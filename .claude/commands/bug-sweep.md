---
description: Sweep one area of sebyx07/ruby2html for defects — run the detectors below, fix each with a failing spec first, ship one goal-scoped pull request. Use for bug sweep, find bugs, fix everything in, QA pass.
argument-hint: <the area or goal to sweep, e.g. "attributes" or "form_with">
---

Sweep `$ARGUMENTS` for defects. A clean area reported clean is a success: never invent a defect to have something to ship, never fix what is not broken. Read `CLAUDE.md` and the nested `CLAUDE.md` of the area (`ext/`, `lib/`, `spec/`) first; their invariants bind every fix.

## Steps

1. Read the area on **both** implementations (the C file and its rule in `lib/gem/ruby2html/render/pure_ruby.rb`; for escaping also `ext/java/Ruby2htmlJrubyService.java`), then run each detector below over it. Read the code that does the thing, not only a file that mentions it.
2. For each defect: write the failing spec first and watch it fail, then fix the cause. A renderer rule goes in a `RenderSpecHelper.describe_each` group or `spec/gem/render_parity_spec.rb`, so it runs on both implementations.
3. A defect class that recurred is fixed as a class: a fuzz case in `spec/gem/render_fuzz_spec.rb`, a guard spec or a `bin/check` step that makes the next one fail, in the same change.
4. Prove it. After any `ext/` edit, `bundle exec rake compile` first: the specs otherwise load the stale build. Then `bin/check`, plus the row for the area in `CLAUDE.md` "Verify by area". Exit 75 means the environment is missing, not the change: `bin/setup`, then rerun. Red is not a pull request: fix the cause, never silence the check.
5. Ship one goal-scoped pull request for the area, every defect in it with its spec, and a `CHANGELOG.md` `## [Unreleased]` line for what users see (`llms.txt` too when DSL behavior changes). A defect outside the area is its own pull request, named in the body. `CI OK` runs what `bin/check` cannot (the Ruby and Rails matrices, JRuby, TruffleRuby, `-Werror`, the sanitizers): watch it to green.
6. The body lists each defect: the input that broke it, the spec that pins it, the fix.

Stop for the owner instead of shipping when a fix changes the public API (`lib/CLAUDE.md`) or documented output, or when the defect is an exploitable escaping bypass or memory-safety hole: that is a private report (`SECURITY.md`), not a public pull request.

## What to hunt — run the detector, do not just read

| Class | Detector |
| --- | --- |
| Native and PureRuby differ | render the input on both (`RenderSpecHelper.describe_each`, skill `debug-render`); compare bytes, encoding and the raised error's first line |
| A value reaches the output unescaped | every append of text or an attribute value: escaped unless `html_safe?`; a plain `String` is never safe; agent `xss-auditor` |
| A name is escaped instead of validated | attribute and tag names with `" ' < > / =`, spaces, control characters or invalid UTF-8 must raise `ArgumentError` on both sides |
| GC hazard in C | a `VALUE` whose pointer is read after `rb_funcall`, `rb_yield` or `rb_str_*` with no `RB_GC_GUARD`; `RSTRING_PTR` kept across a buffer growth; confirm with `bin/build-ext --sanitize` |
| Half-written output after an exception | raise from a block, a `to_s` or an attribute value: the buffer must roll back to before the start tag |
| Encoding | binary, US-ASCII with high bytes, UTF-16 and untranscodable input: same output or same error on both sides |
| Works on one runtime only | `RUBY2HTML_DISABLE_EXT=1 bundle exec rspec spec/gem`; `bundle exec rake spec:standalone` (no Rails, what JRuby and TruffleRuby run) |
| Rails helper writes outside its block | `link_to`, `button_to`, `form_with`, `render`, `capture`, `content_for` with a block of tags, in a `.html.rb` template, a ViewComponent and a `Ruby2html::Component` |
| Template compiler rewrites what it should not | a local or method named like a tag (`title`, `header`), strict locals, `def` bodies, explicit receivers; line numbers in backtraces unchanged |
| Holds on one Rails line only | `CI=1 bundle exec rspec spec/gem/rails spec/features`; the other lines run in CI's `rails` job |
| Hot-path cost | a new allocation or lookup per call in tag methods, `plain`, attributes, escape: `bundle exec rake bench` before and after (skill `benchmark`) |
| A doc, example or `llms.txt` line the code no longer matches | run the snippet: `bundle exec ruby -Ilib/gem -Ilib -e '...'` |
| Guard that proves nothing | break the guarded thing; if the spec stays green, the spec is the bug |
| Missing spec | a rule in the C header comments or `pure_ruby.rb` that no example in `spec/gem/` exercises |
