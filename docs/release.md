# Release checklist

Releases go to RubyGems (`ruby2html`) and are tagged `vX.Y.Z` on GitHub (`sebyx07/ruby2html`).

**Merging a version bump to `main` is the release.** When `lib/gem/ruby2html/version.rb` changes on
`main` and tag `vX.Y.Z` does not exist yet, `.github/workflows/release.yml`:
1. checks that `CHANGELOG.md` has a `## [X.Y.Z]` section, then runs compile, `rspec`, rubocop and `rake smoke`, plus a JRuby install;
2. publishes the gem (RubyGems trusted publishing, GitHub environment `release`; no API key in the repo);
3. only then creates the tag and the GitHub release, with the `.gem` attached and notes from `bin/changelog-notes`.

Nobody tags or `gem push`es by hand. The developerz.ai maintainer agent decides when a release is due
and opens the release PR (`.dz/briefs/release-due.md`). A **major** release is the owner's call: the
agent never opens one.

## The release PR

1. Pick the version (SemVer): patch for fixes; minor for new tags/helpers/options, perf work or intentional output changes; major for removed or renamed public API, or a raised Ruby/Rails floor.
2. `lib/gem/ruby2html/version.rb` → `VERSION = 'X.Y.Z'` (the gemspec reads it).
3. `CHANGELOG.md`: move `## [Unreleased]` into `## [X.Y.Z] - YYYY-MM-DD` (with "Upgrading to X.0" for a major), leave an empty `## [Unreleased]`, add the `[X.Y.Z]` link at the bottom. `bin/changelog-notes X.Y.Z` must print the section.
4. Verify: `bundle exec rake compile && CI=1 bundle exec rspec && bundle exec rubocop && bundle exec rake smoke`.
5. One PR titled `release: X.Y.Z`, containing nothing else. Merge on green.

## After

- `gh run list --workflow release.yml --limit 1`; `gem list -r ruby2html` shows X.Y.Z; the GitHub release exists.
- Failed before publishing: fix on `main` and re-run the workflow (`workflow_dispatch`); it releases whatever version has no tag yet.
- Failed after publishing (gem is out, tag missing): re-run the workflow; never reuse or bump past a published version to "fix" it. `gem yank` only by the owner.

## One-time setup (owner)

- rubygems.org → gem `ruby2html` → Trusted publishers → GitHub Actions: repository `sebyx07/ruby2html`, workflow `release.yml`, environment `release`.
