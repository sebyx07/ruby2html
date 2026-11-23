# Deployment

One lane, from `main`, through GitHub Actions. Nothing is published by hand: no `gem push`, no
hand-made tag.

- **The gems.** Merging a pull request that changes `lib/gem/ruby2html/version.rb` is the release:
  `.github/workflows/release.yml` verifies the commit, publishes the `-java` platform gem and the
  C-extension gem to RubyGems through trusted publishing (OIDC, no API key in the repository),
  and only then creates the `v` tag and the GitHub release from the version's `CHANGELOG.md`
  section. Procedure and recovery: [`docs/release.md`](../release.md).
- **Who decides.** The weekly `release-due` checkup (`.dz/schedules/release-due.md`) judges whether
  users get something from a release and opens the release pull request; `security-release`
  (`.dz/schedules/security-release.md`) covers a confirmed security fix on the other days. A major
  release is the owner's call.
- **Nothing else deploys.** The Rails app under `app/` is a demo and a test bed: `bin/dev` runs it
  locally, and no workflow deploys it.

Outcome checks: the daily `health` checkup (`.dz/schedules/health.md`) verifies that `main` is
green, the last release run succeeded, RubyGems serves `Ruby2html::VERSION`, benchmarks still run,
Dependabot is not stuck and the monthly canary (`.github/workflows/canary.yml`: Ruby head, Rails
edge) ran.
