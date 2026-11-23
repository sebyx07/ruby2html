# Standards

How work is done here, and the check that enforces each rule. The rules themselves live in
`CLAUDE.md` (invariants, never, conventions, pull requests) and the nested `ext/CLAUDE.md`,
`lib/CLAUDE.md`, `spec/CLAUDE.md` and `.github/CLAUDE.md`; this page is the map from rule to guard.
CI job names are those of `.github/workflows/ci.yml`; every job is required through `CI OK`.

| Rule | Enforced by |
|---|---|
| Guards, dependency audit, compile, lint, full specs, Brakeman, packaging | `bin/check`, which is CI's `check` job |
| The C extension and the pure-Ruby renderer are byte-identical | `RenderSpecHelper.describe_each` groups, `spec/gem/render_parity_spec.rb`, `spec/gem/render_fuzz_spec.rb`; CI job `fallback` |
| Text and attribute values are escaped; names are validated | `spec/gem/render_escape_spec.rb`, `spec/gem/render_attributes_spec.rb`, `spec/gem/render_hardening_spec.rb`; agent `xss-auditor` on review |
| C code is memory- and GC-safe, with no warnings | CI jobs `strict-ext` (gcc and clang, `-Werror`) and `sanitizers` (ASAN, UBSAN) |
| It works on every maintained CRuby, on arm64 and macOS | CI jobs `gem-specs`, `native`, `package` (generated Ruby matrix) |
| It works on JRuby and TruffleRuby | CI jobs `engines`, `rails-jruby` |
| The Rails integration works on every supported Rails line, on both renderers | CI job `rails` (generated Rails matrix); `spec/gem/rails/`, `spec/features/` |
| No known advisory in any resolved dependency set | `bundle-audit` (`bin/check`, CI job `audit`), `bin/audit-advisories`, `spec/ci/advisory_audit_spec.rb` |
| The gem builds, installs and renders without Rails; no build output is shipped | `bundle exec rake smoke` (`bin/gem-smoke`) |
| Ruby style; no syntax newer than the Ruby floor in `lib/` | RuboCop (`.rubocop.yml`, `bin/rubocop`) |
| `bin/check` and CI do not drift; the required check is still named `CI OK` | `bin/repo-guards` |
| Agent-read files carry no HTML comment or invisible character; `CLAUDE.md` stays under 12,000 characters; `AGENTS.md` is a symlink | `bin/repo-guards` |
| One Ruby pin (`.ruby-version`); `bin/setup` and `bin/brakeman` behave | `spec/bin/` |
| Workflows are valid; actions are pinned to a commit SHA; permissions are narrow | CI job `workflows` (actionlint, zizmor, `.github/zizmor.yml`) |
| A speed claim has numbers | `bundle exec rake bench`; `.github/workflows/benchmark.yml` comments on every pull request (not gating) |
| A release is a merged version bump with a CHANGELOG section, never a hand push | `.github/workflows/release.yml`, `bin/changelog-notes` |
| It still works on Ruby head and Rails edge | `.github/workflows/canary.yml` (monthly, not gating), the `improve` checkup |
| One concern per pull request; public API changes ask the owner | the reviewer (`.dz/maintainer/reviewer.md`), `escalate` in `.dz/maintainer/maintainer.yml` |
