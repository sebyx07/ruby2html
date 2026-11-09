---
name: release
description: Prepare a ruby2html release PR - bump version, move CHANGELOG Unreleased into a dated section, verify and smoke-test the package, and open a `release: X.Y.Z` PR. Merging that PR publishes (release.yml). Use when the user asks to release, publish, ship or bump the gem version.
disable-model-invocation: true
---

# Release ruby2html

Follows `docs/release.md`. Argument: target version `X.Y.Z` or `patch|minor|major`.

Merging a change to `apps/ruby2html/lib/gem/ruby2html/version.rb` into `main` runs `.github/workflows/release.yml`,
which **publishes to RubyGems**, then tags and creates the GitHub release. So opening the release PR
is safe; **merging it is the publish action**.

## Steps

1. **Preflight** (stop and report on any failure): clean tree; branch from up-to-date `origin/main`;
   `## [Unreleased]` non-empty (else draft entries from `git log <last tag>..HEAD` and get approval);
   `git tag -l vX.Y.Z` and `gem list -r ruby2html --all` do not contain X.Y.Z. A major needs the
   owner's explicit go-ahead.
2. **Bump**: `VERSION = 'X.Y.Z'`; CHANGELOG `## [X.Y.Z] - <today>` + empty `## [Unreleased]` + link
   reference; `bin/changelog-notes X.Y.Z` prints the section.
3. **Refresh the issue-template versions placeholder** in `.github/ISSUE_TEMPLATE/bug_report.yml`:
   gem version from `apps/ruby2html/lib/gem/ruby2html/version.rb`, Ruby version from
   `apps/ruby2html/.ruby-version`, Rails version from `apps/ruby2html/Gemfile.lock`.
   GitHub issue forms cannot derive the value at fill time, so it is refreshed here.
4. **Verify** (run from `apps/ruby2html`): `bundle exec rake compile`, `CI=1 bundle exec rspec`, `bundle exec rubocop`,
   `bundle exec rake smoke`.
5. **PR**: branch `release/X.Y.Z`, one commit `release: X.Y.Z`, PR titled `release: X.Y.Z` with the
   changelog section as the body, containing nothing else apart from the placeholder refresh in
   step 3. Ask before pushing if the user hasn't asked for the PR.
6. **Merge** only on green and only when the user (or, for non-major releases, the developerz.ai
   maintainer policy) authorizes it. Then watch `gh run list --workflow release.yml --limit 1`.

## Never

- Never push a `v*` tag, `gem push` or run `rake release`: release.yml owns tagging and publishing.
- Never reuse a version number; never `gem yank` unless the owner asks.
