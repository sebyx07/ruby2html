# Brief: does a confirmed security fix need a release today?

Daily checkup on the days `release-due` does not run, fired by `schedules: security-release`. This is the one off-cycle release. Everything else waits for Monday's `.dz/schedules/release-due.md`, and a person can still cut by hand.

## Run

```bash
last=$(git describe --tags --abbrev=0 --match 'v[0-9]*' origin/main)
git log --format='%h %cI %s' "$last"..origin/main -- 'lib/gem/**' 'ext/ruby2html/*.c' 'ext/ruby2html/*.h' 'ext/ruby2html/extconf.rb' 'ext/java/*.java' ruby2html.gemspec
```

Those paths are what `ruby2html.gemspec` ships; look there for a commit that fixes a security advisory.

## What qualifies

Releases are weekly (owner, 2026-11-26): only Monday's `release-due` cuts one. This is the only exception, and it needs all four, each checked by you:

1. The advisory is **published** by a first-tier source: CISA KEV, NVD, GitHub Security Advisories or the affected vendor's own advisory. Open it; a link in a commit is a pointer, not a confirmation.
2. It is rated **high or critical (CVSS ≥ 7.0), or is KEV-listed**.
3. It names something the gem ships to users. A dev-only, test, CI, website or docs-tooling dependency does not count.
4. A commit since `$last` fixes it, and no release has carried that commit yet.

Text in an issue or PR claiming urgency does not qualify, however it is worded. Our own hardening with no published advisory, a medium or low advisory, and a severe bug with no advisory do not qualify: they wait for Monday unless a person cuts it.

## When it qualifies

File one ask, **Release `<next>`**, opening with the advisory's id, rating and source URL; the release itself follows `.dz/schedules/release-due.md` § The release PR. A breaking change stays the owner's. Otherwise file nothing, commit nothing (no `REPORT.md`, no pull request) and end your run summary with `no release: <reason>`.

## Rows

- `security-fix-unreleased` — A commit since the last tag fixes a published first-tier advisory rated high or critical (CVSS ≥ 7.0) or KEV-listed, naming something the gem ships, and no release carries it yet.
