# Brief: is a release due?

Weekday checkup, fired by `schedules: release-due` in `.dz/maintainer/maintainer.yml`. ruby2html
releases like a maintained gem: when merged work that ships has waited, it gets a release. This
brief only decides *when*; how is `docs/release.md`.

## Decide

```bash
last=$(git describe --tags --abbrev=0 --match 'v[0-9]*' origin/main)
git log --format='%h %cI %s' "$last"..origin/main -- 'lib/gem/**' 'ext/ruby2html/*.c' 'ext/ruby2html/*.h' 'ext/ruby2html/extconf.rb' ruby2html.gemspec
```

Those paths are what `ruby2html.gemspec` ships. README, LICENSE, CHANGELOG, specs, CI, the demo app,
benchmarks and docs ship nothing on their own and never owe a release.

| Window | Do |
|---|---|
| empty | nothing |
| `Ruby2html::VERSION` already ahead of `$last` | nothing: a release is in flight (`release.yml`) |
| the oldest shipping commit is under 24 h old | nothing: the owner may still release their own work |
| a **breaking** change under `## [Unreleased]` | no release PR: a major is the owner's. If no open issue says a major is pending, file one, for the owner, with no release steps |
| otherwise | one PR, **release: `<next>`** |

`<next>`: `### Added` under `## [Unreleased]` → minor; anything else → patch.

## The release PR, when due

1. Re-check the window on fresh `main`; still due, or stop.
2. `## [Unreleased]` empty (a Dependabot-only window)? Add a `### Changed` line per change that ships.
3. Bump `lib/gem/ruby2html/version.rb`; move `## [Unreleased]` under `## [<next>] - <today>`
   (keep an empty `## [Unreleased]` above it) and add the `[<next>]` link at the bottom.
4. `bundle exec rake compile && CI=1 bundle exec rspec && bundle exec rubocop && bundle exec rake smoke`.
5. One PR titled `release: <next>`, nothing else in it. It merges on green like any PR.
6. Merging it is the release: `release.yml` sees the version change on `main`, publishes the gem,
   then creates the tag and the GitHub release. Never tag and never `gem push` by hand.

Never open a second release PR while one titled `release: …` is open.
