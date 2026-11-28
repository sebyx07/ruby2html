# Deployment

One lane, from `main`, through GitHub Actions. Nothing is published by hand: no `gem push`, no
hand-made tag.

- **The gems.** Merging a pull request that changes `lib/gem/ruby2html/version.rb` is the release:
  `.github/workflows/release.yml` verifies the commit, publishes the `-java` platform gem and the
  C-extension gem to RubyGems through trusted publishing (OIDC, no API key in the repository),
  and only then creates the `v` tag and the GitHub release from the version's `CHANGELOG.md`
  section. Procedure and recovery: [`docs/release.md`](../release.md).
- **Who decides.** The weekly `release-due` checkup (`.dz/schedules/release-due.md`) judges whether
  users get something from a release and opens the release pull request. A fix for a published high or critical advisory in what the gem
  ships is the one release the owner may cut off-cycle. A major release is the owner's call.
- **Nothing else deploys.** The Rails app under `app/` is a demo and a test bed: `bin/dev` runs it
  locally, and no workflow deploys it.

Outcome checks: a workflow run is its own verdict, and the platform files a fix when `main` is red. Nothing polls the published package or the site on a schedule: the `health` checkup was removed on 2026-11-28 (across the fleet it fired 270 times in 30 days and produced no merged fix).
