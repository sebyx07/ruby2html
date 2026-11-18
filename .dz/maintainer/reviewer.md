# Reviewer instructions — sebyx07/ruby2html

> Read by the developerz.ai reviewer at EVERY review of this repository, at the reviewed
> commit, as this repo's own layer of the reviewer's prompt. It refines the platform rules
> (a finding is cited or withheld; the bot always discloses) and never overrides them.
> `AGENTS.md` (`CLAUDE.md` is a symlink to it) is the source of truth; this file is its
> review-time distillation. Keep it under 12,000 characters — past that it is cut.

## Stack

`ruby2html` is a RubyGems gem (Ruby block DSL to HTML) and a Rails demo app in one repo. The
renderer has three sides: the C extension `Ruby2html::Native` (`ext/ruby2html/*.c`, CRuby), its
pure-Ruby twin `Ruby2html::PureRuby` (`lib/gem/ruby2html/render/pure_ruby.rb`, JRuby, TruffleRuby,
a failed build, `RUBY2HTML_DISABLE_EXT=1`), and the JRuby Java escaper
(`ext/java/Ruby2htmlJrubyService.java`, the escape rule only). Rails integration lives in
`lib/gem/ruby2html/railtie.rb` and `lib/gem/ruby2html/rails_components/**`. Specs: RSpec under
`spec/gem/` (both implementations in one process via `RenderSpecHelper.describe_each`),
`spec/gem/rails/`, `spec/features/`.

## What to reject

**Native and PureRuby parity**
- A rule change (text, attributes, tags, escaping, raised errors) in `ext/ruby2html/content.c`,
  `attributes.c`, `tag_render.c` or `html_escape.c` without the same change in
  `render/pure_ruby.rb`, or the reverse. Output must stay byte-identical, encoding and exceptions
  included.
- Such a change without a spec in a `RenderSpecHelper.describe_each` group or
  `spec/gem/render_parity_spec.rb`, so both implementations run it.
- An escape-rule change that leaves `ext/java/Ruby2htmlJrubyService.java` behind.
- A start-tag exception path that does not roll the buffer back to before the tag, on either side.

**Escaping (a security boundary)**
- Text or attribute values not escaped by default; raw output for anything but `html_safe?`
  objects and `component`; a plain `String` (exact class) treated as safe.
- Attribute or tag names escaped instead of validated (a bad name must raise).
- Helper output in `rails_components/**` that is double-escaped or under-escaped.
- Any escaping change without specs in both modes; ask for an `xss-auditor` pass in the PR body.

**C extension safety**
- A `VALUE` whose `RSTRING_PTR` or internal pointer is used after a call that can allocate or
  yield (`rb_funcall`, `rb_yield`, `rb_str_*`, `rb_obj_as_string`) with no `RB_GC_GUARD` after
  its last use.
- `RSTRING_PTR(buf)` held across anything that can grow `buf`, or manual `rb_str_set_len`
  arithmetic instead of `buffer.h` (`r2h_buf_reserve` / commit).
- New warnings under `-Wall -Wextra`, or code that is not gnu99.
- A tag table change past 200 tags (`R2H_MAX_TAGS`) or a 32-char name without the matching C change.

**Performance**
- A cache keyed by `Object#hash` (collisions render another input's output; the old
  `ATTRIBUTE_CACHE` did exactly this). Exact-equality keys only, and only with a benchmark.
- A per-call allocation on a hot path (tag methods, `plain`, attributes, escape), or work done
  per call that could be done at load or compile time.
- A speed claim with no before/after numbers (`bundle exec rake bench` or the benchmark workflow).

**Rails integration**
- `TemplateCompiler` inserting a newline (template line numbers must stay correct), or rewriting
  inside `def` / `class` / `module` bodies, explicit-receiver calls or `Render.new { }` blocks.
- A public `Render` method whose name is a tag name (`Render#output` once hid `<output>`).
- `capture` / `content_for` / `provide` in compiled templates bypassing `TemplateHelpers`.
- `require 'ruby2html'` made heavier: Prism, the ERB engine and `htmlbeautifier` stay lazy;
  `lib/gem/ruby2html.rb` eager-loads only `version` and `render`.

**Public API and packaging**
- A breaking change to the public API (`Render.new(ctx, &blk)`, `#render`, `#plain`,
  `#component`, tag methods, `Ruby2html.escape_html`, `Ruby2html.native?`,
  `Ruby2html::Component`, `RailsHelper#html`, `ComponentHelper#html`, the `.rb` handler,
  `HtmlBeautifierMiddleware`) without a CHANGELOG "Upgrading to 2.0" entry and a major bump; it
  escalates to the owner rather than merging.
- A runtime dependency added to `ruby2html.gemspec`.
- A committed build artifact: `lib/ruby2html/*.so`, `*.jar`, `*.class`, `tmp/`, `pkg/`, `*.gem`,
  `log/`.
- A release by hand: a `v*` tag, `rake release`, `gem push`. Merging a `version.rb` bump to
  `main` is the release; a release PR changes only the version, CHANGELOG and its link.
- A user-visible change with no `## [Unreleased]` CHANGELOG line, or a behaviour change that
  leaves `llms.txt` (the one user reference) stale.
- Hardcoded version lists or benchmark numbers in docs; they point at the CI matrix,
  `.ruby-version`, the lockfiles and the benchmark workflow.
- Newer syntax in `lib/` than rubocop's `TargetRubyVersion` (the gemspec floor) allows.

## Gates that matter

- The one required check is CI's aggregate `CI OK` job (`.github/workflows/ci.yml`): RuboCop,
  bundle-audit (root lockfile plus the matrix gemfiles through `bin/audit-advisories`), the full
  suite and Brakeman, the generated CRuby matrix, native builds on Linux and macOS arm64,
  `-Werror` with gcc and clang, ASAN/UBSAN, the pure-Ruby fallback, JRuby and TruffleRuby,
  Rails integration and `bin/gem-smoke`. Every job is required; none may `continue-on-error`.
- Locally `bin/check` runs the subset that needs no special setup. A change that does not pass
  it is not proven, whatever its description says.
- A new exception in `bin/audit-advisories` must name the advisory id and the exact reviewed
  version; a broader accept is a finding.

## Never flag

- Rubocop-owned style (rubocop-rails_config, single quotes, `# frozen_string_literal: true`,
  Rails-style indented `private`); lefthook and CI autocorrect it.
- Tag names winning over same-named component methods inside `ComponentHelper#html` blocks and
  the closure fallback (`header` renders `<header>`): documented behaviour.
- Renderer `method_missing` forwarding only public context methods and not appending their
  return values: on purpose.
- The dev-tools Dependabot group skipping the 14-day cooldown (`cooldown.exclude` in
  `.github/dependabot.yml`): on purpose.
- The accepted floor-line advisories (Rails 7.2.x, Active Support 7.2.x on Ruby 3.1) listed by
  id in `bin/audit-advisories`.
- The monthly `canary.yml` (Ruby head, Rails edge) being red: it is not gating; the `improve`
  checkup fixes it.
