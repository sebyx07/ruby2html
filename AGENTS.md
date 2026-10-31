# AGENTS.md

Single source of truth for AI coding agents (Claude Code, Codex, Cursor, Copilot, ...) working **on** this repo.
`CLAUDE.md` is a symlink to this file: edit only `AGENTS.md`; there are no other per-tool instruction files.
To write ruby2html templates/components (here or in a user app), load [`llms.txt`](llms.txt): the complete user reference (DSL, attributes, Rails, components, forms, API, pitfalls).
Internals: [`docs/architecture.md`](docs/architecture.md). Releases: [`docs/release.md`](docs/release.md).

## What this repo is

`ruby2html` (RubyGems; version in `lib/gem/ruby2html/version.rb`) renders HTML from a Ruby block DSL. The repo is both the gem and a Rails demo app.

| Part | Path | Notes |
|---|---|---|
| Gem (Ruby) | `lib/gem/ruby2html.rb`, `lib/gem/ruby2html/**` | Packaged. `spec.require_paths = ['lib/gem']`; no runtime dependencies |
| C extension | `ext/ruby2html/*.{c,h}`, `extconf.rb` | Defines `Ruby2html::Native`. `rake compile` → `lib/ruby2html/ruby2html.so` (gitignored, found by `render.rb` via `require_relative`); installed gems get it under `lib/gem/ruby2html/` |
| Pure-Ruby twin | `lib/gem/ruby2html/render/pure_ruby.rb` | `Ruby2html::PureRuby`, used when the `.so` is missing (JRuby, failed build) or `RUBY2HTML_DISABLE_EXT=1` |
| Demo Rails app | `app/`, `config/`, `db/` | Not packaged; loads the gem via `require_relative '../lib/gem/ruby2html'` |
| Specs | `spec/gem/` (renderer, attributes, escaping, `render_parity_spec.rb`; `render_spec_helper.rb` runs each group against Native **and** PureRuby in one process), `spec/gem/rails/` (handler, compiler, components, middleware), `spec/features/`, `spec/benchmarks/` | Rails-booting via `spec/rails_helper.rb`; `rake spec:standalone` runs `spec/gem` minus `rails/` without Rails |
| Benchmarks | `bench/*.rb` (standalone), `spec/benchmarks/requests_spec.rb` (request-level vs ERB/Slim/Phlex) | |
| Scripts | `bin/gem-smoke`, `bin/changelog-notes`, `bin/build-ext` | Packaging smoke test; print a CHANGELOG section; CI-style extension builds (`--werror`, `--cc=clang`, `--sanitize`) |

Supported: all maintained CRuby versions (>= 3.1, gemspec floor), JRuby (PureRuby), TruffleRuby, Rails 7.2+. Dev Ruby: `.ruby-version`; rubocop `TargetRubyVersion` matches the floor (no newer syntax in `lib/`). Dependency versions: `Gemfile.lock` and `gemfiles/*.gemfile` (CI matrix gemfiles, unlocked).

## Commands

```bash
bundle install
bundle exec rake compile          # C ext -> lib/ruby2html/ruby2html.so; RUBY2HTML_NO_SIMD=1 for the scalar escape path
CI=1 bundle exec rspec            # full suite minus the ~6 min benchmark spec (skipped when CI is set)
bundle exec rspec spec/gem        # renderer + Rails integration units
bundle exec rake spec             # compiles first (SKIP_COMPILE=1 to skip); spec:gem = spec/gem; spec:standalone = spec/gem without Rails
RUBY2HTML_DISABLE_EXT=1 bundle exec rspec spec/gem   # whole process on PureRuby (parity groups already cover both)
bundle exec rubocop               # CI: bin/rubocop --parallel; lefthook pre-commit autocorrects staged files
bin/brakeman --no-pager
bundle exec rake bench            # compiles, runs every bench/*.rb
bundle exec rake build            # pkg/ruby2html-X.Y.Z.gem (does not compile)
bundle exec rake smoke            # build + bin/gem-smoke: file list check, install into temp GEM_HOME, render without Rails
bin/rails server                  # demo: /, /rb_files, /form, /benchmark/{html,ruby,compruby,slim,phlex}
```

- Gem tasks (`compile clean clobber spec spec:gem spec:standalone bench smoke build install release default`) do not boot Rails; any other task loads the Rails tasks. `RUBY2HTML_RAILS_TASKS=1` forces that.
- After editing `ext/` always `rake compile`; otherwise specs run the stale `.so` (or PureRuby if none).
- Never run `rake release`, push `v*` tags or `gem push`: merging a version bump to `main` is the release (`docs/release.md`).

## Code map

| File | Responsibility |
|---|---|
| `lib/gem/ruby2html.rb` | Entry point: eager-loads only `version` + `render`; everything else is `autoload`ed (Component, ComponentHelper, RailsHelper, HtmlBeautifierMiddleware, `RailsComponents::*`); requires `railtie` only if ActiveSupport is loaded. Keep `require 'ruby2html'` light (no Prism, no ERB engine, no htmlbeautifier) |
| `lib/gem/ruby2html/render.rb` | Loads Native (or PureRuby) into `Ruby2html::IMPLEMENTATION`; `Ruby2html.native?`, `Ruby2html.escape_html`; `Render`: `HTML5_TAGS`/`VOID_ELEMENTS`, defines tags on both implementations via `define_tag`, includes the implementation; `render`, `method_missing` → context, Rails helper wrappers, ivar copying |
| `lib/gem/ruby2html/render/pure_ruby.rb` | Ruby twin of Native: tag methods, `plain`, `component`, text/attribute rules, `escape_html` |
| `ext/ruby2html/ruby2html.c` | `Init_ruby2html`: defines `Ruby2html::Native` |
| `ext/ruby2html/tag_render.c` | `Native.define_tag(method, tag, void)`: binds each tag to one of 200 C trampolines (`R2H_MAX_TAGS`), tag name `[a-z0-9-]`, max 32 chars; `render_tag` writes open tag, yields or appends content, close tag |
| `ext/ruby2html/content.c` | Text rules (`plain`, `component`, tag content, block return values), `html_safe?` detection |
| `ext/ruby2html/attributes.c` | Attribute rules (nil/boolean/Hash/Array/escape), name validation; no caching |
| `ext/ruby2html/html_escape.c` | Escapes `& < > " '`; SSE2 / NEON 16-byte scan, scalar fallback; UTF-8 coercion (`r2h_utf8_compatible`); `Native.escape_html` |
| `ext/ruby2html/buffer.h` | Inline buffer primitives (reserve ≥2x growth, memcpy, commit) |
| `ext/ruby2html/extconf.rb` | `append_cflags -O3 -std=gnu99 -fvisibility=hidden -Wall -Wextra`, `-fno-plt` on Linux, `-DR2H_NO_SIMD` via env; compiles all `*.c` in the dir |
| `lib/gem/ruby2html/railtie.rb` | `TemplateHandler` (`.rb` templates): compiled strategy via `TemplateCompiler` (template runs with self = view/component, renderer in `@__r2h`), closure fallback (no Prism / parse failure: `instance_exec` on a `Render` with ivar copying); filename annotations; Zeitwerk ignore `app/**/*.html.rb` |
| `lib/gem/ruby2html/rails_components/template_compiler.rb`, `template_collector.rb` | Prism rewrite of receiverless tag/`plain`/`component`/`render`/helper calls in templates. Prism is required lazily on first compile (`available?`); the Railtie's `before_eager_load` loads it at boot in eager-loading (production) apps |
| `lib/gem/ruby2html/rails_components/template_helpers.rb` | Receiver for `link_to button_to image_tag form_with render capture content_for provide` in compiled templates |
| `lib/gem/ruby2html/rails_components/{base_component,link_to,button_to,image_tag,form_with,output_capture}.rb` | Call the real Rails helper, capture nested ruby2html output for its block, append result; `FormBuilderProxy` |
| `lib/gem/ruby2html/component.rb` | `Ruby2html::Component`: includes the implementation directly (self = component), `view_template`/`call`, `render_in(view_context)`, `render_into(buffer, ...)` for nesting into a parent buffer, `helpers`, `content`, Rails helper wrappers |
| `lib/gem/ruby2html/component_helper.rb` | ViewComponent `html(&block)`; current renderer in `@__r2h` on the component (save/restore in `ensure`, fiber-safe; no `Thread.current`); `__ruby2html_renderer__`; private `method_missing` to the renderer |
| `lib/gem/ruby2html/rails_helper.rb` | `html(context, &block)` for ERB, `helper_method` when included in a controller |
| `lib/gem/ruby2html/html_beautifier_middleware.rb` | Dev middleware; lazy-requires `htmlbeautifier` (raises a helpful LoadError if missing) |

## Sharp edges / invariants

1. **Native and PureRuby must produce byte-identical output** (HTML, encoding, raised errors) for every input. Any rule change goes into `content.c`/`attributes.c`/`tag_render.c` **and** `pure_ruby.rb`, with specs in the `RenderSpecHelper.describe_each` groups / `render_parity_spec.rb`. Exceptions while writing a start tag roll the buffer back to before the tag (both sides).
2. **Never cache by `Object#hash`.** Hash collisions return another input's output (the old `ATTRIBUTE_CACHE` did exactly this and was removed). Cache only with exact-equality keys, and only with a benchmark proving a win.
3. **GC safety in C**: any `VALUE` whose `RSTRING_PTR`/internal pointer is used after a call that can allocate or yield (`rb_funcall`, `rb_yield`, `rb_str_*`, `rb_obj_as_string`) must be kept alive with `RB_GC_GUARD(v)` after the last use. Re-read `RSTRING_PTR(buf)` after anything that can grow `buf`. Use `buffer.h` (`r2h_buf_reserve`/`commit`), not manual `rb_str_set_len` arithmetic.
4. **Escaping is a security boundary.** Text and attribute values escaped by default; raw only for `html_safe?` objects and `component`. Plain `String` (exact class) is never treated as safe. Attribute and tag **names** are validated (raise), not escaped. Every escaping change needs specs (both modes) and an `xss-auditor` pass.
5. **Speed over memory.** No per-call allocations on hot paths (tag methods, `plain`, attributes, escape); intern IDs at Init; write straight into the output buffer; generate at load/compile time instead of per call. Perf claims need before/after numbers (`.claude/skills/benchmark`).
6. Tag methods: max one positional arg; with a block the block wins; a block's return value counts only if the block wrote nothing (String/Symbol/Numeric); void tags ignore content and block.
7. Renderer `method_missing` forwards only **public** context methods; forwarded return values are not appended. In compiled `.html.rb` templates and `Ruby2html::Component` code runs with self = view/component (no forwarding); inside `ComponentHelper#html` blocks and the closure fallback it runs on the renderer, so **tag names beat same-named component methods/slots** (`header` renders `<header>`).
8. Never add public methods to `Render` whose names are tag names (`Render#output` used to hide `<output>`). In compiled templates `capture`/`content_for`/`provide` are routed to `TemplateHelpers`, which swaps the renderer buffer (ActionView's own capture can't see ruby2html output); inside ViewComponent `html` blocks they still go to the view.
9. `TemplateCompiler` inserts text only (never newlines) so template line numbers stay correct; it skips `def`/`class`/`module` bodies, calls with explicit receivers, and the blocks of `Render.new { }` (they run on their own renderer).
10. Adding a tag: `HTML5_TAGS` (+ `VOID_ELEMENTS`) only; no C change unless exceeding 200 tags or 32-char names (`.claude/skills/add-html-tag`).
11. Public API (`Render.new(ctx, &blk)`, `#render`, `#plain`, `#component`, tag methods, `Ruby2html.escape_html`, `Ruby2html.native?`, `Ruby2html::Component`, `RailsHelper#html`, `ComponentHelper#html` / `#__ruby2html_renderer__`, the `.rb` handler, `HtmlBeautifierMiddleware`) is used downstream: breaking changes need a CHANGELOG entry ("Upgrading to 2.0") and a major bump.
12. Style: rubocop-rails_config, single quotes, `# frozen_string_literal: true`, nested modules, Rails-style indented `private` methods. C: gnu99, no warnings under `-Wall -Wextra`.
13. Never commit `lib/ruby2html/*.so`, `tmp/`, `pkg/`, `*.gem`, `log/`.

## How to verify a change

| You changed | Run | Also |
|---|---|---|
| `ext/**` (C) | `bundle exec rake compile`, `bin/build-ext --werror` (also `--cc=clang`) → `CI=1 bundle exec rspec spec/gem` → `RUBY2HTML_DISABLE_EXT=1 bundle exec rspec spec/gem` | `bundle exec rake bench` before/after; `review` skill checklist; `debug-render` skill for C vs Ruby diffs |
| `render/pure_ruby.rb` | both spec runs above | output parity with Native |
| `render.rb` (tags, delegation, ivars) | `CI=1 bundle exec rspec` | `rake bench` if hot path |
| Escaping / attributes (either side) | both spec runs + new specs for the case | `xss-auditor` agent |
| `railtie.rb`, `template_compiler.rb`, `rails_components/**`, `component.rb`, `component_helper.rb` | `CI=1 bundle exec rspec spec/gem/rails spec/features` | try the demo pages (`bin/rails server`) |
| `html_beautifier_middleware.rb` | `bundle exec rspec spec/gem/rails/html_beautifier_middleware_spec.rb` | |
| gemspec, `Rakefile`, packaging | `bundle exec rake smoke` | `tar -xOf pkg/*.gem data.tar.gz \| tar -tz` |
| `Gemfile` / deps | `upgrade-deps` skill: full suite + benchmarks | |
| Docs only | check every claim against code; run snippets with `bundle exec ruby -Ilib/gem -Ilib -e '...'` | |
| Anything | `bundle exec rubocop` | CHANGELOG `## [Unreleased]` for user-visible changes; update `llms.txt` if user-facing behavior changes |

## Maintenance model

Goal: the repo needs no hand maintenance except major-version dependency upgrades.

Automated:
- **Maintainer agent**: the repo is managed by [developerz.ai](https://developerz.ai) (policy: `.dz/maintainer/maintainer.yml`). It triages issues, reviews every PR, merges every PR (contributors, members, bots) once its author marks it ready (out of draft), it is reviewed and `CI OK` is green, runs a daily `health` and weekday `release-due` checkup and a monthly `improve` pass (`.dz/briefs/`: canary fixes, dependency majors, speed with benchmark evidence, correctness, docs drift), and opens release PRs. Breaking changes escalate to the owner.
- **Dependencies**: Dependabot (`.github/dependabot.yml`) opens grouped weekly PRs after a 14-day cooldown (security updates skip it); the developerz.ai agent reviews and merges them on green (it is the only merger).
- **CI** (`.github/workflows/ci.yml`; branch protection requires only the aggregate `CI OK` job): RuboCop, bundle-audit, full suite + Brakeman, gem specs across the Ruby matrix (generated automatically from maintained CRuby versions), native builds on Linux/macOS arm64, `-Werror` builds with gcc and clang, ASAN/UBSAN (`use_sigaltstack=0`), the pure-Ruby fallback, JRuby/TruffleRuby via `gemfiles/standalone.gemfile`, Rails integration per `gemfiles/rails_*.gemfile`, and `bin/gem-smoke` packaging on plain RubyGems. Every job is required: nothing is allowed to fail and there is no `continue-on-error`.
- **Canary** (`.github/workflows/canary.yml`, monthly on the 1st, not gating): Ruby head and Rails edge, so upstream breaks surface before a release ships them; the monthly `improve` checkup fixes what it finds.
- **Benchmarks** (`.github/workflows/benchmark.yml`, non-gating): every push to `main` and PR renders a table into the job summary and uploads JSON; PRs get a sticky comment with the delta vs `main`. Set repo variable `BENCH_RUNNER` for a stable self-hosted runner. README holds only a dated release snapshot.
- **Releases** (`.github/workflows/release.yml`): merging a `version.rb` bump to `main` (no `v<VERSION>` tag yet) runs the tests, `rake smoke` and a JRuby install, publishes the gem via RubyGems trusted publishing (environment `release`), then creates the tag and the GitHub release from `bin/changelog-notes`. The release PR is opened by the developerz.ai agent or the `release` skill (`docs/release.md`).
- **Local hooks**: lefthook pre-commit autocorrects staged Ruby files with RuboCop; the Claude Code PostToolUse hook reminds to recompile after `ext/` edits.

Manual (the owner's only jobs): **breaking changes and major releases** (escalated by the agent), and one-time repo setup (RubyGems trusted publisher; ruleset requiring `CI OK`). Major dependency bumps are handled by the agent like any other PR; use the `upgrade-deps` skill when doing one by hand.

Keep it that way: don't hardcode version lists or benchmark numbers in docs; point at the CI matrix, `.ruby-version`, the lockfiles and the benchmark workflow instead.

## AI tooling in this repo

- `llms.txt` is the one user-facing reference for the gem (for people and their LLM tools); hand-written and concise. Keep it accurate when behavior changes. There are no other usage docs to sync.

### Claude Code

- Project skills (`.claude/skills/`): `release` (bump → changelog → verify → `release: X.Y.Z` PR; merging publishes; manual-only), `benchmark` (before/after), `add-html-tag`, `review` (checklist for `ext/` and renderer diffs), `debug-render` (C vs Ruby output diffs, sanitizer builds), `upgrade-deps`.
- Subagents (`.claude/agents/`, read-only tools): `perf-reviewer`, `xss-auditor`. Use them for an independent pass on hot-path or escaping changes.
- `.claude/settings.json`: allowlists specs, `rake compile/spec/bench/build/smoke`, rubocop, brakeman, bench scripts and read-only git/gh; `git commit`, `git push`, `git tag`, `rake release`, `gem push/yank`, `gh release` always ask. A PostToolUse hook (`.claude/hooks/post-edit-reminder.sh`, non-blocking) reminds to recompile after `ext/` edits and to keep Native/PureRuby parity after renderer edits.

## Definition of done

`rake compile` clean → `CI=1 bundle exec rspec` and `RUBY2HTML_DISABLE_EXT=1 bundle exec rspec spec/gem` green → `bundle exec rubocop` clean → CHANGELOG/docs updated if behavior changed → benchmark numbers if a speedup is claimed.
