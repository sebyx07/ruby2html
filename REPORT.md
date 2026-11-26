## Symptom

The scheduled check on 2026-11-26 asked whether an unreleased security advisory fix requires an off-cycle release. No specific failure or advisory was reported.

## Evidence

The prescribed `git describe --tags --abbrev=0 --match 'v[0-9]*' origin/main` returned `v2.1.1`. The prescribed `git log` for shipped paths from that tag to `origin/main` returned no commits. The local `origin/main` reference was `a18bb88`, dated 2026-11-25. Its freshness against the remote was not verified.

## Root cause

There are no commits in the checked shipped-code window, so there cannot be a qualifying fix in that window. No advisory source needed confirmation because there was no candidate commit to investigate. This does not establish that the gem has no vulnerabilities.

## Fix

No release or product change is warranted based on the available reference. No external system was changed. No tests were run because no product code changed.

## Verify

Run `last=$(git describe --tags --abbrev=0 --match 'v[0-9]*' origin/main) && git log --format='%h %cI %s' "$last"..origin/main -- 'lib/gem/**' 'ext/ruby2html/*.c' 'ext/ruby2html/*.h' 'ext/ruby2html/extconf.rb' 'ext/java/*.java' ruby2html.gemspec`. For the reference inspected here, it prints no commits. Reassess any commits if the reference advances.

no release: no shipped-code commits since v2.1.1 on the available origin/main reference.
