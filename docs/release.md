# Release checklist

Releases go to RubyGems (`ruby2html`) and are tagged `vX.Y.Z` on GitHub (`sebyx07/ruby2html`). Agents: use the `release` skill (`.claude/skills/release/SKILL.md`); it follows this list and stops for confirmation before anything public.

**Pushing a `v*` tag publishes the gem.** `.github/workflows/release.yml` then: checks the tag equals `v#{Ruby2html::VERSION}`, compiles, runs `rspec` + rubocop + `rake smoke`, publishes with `rubygems/release-gem` (RubyGems Trusted Publishing, GitHub environment `release`; no API key in the repo), and creates a GitHub release with `pkg/*.gem` and notes from `bin/changelog-notes vX.Y.Z` (falls back to generated notes if the CHANGELOG section is missing).

## 0. Preconditions

- On `main`, clean tree, up to date with `origin/main`; CI green on that commit.
- One-time (maintainer): Trusted Publisher configured on rubygems.org for `sebyx07/ruby2html`, workflow `release.yml`, environment `release`. The gemspec sets `rubygems_mfa_required`.

## 1. Pick the version (SemVer)

- Patch: bug fixes only.
- Minor: new tags/helpers/options, perf work, intentional HTML output changes.
- Major: removed/renamed public API (`Render`, `plain`, `component`, `html` helpers, template handler) or a raised Ruby/Rails floor.

## 2. Bump and document

1. `lib/gem/ruby2html/version.rb` → `VERSION = 'X.Y.Z'` (single source; gemspec reads it).
2. `CHANGELOG.md`: move `## [Unreleased]` entries (including "Upgrading to 2.0" for a major) into `## [X.Y.Z] - YYYY-MM-DD`, leave an empty `## [Unreleased]`, update link references at the bottom. Check: `bin/changelog-notes X.Y.Z` prints the section.
3. If README benchmark numbers are refreshed, include Ruby version, YJIT state and machine.

## 3. Verify locally

```bash
bundle exec rake compile
CI=1 bundle exec rspec
bundle exec rubocop
bundle exec rake smoke      # builds pkg/ruby2html-X.Y.Z.gem, checks file list, installs into a temp GEM_HOME, renders without Rails
```

`rake build` writes `pkg/ruby2html-X.Y.Z.gem` (Bundler gem tasks; Rails is not booted). Optional manual check of the package contents:

```bash
tar -xOf pkg/ruby2html-X.Y.Z.gem data.tar.gz | tar -tz   # lib/gem/**/*.rb, ext/ruby2html/*.{c,h,rb}, README.md, LICENSE, CHANGELOG.md; no .so/.o (bin/gem-smoke checks this)
```

## 4. Commit, tag, push (explicit maintainer confirmation required)

```bash
git add lib/gem/ruby2html/version.rb CHANGELOG.md
git commit -m "Release vX.Y.Z"
git push origin main
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin vX.Y.Z          # triggers release.yml -> publishes
```

Do not run `rake release` locally (it tags, pushes and `gem push`es in one step, bypassing the workflow).

## 5. After

- Watch the run: `gh run watch` / `gh run list --workflow release.yml`.
- `gem list -r ruby2html` shows X.Y.Z; GitHub release exists with the `.gem` attached.
- Workflow failed before publishing: fix on `main`, delete the tag (`git push --delete origin vX.Y.Z && git tag -d vX.Y.Z`), re-tag. Failed after publishing: never reuse the version; release a patch. `gem yank` only by the maintainer.

## Manual fallback (workflow unavailable)

`bundle exec rake build` → `gem push pkg/ruby2html-X.Y.Z.gem` (OTP required) → `gh release create vX.Y.Z pkg/ruby2html-X.Y.Z.gem --notes-file <(bin/changelog-notes vX.Y.Z)`.
