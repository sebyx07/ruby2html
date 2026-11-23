# ext/ — the C extension and the JRuby Java escaper

Rules for everything under `ext/`. Root invariants (parity, escaping, no `Object#hash` cache, speed) apply here first.

**After every edit here: `bundle exec rake compile`, then run the specs.** Without it the specs load the stale `lib/ruby2html/ruby2html.so` (or PureRuby when no `.so` exists) and pass on code you did not test. `bin/check` compiles first; a bare `bundle exec rspec` does not.

## Files

| File | Responsibility |
|---|---|
| `ruby2html/ruby2html.c` | `Init_ruby2html`: defines `Ruby2html::Native` |
| `ruby2html/tag_render.c` | `Native.define_tag(method, tag, void)`: binds each tag to one of 200 C trampolines (`R2H_MAX_TAGS`); tag name `[a-z0-9-]`, 32 chars at most; `render_tag` writes the open tag, yields or appends content, writes the close tag |
| `ruby2html/content.c` | Text rules (`plain`, `component`, tag content, block return values), `html_safe?` detection |
| `ruby2html/attributes.c` | Attribute rules (nil, boolean, Hash, Array, escape), name validation. No caching |
| `ruby2html/html_escape.c` | Escapes `& < > " '`; SSE2 and NEON 16-byte scan with a scalar fallback; UTF-8 coercion (`r2h_utf8_compatible`); `Native.escape_html` |
| `ruby2html/buffer.h` | Inline buffer primitives: reserve (growth of at least 2x), memcpy, commit |
| `ruby2html/extconf.rb` | `append_cflags -O3 -std=gnu99 -fvisibility=hidden -Wall -Wextra`, `-fno-plt` on Linux, `-DR2H_NO_SIMD` from `RUBY2HTML_NO_SIMD=1`; compiles every `*.c` in the directory; writes a no-op Makefile on JRuby and TruffleRuby |
| `java/Ruby2htmlJrubyService.java` | JRuby `BasicLibraryService`: `Ruby2html::JavaNative.escape`. Built by `Rake::JavaExtensionTask` (`Rakefile`) into `lib/gem/ruby2html/ruby2html_jruby.jar` (gitignored; shipped in the `-java` gem) |

## Rules

- **Mirror every rule change in `lib/gem/ruby2html/render/pure_ruby.rb`**, in the same change, with a spec that runs on both implementations. A start-tag exception rolls the buffer back to before the tag, on both sides.
- **GC safety.** A `VALUE` whose `RSTRING_PTR` or internal pointer is used after a call that can allocate or yield (`rb_funcall`, `rb_yield`, `rb_str_*`, `rb_obj_as_string`) needs `RB_GC_GUARD(v)` after its last use. Re-read `RSTRING_PTR(buf)` after anything that can grow `buf`. Use `buffer.h` (`r2h_buf_reserve`, commit); never do `rb_str_set_len` arithmetic by hand.
- **Hot path.** Intern IDs once at Init, never `rb_intern` or `rb_funcall` in a loop; write straight into the output buffer; precompute sizes.
- **No new warnings** under `-Wall -Wextra`, with gcc and with clang. CI builds both with `-Werror`. Code is gnu99.
- **Adding a tag needs no C change** (it is data in `Render::HTML5_TAGS`; skill `add-html-tag`) unless the table passes 200 tags or a name passes 32 chars.
- **Java escaper.** Byte-identical with `html_escape.c` and `PureRuby.escape`. The default package and the `*Service` class name are load-bearing: JRuby's `require` finds the library by that convention.
- Escaping changed: agent `xss-auditor`. Speed changed: agent `perf-reviewer` and skill `benchmark`, with before and after numbers from the same machine.

## Build and verify

| Step | Command |
|---|---|
| Normal build | `bundle exec rake compile` (output `lib/ruby2html/ruby2html.so`, build tree `tmp/ext`) |
| Warnings as errors | `bin/build-ext --werror`, `bin/build-ext --cc=clang --werror` |
| Scalar escape path | `RUBY2HTML_NO_SIMD=1 bundle exec rake compile` |
| Specs on that build | `CI=1 bundle exec rspec spec/gem` (`SKIP_COMPILE=1 bundle exec rake spec:gem` keeps a `bin/build-ext` build) |
| PureRuby process | `RUBY2HTML_DISABLE_EXT=1 bundle exec rspec spec/gem` |
| ASAN + UBSAN | `bin/build-ext --sanitize`, then run the specs with the runtimes preloaded; the exact `LD_PRELOAD` and `ASAN_OPTIONS` line is in the header of `bin/build-ext` (`use_sigaltstack=0`: Ruby installs its own signal stack) |
| Benchmarks | `bundle exec rake bench`, before and after |
| JRuby | `bundle exec rake compile` (builds the jar), `bundle exec rake spec:standalone`, `bundle exec ruby bin/gem-smoke` |

Wrong or crashing output: skill `debug-render` (diff Native against PureRuby, minimize the input, sanitizer build). After a sanitizer or strict build, `bundle exec rake compile` restores the normal `.so`.

CI covers what a dev box cannot: Linux arm64 and macOS arm64 (the NEON path; x86_64 is SSE2), gcc and clang `-Werror`, ASAN/UBSAN, JRuby, TruffleRuby. Jobs: `.github/CLAUDE.md`.
