---
name: release
description: Cut a ruby2html gem release - bump version, move CHANGELOG Unreleased into a dated section, verify and smoke-test the package, then (only after explicit user confirmation) commit, push and push the vX.Y.Z tag, which triggers the publishing workflow. Use when the user asks to release, publish, ship or bump the gem version.
disable-model-invocation: true
---

# Release ruby2html

Executable version of `docs/release.md` (read it if anything below is unclear). Argument: target version `X.Y.Z` or `patch|minor|major`.

Pushing a `vX.Y.Z` tag runs `.github/workflows/release.yml`, which tests and **publishes to RubyGems** and creates the GitHub release. Treat `git push origin vX.Y.Z` as the publish action.

One-time prerequisite (maintainer, not the agent): a Trusted Publisher on rubygems.org for gem `ruby2html` → GitHub Actions, repository `sebyx07/ruby2html`, workflow `release.yml`, environment `release`. If unsure it exists, ask before pushing the tag.

## Steps

1. **Preflight** (stop and report on any failure):
   - `git status --porcelain` empty, branch `main`, `git fetch origin && git status -sb` not behind.
   - Current version from `lib/gem/ruby2html/version.rb`; compute the new one. If the bump level conflicts with `## [Unreleased]` content (e.g. "Removed" with a patch), ask.
   - `## [Unreleased]` in `CHANGELOG.md` is non-empty. If empty, draft entries from `git log v<current>..HEAD --oneline` (no tag? use the commit that last changed `version.rb`) and get the user's approval of the text.
   - `git tag -l vX.Y.Z` and `gem list -r ruby2html --all` must not already contain X.Y.Z.
2. **Bump**: set `VERSION = 'X.Y.Z'`. In `CHANGELOG.md` move Unreleased entries to `## [X.Y.Z] - <today>`, add a fresh empty `## [Unreleased]`, update link references. Verify `bin/changelog-notes X.Y.Z` prints the section.
3. **Verify**: `bundle exec rake compile`, `CI=1 bundle exec rspec`, `bundle exec rubocop`, `bundle exec rake smoke`. All must pass.
4. **Summarize** for the user: old → new version, the changelog section, test/smoke results, `git diff --stat`. Then ask: "Commit and push v X.Y.Z tag (this publishes to RubyGems)? yes/no". **Proceed only on an explicit yes in the user's own message.**
5. **Publish** (after yes):
   ```bash
   git add lib/gem/ruby2html/version.rb CHANGELOG.md
   git commit -m "Release vX.Y.Z"
   git push origin main
   git tag -a vX.Y.Z -m "vX.Y.Z"
   git push origin vX.Y.Z
   ```
6. **Follow up**: `gh run list --workflow release.yml --limit 1` / `gh run watch <id>`. On success report `https://rubygems.org/gems/ruby2html/versions/X.Y.Z` and the GitHub release URL. On failure before the publish step, report the failing step; offer (do not do unasked) to delete and recreate the tag after a fix.

## Never

- Never push a tag, `git push`, `gem push` or run `rake release` without the confirmation in step 4. Do not use `rake release` at all (bypasses the workflow).
- Never reuse a version number; never `gem yank` unless the user asks.
- Manual `gem push` only if the user says the workflow is unavailable (see `docs/release.md`, "Manual fallback").
