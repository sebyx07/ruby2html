---
name: debug-render
description: Debug wrong or crashing ruby2html output - diff the C extension (Ruby2html::Native) against the pure-Ruby twin (Ruby2html::PureRuby), minimize the input, and build the extension with AddressSanitizer/UBSan for memory errors. Use for HTML mismatches, encoding errors, segfaults or GC-related flakiness.
---

# Debug ruby2html rendering

Two implementations exist and must match byte for byte: `Ruby2html::Native` (`ext/ruby2html/`) and `Ruby2html::PureRuby` (`lib/gem/ruby2html/render/pure_ruby.rb`). `Ruby2html::IMPLEMENTATION` says which one `Render` uses; `RUBY2HTML_DISABLE_EXT=1` forces PureRuby.

## 1. Which side is wrong?

```bash
bundle exec rake compile
cat > "$SCRATCH/case.rb" <<'RUBY'
Ruby2html::Render.new { div(class: ['a', nil], data: { x_y: 1 }) { td { 1.5 } } }.render.to_str
RUBY
for mode in 0 1; do
  RUBY2HTML_DISABLE_EXT=$mode bundle exec ruby -Ilib/gem -Ilib -e 'require "ruby2html"; require "active_support"; require "active_support/core_ext/string/output_safety"
    out = eval(File.read(ARGV[0])); puts "#{Ruby2html::IMPLEMENTATION}: #{out.inspect} #{out.encoding}"' "$SCRATCH/case.rb"
done
```

(`$SCRATCH` = your scratch directory.) Drop the ActiveSupport requires to test the no-Rails path; `html_safe?` handling differs with/without it. Same-process comparison (what the specs do, see `spec/gem/render_spec_helper.rb`): `PureRuby` always gets the tag methods, so `pure = Class.new(Ruby2html::Render) { include Ruby2html::PureRuby }` renders with PureRuby while `Ruby2html::Render` uses Native: compare `pure.new(&blk).render` with `Ruby2html::Render.new(&blk).render`.

Decide against the documented rules (`llms.txt`, comments at the top of `content.c` / `attributes.c` / `tag_render.c`), not against whichever side "looks right". Fix the wrong side, then add the case to a `RenderSpecHelper.describe_each` group or `spec/gem/render_parity_spec.rb` (both run Native and PureRuby).

## 2. Minimize

Reduce to one tag call. Vary one dimension at a time: content type (String / SafeBuffer / Symbol / Integer / Float / other / nil), block vs content, block wrote vs did not write, attribute value type (nil / true / false / Hash / Array / other), encoding (`"x".encode('ISO-8859-1')`, `.b`, invalid UTF-8 `"\xff".dup.force_encoding('UTF-8')`), string length around 16-byte SIMD chunk boundaries (15, 16, 17, 31, 32, 33 bytes with the special char at different offsets).

Scalar vs SIMD escape path: `RUBY2HTML_NO_SIMD=1 bundle exec rake compile` and rerun.

## 3. Crashes / memory errors: sanitizer build

`bin/build-ext` builds the CI variants (CI runs the same commands in the `sanitizers` and `strict-ext` jobs):

```bash
bin/build-ext --sanitize              # ASAN + UBSAN build into lib/ruby2html
LD_PRELOAD="$(gcc -print-file-name=libasan.so):$(gcc -print-file-name=libubsan.so)" \
  ASAN_OPTIONS=detect_leaks=0:use_sigaltstack=0 bundle exec ruby -Ilib/gem "$SCRATCH/repro.rb"   # or: ... bundle exec rspec spec/gem
bundle exec rake clobber && bundle exec rake compile   # ALWAYS rebuild normally afterwards
bin/build-ext --werror                # / --cc=clang --werror: warnings as errors
```

Without the script: `bundle exec rake compile -- --with-cflags="-fsanitize=address,undefined -fno-omit-frame-pointer -g -O1" --with-ldflags="-fsanitize=address,undefined"`.

`detect_leaks=0` is required (Ruby's own allocations look like leaks). macOS/clang: use `-fsanitize=address` and `DYLD_INSERT_LIBRARIES=$(clang -print-file-name=libclang_rt.asan_osx_dynamic.dylib)`.

GC-related bugs (missing `RB_GC_GUARD`, stale `RSTRING_PTR` after the buffer grows or after a yield) often only show under GC pressure: run the repro with `GC.stress = true` (slow; keep the input tiny), or in a loop with `GC.compact` between renders.

gdb: `gdb -ex run --args ruby -Ilib/gem -Ilib repro.rb`, build with `--with-cflags="-O0 -g"`.

## 4. Rails-side issues

- Template output wrong but `Render.new { ... }` right: inspect the compiled source: `Ruby2html::RailsComponents::TemplateCompiler.compile(File.read(path)).source` (nil means Prism unavailable or parse error → closure fallback).
- Helper markup outside its tag: check `rails_components/output_capture.rb` (buffer swap during the helper's block).

## Done when

Root cause named (file:line), fix on the correct side, spec covering it passing in both modes, sanitizer run clean if it was a memory bug, extension rebuilt without sanitizers.
