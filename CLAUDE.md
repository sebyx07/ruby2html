# CLAUDE.md

For agents working **on** this repository. **Budget: under 12,000 chars** (the developerz.ai loader cuts the rest; `bin/repo-guards` enforces it). Move detail down, never raise the cap:

| Touching | Also read (auto-loads there) |
|---|---|
| `ext/` | [`ext/CLAUDE.md`](ext/CLAUDE.md): C file map, GC safety, build variants, the JRuby Java escaper |
| `lib/` | [`lib/CLAUDE.md`](lib/CLAUDE.md): Ruby code map, renderer and template-compiler rules, public API |
| `spec/` | [`spec/CLAUDE.md`](spec/CLAUDE.md): spec layout, both-implementation groups, guard specs |
| `.github/`, `docs/release.md`, `lib/gem/ruby2html/version.rb` | [`.github/CLAUDE.md`](.github/CLAUDE.md): CI jobs, canary, benchmarks, Dependabot, release lane |

`AGENTS.md` is a symlink to this file; there are no other per-tool instruction files. Writing ruby2html templates or components (here or in a user app): load [`llms.txt`](llms.txt), the complete user reference. Internals: [`docs/architecture.md`](docs/architecture.md). Intent and direction (draft): [`docs/idea/`](docs/idea/); index: [`docs/README.md`](docs/README.md).

## ruby2html

RubyGems gem (`ruby2html.gemspec`; version in `lib/gem/ruby2html/version.rb`) that renders HTML from a Ruby block DSL. The repository is both the gem and a Rails demo app around it.

| Part | Path | Notes |
|---|---|---|
| Gem (Ruby) | `lib/gem/ruby2html.rb`, `lib/gem/ruby2html/**` | Packaged; `spec.require_paths = ['lib/gem']`; **no runtime dependencies** |
| C extension | `ext/ruby2html/*.{c,h}`, `extconf.rb` | `Ruby2html::Native`, CRuby only. `rake compile` writes `lib/ruby2html/ruby2html.so` (gitignored) |
| Pure-Ruby twin | `lib/gem/ruby2html/render/pure_ruby.rb` | `Ruby2html::PureRuby`: used when the `.so` is missing, on JRuby and TruffleRuby, or with `RUBY2HTML_DISABLE_EXT=1` |
| Java escaper | `ext/java/Ruby2htmlJrubyService.java` | `Ruby2html::JavaNative.escape`, JRuby's only native code; ships in the `-java` platform gem |
| Rails integration | `lib/gem/ruby2html/railtie.rb`, `rails_components/**`, `component*.rb` | `.html.rb` template handler, Prism template compiler, components, helper wrappers |
| Demo Rails app | `app/`, `config/`, `db/` | Not packaged; loads the gem with `require_relative '../lib/gem/ruby2html'` |
| Specs, benchmarks | `spec/`, `bench/*.rb`, `spec/benchmarks/` | RSpec; benchmark scripts; request-level comparison against ERB, Slim, Phlex |

Supported: every maintained CRuby from the gemspec floor up, JRuby, TruffleRuby, Rails from the demo app's floor up. Tested versions are generated in `.github/workflows/ci.yml`; the dev Ruby is `.ruby-version`. Never restate version lists or benchmark numbers in docs: point at the CI matrix, the lockfiles and the benchmark workflow. RuboCop's `TargetRubyVersion` is the floor: no newer syntax in `lib/`.

## Invariants

1. **Native and PureRuby are byte-identical** for every input: HTML, encoding and raised errors. A rule change lands in the C files **and** `pure_ruby.rb`, with a spec in a `RenderSpecHelper.describe_each` group or `spec/gem/render_parity_spec.rb`. The Java escaper is a third side of the escape rule.
2. **Escaping is a security boundary.** Text and attribute values are escaped by default; raw only for `html_safe?` objects and `component`; a plain `String` (exact class) is never safe. Attribute and tag **names** are validated (raise), never escaped. Every escaping change: specs in both modes plus an `xss-auditor` pass.
3. **Never cache by `Object#hash`.** A collision returns another input's output (the removed `ATTRIBUTE_CACHE` did exactly this). Exact-equality keys only, and only with a benchmark that proves a win.
4. **GC safety in C.** `RB_GC_GUARD` every `VALUE` whose pointer outlives an allocating or yielding call; re-read `RSTRING_PTR(buf)` after growth; use `buffer.h`. A miss is a rare crash under GC stress, not a failing spec. Detail: `ext/CLAUDE.md`.
5. **Speed over memory.** No per-call allocation on hot paths (tag methods, `plain`, attributes, escape); intern IDs at Init; generate at load or compile time, not per call. A speed claim needs before/after numbers (skill `benchmark`).
6. **Public API is a contract** (list: `lib/CLAUDE.md`). A breaking change needs the owner's decision, a CHANGELOG "Upgrading" entry and a major bump.

## Never

- `gem push`, `rake release`, `gem yank`, `gh release`, a `v*` tag, or a force push. Release = merge a `version.rb` bump (`docs/release.md`); the tag is an output of `release.yml`.
- Commit build output: `lib/ruby2html/*.so`, `*.jar`, `*.class`, `tmp/`, `pkg/`, `*.gem`, `log/`.
- Run specs after editing `ext/` without `bundle exec rake compile`: they load the stale `.so` (or PureRuby when none exists) and pass on code you did not test.
- Add a runtime dependency to the gemspec, or make `require 'ruby2html'` heavier (Prism, the ERB engine and `htmlbeautifier` stay lazy).
- Add backwards-compatibility shims, dead-code comments or speculative abstractions.
- Weaken the gate to get green: a RuboCop exclusion, a skipped or deleted spec, `continue-on-error`, a new `.github/zizmor.yml` exception without its reason.
- Use git worktrees, `git stash`, `git add -A` or `git add .`. Agents share this checkout: stage by path.
- Read `config/master.key` or `.env*` into a prompt, a log or a commit.
- Add a Claude Code hook or an allow/deny list to `.claude/settings.json`. Agents run with full permissions; a rule that must hold becomes a check in `bin/check`.

## Commands

| Task | Command |
|---|---|
| Install | `bin/setup`: mise toolchain, gems, `bundler-audit`, C extension, demo database, lefthook. Idempotent. `--skip-db` for gem-only work |
| Pre-PR gate | `bin/check`: repo guards, `bundle-audit` on `Gemfile.lock`, `rake compile`, RuboCop, full RSpec, Brakeman, `rake smoke`. CI's `check` job runs this same script |
| Inner loop | `bin/check fast`: repo guards, compile, RuboCop, `spec/gem` (seconds). Skips `spec/features`, `spec/ci`, `spec/bin`, the audit, Brakeman and packaging |
| Compile | `bundle exec rake compile`; `RUBY2HTML_NO_SIMD=1` for the scalar escape path; strict, clang and sanitizer builds: `bin/build-ext --help` |
| Specs | `CI=1 bundle exec rspec` (full, minus the ~6 min request benchmark that `CI` skips) · `bundle exec rspec spec/gem` · `bundle exec rspec path_spec.rb:LINE` |
| PureRuby process | `RUBY2HTML_DISABLE_EXT=1 bundle exec rspec spec/gem` |
| Without Rails | `bundle exec rake spec:standalone` (`spec/gem` minus `rails/`; what JRuby, TruffleRuby and the Ruby matrix run) |
| Lint | `bin/rubocop` · fix: `bundle exec rubocop -a <file>` · `bin/brakeman --no-pager` |
| Benchmarks | `bundle exec rake bench` (compiles, runs every `bench/*.rb`); request level: `bundle exec rspec spec/benchmarks/` |
| Package | `bundle exec rake smoke`: build, install into a temporary `GEM_HOME`, render without Rails (`bin/gem-smoke`) |
| Demo app | `bin/dev` (`bin/rails server`): `/`, `/rb_files`, `/form`, `/benchmark/{html,ruby,compruby,slim,phlex}` · `bin/stop` |
| Console | `bin/console`: IRB with the gem loaded, no Rails |

**Exit codes of `bin/check`:** 0 green. **75 = environment missing (bundle, `bundle-audit`): nothing was graded.** Run `bin/setup` and rerun; never report 75 as a failing change, never as a pass. 1: a step ran and is red; the summary prints the command to rerun.

`bin/check` does not run the CI-only jobs (version matrices, arm64 and macOS, `-Werror`, ASAN/UBSAN, the PureRuby-only run, JRuby, TruffleRuby, actionlint, zizmor). Green locally can still be red in CI: `gh run view --log-failed` names the command.

Rake: the gem tasks (compile, spec, bench, smoke, build, audit) do not boot Rails; any other task loads the Rails tasks (`Rakefile`).

## Verify by area

`bin/check` plus the row below. The per-file runs for `ext/`, `lib/` and workflows are in the nested file's own table.

| You changed | Also run | And |
|---|---|---|
| `ext/**`, `render.rb`, `render/pure_ruby.rb` | `RUBY2HTML_DISABLE_EXT=1 bundle exec rspec spec/gem`; for C: `bin/build-ext --werror` (and `--cc=clang`) | `rake bench` before and after on a hot path; skills `review`, `debug-render` |
| Escaping or attributes, either side | both processes plus new specs for the case | agent `xss-auditor` |
| `railtie.rb`, `rails_components/**`, `component*.rb` | `CI=1 bundle exec rspec spec/gem/rails spec/features` | try the demo pages |
| gemspec, `Rakefile`, packaging | `bundle exec rake smoke` | `tar -xOf pkg/*.gem data.tar.gz \| tar -tz` |
| `Gemfile`, dependencies | `bin/setup`, then `bin/check` | skill `upgrade-deps` |
| Docs only | check every claim against the code | snippets: `bundle exec ruby -Ilib/gem -Ilib -e '...'` |

## Conventions

- Match nearby code. Ruby: rubocop-rails_config, single quotes, `# frozen_string_literal: true`, nested modules, Rails-style indented `private`. C: gnu99, no warnings under `-Wall -Wextra`.
- Test first; a renderer rule gets a spec that runs on both implementations.
- User-visible change: `CHANGELOG.md` under `## [Unreleased]`, and `llms.txt` when DSL behavior changes (the one user reference; nothing else to sync).
- lefthook (from `bin/setup`): RuboCop autocorrect on commit, `rake spec:gem` on push. The gate is `bin/check` and CI.

## Pull requests

- **`CI OK` is the required check** (ruleset `main-protection`): the aggregate job of `ci.yml`; every job must pass. Live rules: `gh api repos/sebyx07/ruby2html/rulesets`.
- A PR body claims only what the diff does; evidence you could not get is stated as missing.
- One concern per PR. Keep it a draft (or `WIP` in the title) until ready: a ready, reviewed, green PR is merged by the maintainer bot.
- Done: `bin/check` green, the area row above run, CHANGELOG and docs true, benchmark numbers when a speedup is claimed.

## Maintenance model

Hand maintenance is limited to owner decisions: breaking changes, major releases, one-time repo setup.

| What | How |
|---|---|
| Maintainer agent | developerz.ai, policy in `.dz/` (`.dz/README.md`): triages issues, reviews every PR, merges on a green `CI OK`, runs the scheduled checkups in `.dz/schedules/`. Outside changes to `.github/`, `bin/`, release tasks, the gemspec or `VERSION` stay with the owner |
| CI | `.github/workflows/ci.yml`, aggregate `CI OK`. Dependency audits: `bundle-audit` on the committed root `Gemfile.lock` (jobs `audit` and `check`), and `bin/audit-advisories` on the set each unlocked matrix gemfile (`gemfiles/*.gemfile`) resolves, riding on `rake compile` and the spec tasks. Jobs and rules: `.github/CLAUDE.md` |
| Dependencies | Dependabot: weekly, grouped, 14-day cooldown in every ecosystem; the maintainer agent is the only merger (no auto-merge workflow) |
| Releases | Merging a `version.rb` bump to `main` publishes both gems (C extension and `-java`) through RubyGems trusted publishing, then tags. Steps: `docs/release.md`, skill `release` |

## AI tooling

| Tool | Notes |
|---|---|
| Skills (`.claude/skills/`) | `release`, `benchmark`, `add-html-tag`, `review` (checklist for `ext/` and renderer diffs), `debug-render` (C against Ruby output, sanitizer builds), `upgrade-deps` |
| Agents (`.claude/agents/`) | `perf-reviewer`, `xss-auditor`: fresh-context review of hot-path or escaping changes; they report, they do not edit |
| Commands (`.claude/commands/`) | `/planx` (a plan under `docs/plans/`; not for a one-file fix), `/feature` (one change to merged), `/bug-sweep` (one area, a failing spec per defect) |
| `.claude/settings.json` | `bypassPermissions` and nothing else |
| `.mcp.json` | `codegraph`, `sentry-mcp`, `developerz`; secrets come from the environment (`.env.example`), stdio packages are pinned to an exact version |
| `bin/repo-guards` | Fails on CI and `bin/check` drift, invisible characters or HTML comments in agent-read files, a rerouted API or auto-started MCP servers in settings, this file reaching 12,000 chars, `AGENTS.md` not being a symlink |
