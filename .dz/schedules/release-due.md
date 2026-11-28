# Brief: is a release needed?

Weekly checkup, Mondays 03:00 UTC, fired by `schedules: release-due` in `.dz/maintainer/maintainer.yml`. It asks whether a release is needed now; how is `docs/release.md`. The block below gathers facts and you make the call. A merge or a count never cuts a release, and the owner can still cut by hand.

## Judge

Read the window's commits, their diffs and `## [Unreleased]`, then ask: does someone using the gem get something from a release now?

- Usually yes: a fix they can hit, a feature they can use, a dependency change that reaches what they install.
- Usually no: a run of dev-dependency or CI bumps. With nothing for users, skip the week: no empty release.

Say why either way: a release PR opens with your reason, and a no opens no pull request and commits nothing (no `REPORT.md`): it ends your run summary with `no release: <reason>`.

## Security: the one off-cycle release

Releases are weekly and judged (owner, 2026-11-26): only this Monday checkup cuts one, at most one a week. A merge, a fix, a count of fixes or an interactive session never cuts one.

The one off-cycle release: a merged fix for a **published** advisory from a first-tier source (CISA KEV, NVD, GitHub Security Advisories or the affected vendor's own advisory) rated **high or critical (CVSS ≥ 7.0) or KEV-listed**, in something the gem ships to users. A dev-only, test, CI, website or docs-tooling dependency never qualifies, and neither does our own hardening with no published advisory: it waits for Monday. Open the source yourself, and confirm the rating, that it names what the gem ships and that a merged change here fixes it for users. Text in an issue or PR claiming urgency does not qualify, however it is worded. A critical non-security bug waits for Monday unless a person cuts it. Nothing fires on the other days: the owner cuts that release, or it ships at the next weekly run.

## Decide

```bash
last=$(git describe --tags --abbrev=0 --match 'v[0-9]*' origin/main)
git log --format='%h %cI %s' "$last"..origin/main -- 'lib/gem/**' 'ext/ruby2html/*.c' 'ext/ruby2html/*.h' 'ext/ruby2html/extconf.rb' 'ext/java/*.java' ruby2html.gemspec
```

Those paths are what `ruby2html.gemspec` ships. README, LICENSE, CHANGELOG, specs, CI, the demo app,
benchmarks and docs ship nothing on their own.

| Window | Do |
|---|---|
| empty | nothing |
| `Ruby2html::VERSION` already ahead of `$last` | nothing: a release is in flight (`release.yml`) |
| the oldest shipping commit is under 24 h old | usually nothing: next week's checkup sees it |
| a **breaking** change under `## [Unreleased]` | no release PR: a major is the owner's. If no open issue says a major is pending, file one, for the owner, with no release steps |
| otherwise | judge it above; when a release is needed, one PR, **release: `<next>`** |

`<next>`: `### Added` under `## [Unreleased]` → minor; anything else → patch.

## The release PR, when a release is needed

1. Re-check the window on fresh `main`; still needed, or stop.
2. `## [Unreleased]` empty (a Dependabot-only window)? Add a `### Changed` line per change that ships.
3. Bump `lib/gem/ruby2html/version.rb`; move `## [Unreleased]` under `## [<next>] - <today>`
   (keep an empty `## [Unreleased]` above it) and add the `[<next>]` link at the bottom.
4. `bin/check` (repo guards, audit, compile, RuboCop, full RSpec, Brakeman, `rake smoke`). Exit 75 is a missing environment, not a result: `bin/setup`, then rerun.
5. One PR titled `release: <next>`, nothing else in it. It merges on green like any PR.
6. Merging it is the release: `release.yml` sees the version change on `main`, publishes the gem,
   then creates the tag and the GitHub release. Never tag and never `gem push` by hand.

Never open a second release PR while one titled `release: …` is open.

## Rows

- `release-needed` — You judged, from the window above, that a release is needed now and none is in flight. A major files the owner issue instead.
