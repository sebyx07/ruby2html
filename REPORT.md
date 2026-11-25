## Symptom

The scheduled security release check asks whether a confirmed advisory fix shipped by the gem remains unreleased as of 2026-11-25. No failure was reported.

## Evidence

The scheduled `git describe` and path-filtered `git log` commands returned `LAST=v2.1.1` and no shipping commits after that tag on the local `origin/main` reference. That reference points to `ee6e1d3`, dated 2026-11-24. `CHANGELOG.md` has an empty Unreleased section, and the gem version is 2.1.1.

## Root cause

No shipped code changed in the checked window, so no commit in that window can be an unreleased advisory fix. No advisory source was investigated because there was no candidate commit. The decision is limited to the local `origin/main` reference available in this checkout and does not assert that the gem has no vulnerabilities.

## Fix

No release or product change is warranted. No external system was changed.

## Verify

Run `last=$(git describe --tags --abbrev=0 --match 'v[0-9]*' origin/main) && git log --format='%h %cI %s' "$last"..origin/main -- 'lib/gem/**' 'ext/ruby2html/*.c' 'ext/ruby2html/*.h' 'ext/ruby2html/extconf.rb' 'ext/java/*.java' ruby2html.gemspec`. At the checked reference, it prints nothing. No tests were run because no code changed.

no release: no shipped commits since v2.1.1.
