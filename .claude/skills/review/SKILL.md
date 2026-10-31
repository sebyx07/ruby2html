---
name: review
description: Review checklist for ruby2html changes, especially ext/ (C) and the renderer - GC safety, escaping, Native/PureRuby parity, allocations, benchmark before/after. Use when reviewing a diff, a PR, or your own work before declaring it done.
---

# Review a ruby2html change

Scope: `git diff` (uncommitted) or `git diff main...HEAD`. Read `AGENTS.md` "Sharp edges / invariants" first. Report findings as file:line + why + fix; say explicitly which checklist sections passed.

## C extension (`ext/ruby2html/`)

- [ ] **GC safety**: every `VALUE` whose pointer (`RSTRING_PTR`, `RARRAY_CONST_PTR`) is used across a call that may allocate/yield/raise has `RB_GC_GUARD` after its last use. Temporaries from `rb_obj_as_string`, `rb_sym2str`, `rb_String`, `r2h_utf8_compatible` included.
- [ ] **Stale pointers**: no `RSTRING_PTR(buf)` cached across `r2h_buf_reserve`, `rb_yield*`, `rb_funcall` or any append (buffer may move).
- [ ] Buffer writes go through `buffer.h` (`r2h_buf_reserve` → write → `r2h_buf_commit`); reserved size ≥ bytes written (escaping: exact extra computed first).
- [ ] Types: `long` for Ruby lengths, casts to `size_t` only for `memcpy`; no signed overflow on size math.
- [ ] Exceptions: no C-side state left inconsistent if a Ruby call raises (`rb_yield`, `to_s`, `html_safe?`).
- [ ] IDs interned at Init (`r2h_id_*`), no `rb_intern` in hot paths; no new `rb_funcall` per byte/attribute if avoidable.
- [ ] Encoding: output stays UTF-8; inputs go through `r2h_utf8_compatible`.
- [ ] SIMD: SSE2 / NEON / scalar paths agree (rebuild with `RUBY2HTML_NO_SIMD=1` and run specs).
- [ ] `bin/build-ext --werror` (and `--cc=clang --werror`) passes; for memory-sensitive changes run the sanitizer build (`debug-render` skill).

## Escaping (C and Ruby)

- [ ] Text and attribute values escaped (`& < > " '`) unless `html_safe?`; exact `String` never treated as safe.
- [ ] Attribute/tag names validated, invalid names raise `ArgumentError`.
- [ ] New raw-output paths are documented and justified; consider an `xss-auditor` subagent pass.

## Parity (Native vs PureRuby)

- [ ] Every rule change exists in both `ext/ruby2html/*.c` and `lib/gem/ruby2html/render/pure_ruby.rb`.
- [ ] Specs pass in both modes: `CI=1 bundle exec rspec spec/gem` and `RUBY2HTML_DISABLE_EXT=1 bundle exec rspec spec/gem`. Same exceptions too.
- [ ] Suspicious cases diffed with the `debug-render` skill.

## Ruby / performance

- [ ] No per-call allocations added on hot paths (splats, arrays, interpolation, `define_method` at call time, `method_missing` in loops).
- [ ] No cache keyed by `Object#hash`.
- [ ] Benchmarks before/after (`benchmark` skill) for any hot-path change; numbers in the PR. Or a `perf-reviewer` subagent pass.

## Rails integration

- [ ] `TemplateCompiler` edits never insert newlines; skips `def`/`class`/`module`; explicit receivers untouched.
- [ ] Helper wrappers capture block output (`OutputCapture`) and append exactly once.
- [ ] `CI=1 bundle exec rspec spec/gem/rails spec/features`.

## Hygiene

- [ ] `bundle exec rubocop` clean; no Ruby syntax newer than the gemspec `required_ruby_version` floor in `lib/`.
- [ ] CHANGELOG `## [Unreleased]` entry for user-visible changes (breaking → "Upgrading to 2.0").
- [ ] `llms.txt` updated if user-facing behavior changed.
