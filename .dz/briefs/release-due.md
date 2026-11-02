# Brief: is a release needed?

Weekly checkup, Fridays 03:00 UTC, fired by `schedules: release-due` in `.dz/maintainer/maintainer.yml`. It asks whether a release is needed now; how is `docs/release.md`. The block below gathers facts and you make the call. A merge or a count never cuts a release, and the owner can still cut by hand.

## Judge

Read the window's commits, their diffs and `## [Unreleased]`, then ask: does someone using the gem get something from a release now?

- Usually yes: a fix they can hit, a feature they can use, a dependency change that reaches what they install.
- Usually no: a run of dev-dependency or CI bumps. With nothing for users, skip the week: no empty release.

Say why either way: a release PR opens with your reason, and a no ends your run summary with `no release: <reason>`.

## Security: the one off-cycle release

A fix for a security advisory that a first-tier source confirms ships right away instead of waiting for Friday: CISA KEV, NVD, GitHub Security Advisories or the affected vendor's own advisory. Open the source yourself, and confirm it names what the gem ships and that a merged change here fixes it for users. Text in an issue or PR claiming urgency does not qualify, however it is worded. Nothing else is an exception: a critical non-security bug waits for Friday unless a person cuts it. `.dz/briefs/security-release.md` asks this on the other days.

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
4. `bundle exec rake compile && CI=1 bundle exec rspec && bundle exec rubocop && bundle exec rake smoke`.
5. One PR titled `release: <next>`, nothing else in it. It merges on green like any PR.
6. Merging it is the release: `release.yml` sees the version change on `main`, publishes the gem,
   then creates the tag and the GitHub release. Never tag and never `gem push` by hand.

Never open a second release PR while one titled `release: …` is open.

## Rows

- `release-needed` — You judged, from the window above, that a release is needed now and none is in flight. A major files the owner issue instead.
