# Brief: is the project healthy?

Daily checkup, fired by `schedules: health` in `.dz/maintainer/maintainer.yml`. ruby2html is
maintained so that nobody has to watch it. This covers the failures no issue or PR announces.

| Signal | Command | Healthy |
|---|---|---|
| `main` is green | `gh run list --workflow ci.yml --branch main --event push --limit 1 --json conclusion,headSha` | `success` |
| the last release published | `gh run list --workflow release.yml --limit 1 --json conclusion,displayTitle` | `success` (or no run yet) |
| RubyGems serves `Ruby2html::VERSION` | `gem list ruby2html --remote --exact` vs `lib/gem/ruby2html/version.rb` | equal, or a release run is in flight |
| benchmarks still run | `gh run list --workflow benchmark.yml --branch main --limit 1 --json conclusion` | `success` |
| Dependabot is not stuck | `gh pr list --app dependabot --json number,createdAt` | none older than 7 days (app dependencies wait out the 14-day cooldown in `.github/dependabot.yml`; the dev-tools group is exempt via `cooldown.exclude` and opens within days) |
| canary ran | `gh run list --workflow canary.yml --limit 1 --json conclusion,createdAt` | a run in the last 35 days; its failures are the monthly `improve` checkup's job, not an issue |

## Rows

- `main-red`: the last push run of `ci.yml` on `main` did not conclude `success`.
- `release-unpublished`: the last `release.yml` run did not conclude `success`.
- `rubygems-version-lag`: RubyGems does not serve `Ruby2html::VERSION` from `lib/gem/ruby2html/version.rb`, and no release run is in flight.
- `benchmark-red`: the last `benchmark.yml` run on `main` did not conclude `success`.
- `dependabot-stuck`: a Dependabot PR is open more than 7 days.
- `canary-stale`: no `canary.yml` run in the last 35 days (a failed canary is the `improve` checkup's row, not this one).

For each unhealthy signal, file one issue unless an open issue already names it. The title names the
signal (`main is red at <sha>`, `release <v> did not publish`), and the body carries the command, its
output and the run URL. A red `main` comes first: nothing releases from it. Never delete a tag,
re-run a publish or `gem push` from here.
