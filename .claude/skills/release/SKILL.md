---
name: release
description: Prepare a ruby2html release PR - bump version, move CHANGELOG Unreleased into a dated section, verify and smoke-test the package, and open a `release: X.Y.Z` PR. Merging that PR publishes (release.yml). Use when the user asks to release, publish, ship or bump the gem version.
disable-model-invocation: true
---

# Release ruby2html

Follows `docs/release.md`. Argument: target version `X.Y.Z` or `patch|minor|major`.

Merging a change to `lib/gem/ruby2html/version.rb` into `main` runs `.github/workflows/release.yml`,
which **publishes to RubyGems**, then tags and creates the GitHub release. So opening the release PR
is safe; **merging it is the publish action**.

## Steps

1. **Preflight** (stop and report on any failure): clean tree; branch from up-to-date `origin/main`;
   `## [Unreleased]` non-empty (else draft entries from `git log <last tag>..HEAD` and get approval);
   `git tag -l vX.Y.Z` and `gem list -r ruby2html --all` do not contain X.Y.Z. A major needs the
   owner's explicit go-ahead.
2. **Bump**: `VERSION = 'X.Y.Z'`; CHANGELOG `## [X.Y.Z] - <today>` + empty `## [Unreleased]` + link
   reference; `bin/changelog-notes X.Y.Z` prints the section.
3. **Verify**: `bundle exec rake compile`, `CI=1 bundle exec rspec`, `bundle exec rubocop`,
   `bundle exec rake smoke`.
4. **PR**: branch `release/X.Y.Z`, one commit `release: X.Y.Z`, PR titled `release: X.Y.Z` with the
   changelog section as the body. Ask before pushing if the user hasn't asked for the PR.
5. **Merge** only on green and only when the user (or, for non-major releases, the developerz.ai
   maintainer policy) authorizes it. Then watch `gh run list --workflow release.yml --limit 1`.

## Never

- Never push a `v*` tag, `gem push` or run `rake release`: release.yml owns tagging and publishing.
- Never reuse a version number; never `gem yank` unless the owner asks.
