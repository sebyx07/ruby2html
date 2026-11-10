# AGENTS.md

Single source of truth for AI coding agents (Claude Code, Codex, Cursor, Copilot, ...) working **on** this repo. `CLAUDE.md` is a symlink to this file: edit only `AGENTS.md`; there are no other per-tool instruction files.

Writing ruby2html templates/components (here or in a user app)? Load [`llms.txt`](llms.txt) — the complete user reference (DSL, attributes, Rails, components, forms, API, pitfalls). Internals: [`docs/architecture.md`](docs/architecture.md). Releases: [`docs/release.md`](docs/release.md).

## Stack

`ruby2html` (RubyGems; version in `lib/gem/ruby2html/version.rb`) renders HTML from a Ruby block DSL; the repo is both the gem and a Rails demo app.

| Part | Path | Notes |
|---|---|---|
| Gem (Ruby) | `lib/gem/ruby2html.rb`, `lib/gem/ruby2html/**` | Packaged; `spec.require_paths = ['lib/gem']`; no runtime dependencies |
| C extension | `ext/ruby2html/*.{c,h}`, `extconf.rb` | `Ruby2html::Native` (CRuby only). `rake compile` → `lib/ruby2html/ruby2html.so` (gitignored, found by `render.rb` via `require_relative`); installed gems get it under `lib/gem/ruby2html/` |
| Pure-Ruby twin | `lib/gem/ruby2html/render/pure_ruby.rb` | `Ruby2html::PureRuby` — used when the `.so` is missing (JRuby, failed build), on TruffleRuby (pure Ruby beats Sulong there), or with `RUBY2HTML_DISABLE_EXT=1` |
| Java escaper (JRuby) | `ext/java/Ruby2htmlJrubyService.java` | `Ruby2html::JavaNative.escape` (byte-level HTML escape, the hot path); JRuby's only native code; `PureRuby.escape` uses it when present. `rake compile` on JRuby → `lib/gem/ruby2html/ruby2html_jruby.jar` (gitignored); shipped in the `-java` platform gem |
| Demo Rails app | `app/`, `config/`, `db/` | Not packaged; loads the gem via `require_relative '../lib/gem/ruby2html'` |
| Specs | `spec/gem/` (renderer, attributes, escaping, `render_parity_spec.rb`; `render_spec_helper.rb` runs each group against Native **and** PureRuby in one process), `spec/gem/rails/` (handler, compiler, components, middleware), `spec/features/`, `spec/benchmarks/` | Rails-booting via `spec/rails_helper.rb`; `rake spec:standalone` runs `spec/gem` minus `rails/` without Rails |
| Benchmarks | `bench/*.rb` (standalone), `spec/benchmarks/requests_spec.rb` (request-level vs ERB/Slim/Phlex) | |
| Scripts | `bin/gem-smoke`, `bin/changelog-notes`, `bin/build-ext`, `bin/rails-versions`, `bin/rails-defaults-check`, `bin/audit-advisories` | Packaging smoke test; print a CHANGELOG section; CI-style extension builds (`--werror`, `--cc=clang`, `--sanitize`); the demo app's Rails floor (`bin/rails-versions --floor`) and the CI guard that keeps the app, the advertised floor and the matrix in sync (`bin/rails-defaults-check`); audit one resolved lockfile against the Ruby advisory database (`bundle-audit check --update --gemfile-lock <lockfile>`; exits non-zero on an advisory, except the reviewed advisories the script accepts, scoped to the exact reviewed version the lockfile resolves) |

- Supported: all maintained CRuby versions (>= 3.1, gemspec floor; CI tracks the official list — currently 3.3, 3.4, 4.0), JRuby (pure Ruby + the Java escaper), TruffleRuby (pure Ruby), Rails 7.2+.
- Dev Ruby: `.ruby-version` (latest stable). The CRuby CI matrix is generated automatically from the maintained-versions list, so a new release (e.g. a new 4.x) joins CI with no edit.
- rubocop `TargetRubyVersion` matches the floor (no newer syntax in `lib/`).
- Dependency versions: `Gemfile.lock` and `gemfiles/*.gemfile` (CI matrix gemfiles, unlocked).

## Non-negotiables

| Rule | Substance |
|---|---|
| Native ⇄ PureRuby parity | Byte-identical output (HTML, encoding, raised errors); every rule change lands in the C files **and** `pure_ruby.rb`, with parity specs; the Java escaper matches the escape rule (edge 1) |
| Escaping is a security boundary | Text and attribute values escaped by default; raw only for `html_safe?` objects and `component`; plain `String` never safe; names validated (raise), never escaped; every escaping change: specs (both modes) + `xss-auditor` (edge 4) |
| Never cache by `Object#hash` | Collisions return another input's output (the old `ATTRIBUTE_CACHE` did exactly this); exact-equality keys only, and only with a benchmark proving a win (edge 2) |
| GC safety in C | `RB_GC_GUARD` every `VALUE` whose pointer outlives an allocating/yielding call; re-read `RSTRING_PTR(buf)` after growth; use `buffer.h` (edge 3) |
| Speed over memory | No per-call allocations on hot paths; perf claims need before/after numbers (edge 5) |
| Never release by hand | No `rake release`, no `v*` tag push, no `gem push` — merging a `version.rb` bump to `main` is the release |
| Never commit artifacts | `lib/ruby2html/*.so`, `*.jar`, `*.class`, `tmp/`, `pkg/`, `*.gem`, `log/` (edge 13) |
| Breaking public API | CHANGELOG entry ("Upgrading to 2.0") + major bump; breaking changes escalate to the owner (edge 11) |

## Commands

| Command | Notes |
|---|---|
| `bundle install` | — |
| `bundle exec rake compile` | C ext → `lib/ruby2html/ruby2html.so`; `RUBY2HTML_NO_SIMD=1` for the scalar escape path; carries `audit:advisories` (CI only; the `spec` tasks carry it too, so `SKIP_COMPILE=1` does not drop it) |
| `bundle exec rake audit:advisories`, `bin/audit-advisories [lockfile]` | audits one resolved lockfile — `<BUNDLE_GEMFILE>.lock` (the script reads `ENV['BUNDLE_GEMFILE']` itself; the rake task runs it with the variable still set, only its child processes get the Bundler keys stripped), else `Gemfile.lock`; an explicit path wins — against the Ruby advisory database via `bundle-audit check --update --gemfile-lock`; the rake task runs only in CI (`CI=1`) and only for the unlocked `gemfiles/*.gemfile` matrix sets; exits non-zero on an advisory, except the advisories `bin/audit-advisories` accepts for the floor lines the matrix resolves on purpose (Rails 7.2.x, Active Support 7.2.x on Ruby 3.1): those are listed by advisory id in the script, scoped to the exact reviewed version — a moved resolution drops every exception and fails the audit until the list is re-reviewed |
| `CI=1 bundle exec rspec` | full suite minus the ~6 min benchmark spec (skipped when CI is set) |
| `bundle exec rspec spec/gem` | renderer + Rails integration units |
| `bundle exec rake spec` | compiles first (`SKIP_COMPILE=1` to skip); `spec:gem` = `spec/gem`; `spec:standalone` = `spec/gem` without Rails |
| `RUBY2HTML_DISABLE_EXT=1 bundle exec rspec spec/gem` | whole process on PureRuby (parity groups already cover both) |
| `bundle exec rubocop` | CI: `bin/rubocop --parallel`; lefthook pre-commit autocorrects staged files |
| `bin/brakeman --no-pager` | — |
| `bundle exec rake bench` | compiles, runs every `bench/*.rb` |
| `bundle exec rake build` | `pkg/ruby2html-X.Y.Z.gem` (does not compile) |
| `bundle exec rake smoke` | build + `bin/gem-smoke`: file list check, install into temp GEM_HOME, render without Rails |
| `bin/rails server` | demo: `/`, `/rb_files`, `/form`, `/benchmark/{html,ruby,compruby,slim,phlex}` |

- Gem tasks (`compile clean clobber spec spec:gem spec:standalone bench smoke build install release default audit:advisories`) do not boot Rails; any other task loads the Rails tasks. `RUBY2HTML_RAILS_TASKS=1` forces that.
- After editing `ext/` always `rake compile`; otherwise specs run the stale `.so` (or PureRuby if none).
- Never run `rake release`, push `v*` tags or `gem push`: merging a version bump to `main` is the release (`docs/release.md`).

## Code map

| File | Responsibility |
|---|---|
| `lib/gem/ruby2html.rb` | Entry point: eager-loads only `version` + `render`; everything else `autoload`ed (Component, ComponentHelper, RailsHelper, HtmlBeautifierMiddleware, `RailsComponents::*`); requires `railtie` only if ActiveSupport is loaded. Keep `require 'ruby2html'` light (no Prism, no ERB engine, no htmlbeautifier) |
| `lib/gem/ruby2html/render.rb` | Loads Native (or PureRuby) into `Ruby2html::IMPLEMENTATION`; `load_native_extension` returns false on JRuby/TruffleRuby (no C ext there); `Ruby2html.native?`, `Ruby2html.escape_html`; `Render`: `HTML5_TAGS`/`VOID_ELEMENTS`, defines tags on both implementations via `define_tag`, includes the implementation; `render`, `method_missing` → context, Rails helper wrappers, ivar copying |
| `lib/gem/ruby2html/render/pure_ruby.rb` | Ruby twin of Native: tag methods, `plain`, `component`, text/attribute rules, `escape_html`. `escape` picks the fastest available: ERB's C escaper on CRuby, `Ruby2html::JavaNative` (the Java escaper) on JRuby, else a regex — all byte-identical |
| `ext/ruby2html/ruby2html.c` | `Init_ruby2html`: defines `Ruby2html::Native` |
| `ext/ruby2html/tag_render.c` | `Native.define_tag(method, tag, void)`: binds each tag to one of 200 C trampolines (`R2H_MAX_TAGS`), tag name `[a-z0-9-]`, max 32 chars; `render_tag` writes open tag, yields or appends content, close tag |
| `ext/ruby2html/content.c` | Text rules (`plain`, `component`, tag content, block return values), `html_safe?` detection |
| `ext/ruby2html/attributes.c` | Attribute rules (nil/boolean/Hash/Array/escape), name validation; no caching |
| `ext/ruby2html/html_escape.c` | Escapes `& < > " '`; SSE2 / NEON 16-byte scan, scalar fallback; UTF-8 coercion (`r2h_utf8_compatible`); `Native.escape_html` |
| `ext/ruby2html/buffer.h` | Inline buffer primitives (reserve ≥2x growth, memcpy, commit) |
| `ext/ruby2html/extconf.rb` | `append_cflags -O3 -std=gnu99 -fvisibility=hidden -Wall -Wextra`, `-fno-plt` on Linux, `-DR2H_NO_SIMD` via env; compiles all `*.c` in the dir; no-op Makefile (pure Ruby) on JRuby and TruffleRuby |
| `ext/java/Ruby2htmlJrubyService.java` | JRuby `BasicLibraryService`: `Ruby2html::JavaNative.escape`, byte-identical with `html_escape.c` and `PureRuby.escape`. Built by `Rake::JavaExtensionTask` (Rakefile); default package + the `*Service` name are load-bearing (JRuby's `require` convention) |
| `lib/gem/ruby2html/railtie.rb` | `TemplateHandler` (`.rb` templates): compiled strategy via `TemplateCompiler` (template runs with self = view/component, renderer in `@__r2h`), closure fallback (no Prism / parse failure: `instance_exec` on a `Render` with ivar copying); filename annotations; Zeitwerk ignore `app/**/*.html.rb` |
| `lib/gem/ruby2html/rails_components/template_compiler.rb`, `template_collector.rb` | Prism rewrite of receiverless tag/`plain`/`component`/`render`/helper calls in templates; Prism required lazily on first compile (`available?`); the Railtie's `before_eager_load` loads it at boot in eager-loading (production) apps |
| `lib/gem/ruby2html/rails_components/template_helpers.rb` | Receiver for `link_to button_to image_tag form_with render capture content_for provide` in compiled templates |
| `lib/gem/ruby2html/rails_components/{base_component,link_to,button_to,image_tag,form_with,output_capture}.rb` | Call the real Rails helper, capture nested ruby2html output for its block, append result; `FormBuilderProxy` |
| `lib/gem/ruby2html/component.rb` | `Ruby2html::Component`: includes the implementation directly (self = component), `view_template`/`call`, `render_in(view_context)`, `render_into(buffer, ...)` for nesting into a parent buffer, `helpers`, `content`, Rails helper wrappers |
| `lib/gem/ruby2html/component_helper.rb` | ViewComponent `html(&block)`; current renderer in `@__r2h` (save/restore in `ensure`, fiber-safe; no `Thread.current`); `__ruby2html_renderer__`; private `method_missing` to the renderer |
| `lib/gem/ruby2html/rails_helper.rb` | `html(context, &block)` for ERB, `helper_method` when included in a controller |
| `lib/gem/ruby2html/html_beautifier_middleware.rb` | Dev middleware; lazy-requires `htmlbeautifier` (helpful LoadError if missing) |

## How to verify a change

| You changed | Run | Also |
|---|---|---|
| `ext/**` (C) | `bundle exec rake compile`, `bin/build-ext --werror` (also `--cc=clang`) → `CI=1 bundle exec rspec spec/gem` → `RUBY2HTML_DISABLE_EXT=1 bundle exec rspec spec/gem` | `bundle exec rake bench` before/after; `review` skill checklist; `debug-render` skill for C vs Ruby diffs |
| `render/pure_ruby.rb` | both spec runs above | output parity with Native |
| `render.rb` (tags, delegation, ivars) | `CI=1 bundle exec rspec` | `rake bench` if hot path |
| Escaping / attributes (either side) | both spec runs + new specs for the case | `xss-auditor` agent |
| `railtie.rb`, `template_compiler.rb`, `rails_components/**`, `component.rb`, `component_helper.rb` | `CI=1 bundle exec rspec spec/gem/rails spec/features` | try the demo pages (`bin/rails server`) |
| `html_beautifier_middleware.rb` | `bundle exec rspec spec/gem/rails/html_beautifier_middleware_spec.rb` | |
| `ext/java/**` (JRuby escaper) | on JRuby: `bundle exec rake compile` → `bundle exec rake spec:standalone` → `bundle exec ruby bin/gem-smoke` | keep byte-identical with `html_escape.c` / `PureRuby.escape`; `xss-auditor` pass |
| gemspec, `Rakefile`, packaging | `bundle exec rake smoke` | `tar -xOf pkg/*.gem data.tar.gz \| tar -tz` |
| `Gemfile` / deps | `upgrade-deps` skill: full suite + benchmarks | |
| Docs only | check every claim against code; run snippets with `bundle exec ruby -Ilib/gem -Ilib -e '...'` | |
| Anything | `bundle exec rubocop` | CHANGELOG `## [Unreleased]` for user-visible changes; update `llms.txt` if user-facing behavior changes |

## Sharp edges / invariants

1. **Native and PureRuby must produce byte-identical output** (HTML, encoding, raised errors) for every input. Any rule change goes into `content.c`/`attributes.c`/`tag_render.c` **and** `pure_ruby.rb`, with specs in the `RenderSpecHelper.describe_each` groups / `render_parity_spec.rb`; start-tag exceptions roll the buffer back to before the tag (both sides). The JRuby Java escaper (`ext/java`) is a third side of the escape rule only: byte-identical with `html_escape.c` / `PureRuby.escape` (the JRuby standalone run exercises it, and a `render_spec` example checks it is loaded and matches).
2. **Never cache by `Object#hash`**: collisions return another input's output (the old `ATTRIBUTE_CACHE` did exactly this and was removed). Exact-equality keys only, and only with a benchmark proving a win.
3. **GC safety in C**: any `VALUE` whose `RSTRING_PTR`/internal pointer is used after a call that can allocate or yield (`rb_funcall`, `rb_yield`, `rb_str_*`, `rb_obj_as_string`) needs `RB_GC_GUARD(v)` after its last use; re-read `RSTRING_PTR(buf)` after anything that can grow `buf`; use `buffer.h` (`r2h_buf_reserve`/`commit`), never manual `rb_str_set_len` arithmetic.
4. **Escaping is a security boundary.** Text and attribute values escaped by default; raw only for `html_safe?` objects and `component`; plain `String` (exact class) never safe. Attribute/tag **names** are validated (raise), not escaped. Every escaping change: specs (both modes) + `xss-auditor` pass.
5. **Speed over memory.** No per-call allocations on hot paths (tag methods, `plain`, attributes, escape); intern IDs at Init; write straight into the output buffer; generate at load/compile time, not per call. Perf claims need before/after numbers (`.claude/skills/benchmark`).
6. Tag methods: max one positional arg; with a block the block wins; a block's return value counts only if the block wrote nothing (String/Symbol/Numeric); void tags ignore content and block.
7. Renderer `method_missing` forwards only **public** context methods; forwarded return values are not appended. Compiled `.html.rb` templates and `Ruby2html::Component` run with self = view/component (no forwarding); `ComponentHelper#html` blocks and the closure fallback run on the renderer, so **tag names beat same-named component methods/slots** (`header` renders `<header>`).
8. Never add public `Render` methods whose names are tag names (`Render#output` once hid `<output>`). In compiled templates `capture`/`content_for`/`provide` route to `TemplateHelpers`, which swaps the renderer buffer (ActionView's own capture can't see ruby2html output); inside ViewComponent `html` blocks they still go to the view.
9. `TemplateCompiler` inserts text only (never newlines) so template line numbers stay correct; it skips `def`/`class`/`module` bodies, explicit-receiver calls, and `Render.new { }` blocks (they run on their own renderer).
10. Adding a tag: `HTML5_TAGS` (+ `VOID_ELEMENTS`) only; no C change unless exceeding 200 tags or 32-char names (`.claude/skills/add-html-tag`).
11. Public API used downstream — `Render.new(ctx, &blk)`, `#render`, `#plain`, `#component`, tag methods, `Ruby2html.escape_html`, `Ruby2html.native?`, `Ruby2html::Component`, `RailsHelper#html`, `ComponentHelper#html` / `#__ruby2html_renderer__`, the `.rb` handler, `HtmlBeautifierMiddleware` — breaking changes need a CHANGELOG entry ("Upgrading to 2.0") and a major bump.
12. Style: rubocop-rails_config, single quotes, `# frozen_string_literal: true`, nested modules, Rails-style indented `private` methods. C: gnu99, no warnings under `-Wall -Wextra`.
13. Never commit `lib/ruby2html/*.so`, `*.jar`, `*.class`, `tmp/`, `pkg/`, `*.gem`, `log/`.
14. **The demo app's Rails floor is derived, not hardcoded.** `config.load_defaults` in `config/application.rb` is the single source of truth: `bin/rails-versions` parses it (`--floor` prints it, no network) and derives the CI matrix from it. The matrix's oldest entry and the floor the gem advertises (`Rails X.Y+` in README.md, llms.txt and AGENTS.md) must equal the app's floor — `bin/rails-defaults-check` fails CI, naming every version compared, when they drift. A matrix entry older than the app's `load_defaults` cannot boot the demo app (`RuntimeError: Unknown version`); Rails edge is not a matrix entry (it runs monthly in `canary.yml`).

## Maintenance model

Goal: the repo needs no hand maintenance except major-version dependency upgrades.

| What | How |
|---|---|
| Maintainer agent | Repo managed by [developerz.ai](https://developerz.ai) (policy: `.dz/maintainer/maintainer.yml`): triages issues, reviews and merges every PR (contributors, members, bots) once its author marks it ready (out of draft), it is reviewed and `CI OK` is green; daily `health` + weekday `release-due` checkups and a monthly `improve` pass (`.dz/briefs/`: canary fixes, dependency majors, speed with benchmark evidence, correctness, docs drift); opens release PRs; breaking changes escalate to the owner. Sibling projects such as [wurk](https://github.com/sebyx07/wurk) run the same model |
| Dependencies | Dependabot (`.github/dependabot.yml`) opens grouped weekly PRs: app dependencies wait out a 14-day cooldown (security updates skip it), while the dev-tools group is exempt from it (`cooldown.exclude`) and is proposed within days; the agent reviews and merges on green — the only merger |
| CI | `.github/workflows/ci.yml`; branch protection requires only the aggregate `CI OK` job: RuboCop, bundle-audit (the committed root `Gemfile.lock` in the `audit` job, plus the resolved sets of the unlocked matrix gemfiles `gemfiles/standalone.gemfile` and `gemfiles/rails.gemfile` — the matrix sets are audited by `bin/audit-advisories`, which the `audit:advisories` task rides on `rake compile` and the `spec` tasks (so `SKIP_COMPILE=1` cannot drop it), so every matrix entry audits the set it just resolved; the advisories of the floor lines the matrix resolves on purpose (Rails 7.2.x, Active Support 7.2.x on Ruby 3.1) are accepted by advisory id in `bin/audit-advisories`, scoped to the exact reviewed version, every other advisory fails the entry), full suite + Brakeman, gem specs across the Ruby matrix (generated from maintained CRuby versions), native builds on Linux/macOS arm64, `-Werror` with gcc and clang, ASAN/UBSAN (`use_sigaltstack=0`), pure-Ruby fallback, JRuby (Java escaper jar + `-java` gem) and TruffleRuby (pure Ruby) via `gemfiles/standalone.gemfile`, Rails integration per `gemfiles/rails.gemfile`, `bin/gem-smoke` packaging on plain RubyGems. Every job required; no `continue-on-error` |
| Canary | `.github/workflows/canary.yml`, monthly on the 1st, not gating: Ruby head and Rails edge surface upstream breaks before a release ships them; the monthly `improve` checkup fixes what it finds |
| Benchmarks | `.github/workflows/benchmark.yml`, non-gating: every push to `main` and PR renders a table into the job summary and uploads JSON; PRs get a sticky comment with the delta vs `main`. Set repo variable `BENCH_RUNNER` for a stable self-hosted runner; README holds only a dated release snapshot |
| Releases | `.github/workflows/release.yml`: merging a `version.rb` bump to `main` (no `v<VERSION>` tag yet) runs the tests and `rake smoke`, builds the `-java` gem on JRuby (jar inside), publishes **both** the C-extension gem and the `-java` gem via RubyGems trusted publishing (environment `release`), then creates the tag and the GitHub release from `bin/changelog-notes`. The release PR is opened by the agent or the `release` skill (`docs/release.md`) |
| Local hooks | lefthook pre-commit autocorrects staged Ruby files with RuboCop; the Claude Code PostToolUse hook reminds to recompile after `ext/` edits |
| Manual (owner only) | Breaking changes and major releases (escalated by the agent); one-time repo setup (RubyGems trusted publisher; ruleset requiring `CI OK`). Major dependency bumps: the agent like any other PR (`upgrade-deps` skill if by hand) |
| Docs rule | Don't hardcode version lists or benchmark numbers in docs; point at the CI matrix, `.ruby-version`, the lockfiles and the benchmark workflow instead |

## AI tooling in this repo

| Tool | Notes |
|---|---|
| `llms.txt` | The one user-facing reference for the gem (people and their LLM tools); hand-written, concise; keep accurate when behavior changes — there are no other usage docs to sync |
| Skills (`.claude/skills/`) | `release` (bump → changelog → verify → `release: X.Y.Z` PR; merging publishes; manual-only), `benchmark` (before/after), `add-html-tag`, `review` (checklist for `ext/` and renderer diffs), `debug-render` (C vs Ruby output diffs, sanitizer builds), `upgrade-deps` |
| Subagents (`.claude/agents/`, read-only tools) | `perf-reviewer`, `xss-auditor` — independent pass on hot-path or escaping changes |
| `.claude/settings.json` | Allowlists the routine workflow (specs, `rake`, rubocop, brakeman, bench scripts, `bin/*`, git add/commit/push/branch, `gh pr|issue|api|run|workflow`). Denied outright (never needed: merging a version bump publishes): `git tag`, force pushes, `rake release`, `gem push/yank`, `gh release`, reading `.env*`/`config/master.key`. PostToolUse hook (`.claude/hooks/post-edit-reminder.sh`, non-blocking) reminds to recompile after `ext/` edits and keep Native/PureRuby parity after renderer edits |

## Definition of done

`rake compile` clean → `CI=1 bundle exec rspec` and `RUBY2HTML_DISABLE_EXT=1 bundle exec rspec spec/gem` green → `bundle exec rubocop` clean → CHANGELOG/docs updated if behavior changed → benchmark numbers if a speedup is claimed.
