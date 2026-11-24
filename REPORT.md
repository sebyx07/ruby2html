## Symptom

The scheduled check asks whether an unreleased security fix requires an off-cycle release.

## Evidence

`git describe --tags --abbrev=0 --match 'v[0-9]*' origin/main` printed `v2.1.1`. The scheduled `git log` query for shipped paths from `v2.1.1` to `origin/main` printed no commits. `CHANGELOG.md` has an empty Unreleased section, and the gem version is `2.1.1`. GitHub's default branch listing shows a subsequent scheduled report commit, not a shipping commit.

## Root cause

There are no commits in the specified shipped paths since the latest release tag, so there is no candidate unreleased security fix to qualify against an advisory. This conclusion concerns the checkout's `origin/main` reference and does not assert that the gem has no vulnerabilities.

## Fix

No release or product change is warranted. No external advisory was checked because there is no candidate fix to evaluate. No infrastructure was changed.

## Verify

Run `last=$(git describe --tags --abbrev=0 --match 'v[0-9]*' origin/main) && git log --format='%h %cI %s' "$last"..origin/main -- 'lib/gem/**' 'ext/ruby2html/*.c' 'ext/ruby2html/*.h' 'ext/ruby2html/extconf.rb' 'ext/java/*.java' ruby2html.gemspec`. The query printed no commits in this run. Tests were not run because no product code changed.

no release: no shipped commits since v2.1.1.
