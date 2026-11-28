# .github/ — CI, canary, benchmarks, release

Outside contributors do not change `.github/`, `bin/`, the `Rakefile` release tasks, the gemspec or `Ruby2html::VERSION` (owner only; dependency-bot bumps exempt): `.dz/maintainer/maintainer.yml`.

## Workflows

| File | Trigger | Does |
|---|---|---|
| `workflows/ci.yml` | pull request, push to `main`, manual | The gate. Ends in the aggregate job **`CI OK`** |
| `workflows/canary.yml` | monthly cron (the 1st), manual | Ruby head and Rails edge. **Not** part of `CI OK`; the monthly `improve` checkup (`.dz/schedules/improve.md`) reads it and fixes what it finds |
| `workflows/benchmark.yml` | pull request and push to `main` that touch what a benchmark measures (`lib/`, `ext/`, `bench/`, `bin/bench-report`, `bin/rails`, the Rakefile, `app/`, `config/`, `db/`, the bundle, `.ruby-version`; never a `CLAUDE.md`), manual | Non-gating. Renders a table into the job summary and uploads JSON per architecture; a PR gets one sticky comment per architecture with the delta against `main`. Repository variable `BENCH_RUNNER` selects a self-hosted runner for stable numbers |
| `workflows/release.yml` | push to `main` touching `lib/gem/ruby2html/version.rb`, manual | Verify, publish both gems, tag, GitHub release |
| `dependabot.yml` | weekly, Monday | bundler, github-actions, devcontainers and docker: minor+patch as one PR per ecosystem, security updates batched into one more, majors individually, at most 3 open version-update PRs per ecosystem (security updates have Dependabot's own cap), 14-day cooldown (security updates skip it). The maintainer agent is the only merger; there is no auto-merge workflow |
| `../bin/bench-charts` | by hand, after `bin/bench-report run docs/benchmarks/x86_64-linux.json` | Not a workflow: redraws `docs/benchmarks/*.svg` and the README Performance block from that committed run. `--check` (run by `spec/ci/bench_charts_spec.rb`, so by `bin/check`) fails when they drift |
| `zizmor.yml` | - | Reviewed exceptions for the workflow security linter, each with its reason |

## `ci.yml` jobs

| Job | Checks |
|---|---|
| `changes` | Reads the changed files: `code=false` when every one is `*.md` or under `docs/`. Every job below `check` then skips; anything unreadable counts as code |
| `workflows` | actionlint and zizmor on `.github/workflows`; `bin/repo-guards` |
| `check` | **`bin/check`, the local gate**, on `.ruby-version` with the committed `Gemfile.lock`: repo guards, `bundle-audit`, `rake compile`, RuboCop, the full RSpec suite, Brakeman, `rake smoke`. The only place RuboCop and Brakeman run in CI |
| `audit` | `bundle-audit check --update` on the committed root `Gemfile.lock`, with plain RubyGems and no bundle |
| `ruby-versions`, `rubies`, `rails-versions` | Generate the matrices: every maintained CRuby from the gemspec floor (`ruby/actions`; `rubies` drops head), every stable Rails minor from the demo floor (`bin/rails-versions`). A pull request keeps the oldest and the newest of each; a push to `main` that is not docs-only and a manual run test them all |
| `gem-specs` | `rake spec:standalone` on each maintained CRuby, `gemfiles/standalone.gemfile` (unlocked, no Rails) |
| `native` | `rake spec:gem` and `rake smoke` on Linux arm64 (gcc) and macOS arm64 (clang): the NEON path |
| `strict-ext` | `bin/build-ext --werror` with gcc and with clang, then `spec/gem` on that build |
| `sanitizers` | `bin/build-ext --sanitize`, then `spec/gem` with ASAN and UBSAN preloaded (`use_sigaltstack=0`) |
| `fallback` | `spec/gem` with `RUBY2HTML_DISABLE_EXT=1` |
| `engines` | JRuby (Java escaper jar, `-java` gem) and TruffleRuby (pure Ruby): `rake spec:standalone`, `bin/gem-smoke` |
| `rails` | `spec/features spec/gem/rails` per Rails minor, `gemfiles/rails.gemfile` (unlocked, `RAILS_VERSION`), once with the C extension and once with `RUBY2HTML_DISABLE_EXT=1` |
| `rails-jruby` | The same specs on JRuby, one Rails line: `activerecord-jdbcsqlite3-adapter` stands in for sqlite3 and exists only for some lines (`RAILS_VERSION` in the job; move it up when a newer adapter ships). `gemfiles/rails_common.rb` holds view_component below 4.16 there (it calls `Ractor` at boot) |
| `package` | `ruby bin/gem-smoke` with plain RubyGems (no Bundler) on each maintained CRuby |
| `ci-ok` (`CI OK`) | Fails unless every job above succeeded; cancelled counts as failed, and so does skipped unless `changes` said docs-only |

## Rules

- **The ruleset `main-protection` requires only `CI OK`.** Never rename that job (`bin/repo-guards` fails when the name is gone). A new job must be added to `ci-ok`'s `needs`, or it gates nothing. Live ruleset: `gh api repos/sebyx07/ruby2html/rulesets`.
- **`bin/check` is the `check` job.** Add a check to `bin/check`, not as a second workflow step, so local and CI cannot drift; `bin/repo-guards` fails when `ci.yml` stops running the bare `bin/check` or `bin/repo-guards`, or when `bin/check` stops running `bin/repo-guards`.
- Every job is required. No `continue-on-error`, no allowed failures. A flaky job is fixed or quarantined with an issue.
- **Dependency audits.** The root `Gemfile.lock`: jobs `audit` and `check`. The unlocked matrix gemfiles write their lockfile during the job (`gemfiles/*.lock`, gitignored); `rake audit:advisories` (`bin/audit-advisories`) audits that resolved set, riding on `rake compile` and on the spec tasks, so `SKIP_COMPILE=1` cannot drop it. Never move that audit into a workflow step, never set `SKIP_COMPILE` on a matrix job: `spec/ci/advisory_audit_spec.rb` fails.
- **Accepted advisories** live in `bin/audit-advisories`, by advisory id, scoped to the exact reviewed version of the floor lines the matrix resolves on purpose. A moved resolution drops every exception and fails the audit until the list is reviewed again. Never widen the list to get green.
- The matrices here and in `canary.yml` are the only place supported versions are listed. Docs link here; never copy the list.
- **Actions are pinned to a commit SHA** with the version in a trailing comment; `persist-credentials: false` on every checkout; top-level `permissions: contents: read`, widened per job only (`release.yml`: `contents: write` and `id-token: write` on the publish job; `benchmark.yml`: `pull-requests: write` for the sticky comment). zizmor fails the build otherwise. A new exception goes in `zizmor.yml` with its reason.
- The reusable workflow `ruby/actions/.github/workflows/ruby_versions.yml` has no tags: it is pinned to a `master` commit, and Dependabot does not move it. Bump it by hand when the version list it returns goes stale.
- A `.ruby-version` bump can need a newer `ruby/setup-ruby` than the 14-day cooldown has proposed: bump the pin (SHA and version comment) in the same PR.
- No expression interpolation inside `run:`; pass `${{ ... }}` through `env:`.
- A red canary never blocks a PR; fix it in its own PR before the upstream release ships.

Before pushing a workflow change, from the repository root:

```bash
docker run --rm -v "$PWD":/repo -w /repo rhysd/actionlint:1.7.12
pipx run zizmor==1.33.1 .github/workflows
bin/repo-guards
```

The versions are the ones the `workflows` job of `ci.yml` runs; change them there and here together.

## Release lane

Source of truth: `docs/release.md`. Prepare with skill `release`.

1. PR titled `release: <version>`, nothing else in it: bump `VERSION` in `lib/gem/ruby2html/version.rb`; move `## [Unreleased]` in `CHANGELOG.md` into `## [<version>] - YYYY-MM-DD`, leaving an empty `Unreleased`, and add the link at the bottom; refresh the versions placeholder in `ISSUE_TEMPLATE/bug_report.yml`. Check: `bin/changelog-notes <version>` prints the section.
2. `CI OK` green, merge. **The merge is the release.**
3. `release.yml`: `version` (is there a tag `v<VERSION>` yet?) then `test` (CHANGELOG section, compile, RSpec, RuboCop, `rake smoke`) and `jruby` (builds the `-java` gem), then `release` (RubyGems trusted publishing through OIDC, environment `release`, no API key: the `-java` gem, then the C-extension gem; then the tag and the GitHub release with notes from `bin/changelog-notes`).

Rules:

- Never `gem push`, `rake release`, `gh release create`, or push a `v*` tag. The tag is an output of the release, created after RubyGems has the gems.
- A merge that does not change `version.rb` publishes nothing. Do not write "released" until `gem list -r ruby2html` shows the version.
- A published version is never pushed again, and never bumped past to repair it. Recovery for a run that failed before or after publishing: `docs/release.md`, section "After". `gem yank`: the owner only.
- The weekly `release-due` checkup (`.dz/schedules/release-due.md`) decides when a release PR is opened; a fix for a published high, critical or KEV-listed advisory in what ships is the one release the owner may cut off-cycle. A major release is the owner's call.
- One-time owner setup: the RubyGems trusted publisher (repository `sebyx07/ruby2html`, workflow `release.yml`, environment `release`) and the ruleset requiring `CI OK`.
