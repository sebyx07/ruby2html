# Devops checkup

Weekly checkup, Saturdays 00:00 UTC, OFFERED and off: the `devops` entry in
`.dz/maintainer/maintainer.yml` is commented out, and uncommenting it is the opt-in. It is the
developerz.ai platform's standard devops checkup, adapted to ruby2html: how this repository ships,
graded on five axes. A read-only scout: you read files only, no shell, network or database. You
also have the Signals block: recent CI job failures and failed tasks.

What ships here: two RubyGems packages built from one `ruby2html.gemspec`, the C-extension gem and
the `-java` platform gem with a prebuilt escaper jar, published by
`.github/workflows/release.yml` through RubyGems trusted publishing when
`lib/gem/ruby2html/version.rb` changes on `main`. The gem has no runtime dependency. The Rails app
under `app/` is a demo and a test bed: it is not packaged and not deployed. There is no server,
container or database in production.

**Evidence or nothing.** Every point lost names a `path:line` or a Signals line. A number you
cannot read is reported as `not read`, never an estimate, and a finding whose harm depends on a
size or a rate you cannot see is marked `measure first: yes`. Do not fix what is not broken.

## The axes

1. **Reliable.** Does a change get proved before it ships, and can a bad one be undone?
   - `bin/check` and CI run the same gate (the `check` job of `ci.yml` runs `bin/check`; the
     aggregate `CI OK` job needs every other job; `bin/repo-guards` fails when either drifts), and
     `release.yml` verifies the commit before it publishes.
   - What `bin/check` cannot run is still proved before merge (a pull request runs the oldest and
     the newest Ruby and Rails, every code push to `main` the full matrices): the Ruby and Rails matrices, the
     pure-Ruby run (`RUBY2HTML_DISABLE_EXT=1`), JRuby and TruffleRuby, `-Werror` and the
     sanitizers. A job missing from `CI OK`'s `needs` gates nothing.
   - `Gemfile.lock` is committed and agrees with `Gemfile`; Ruby is pinned once, in
     `.ruby-version`, and `mise.toml` reads it.
   - A bad release can be undone: `docs/release.md` § After says how (fix on `main` and ship a new
     patch; a published version is never pushed again; `gem yank` is the owner's).
   - Signals: the same CI job or task failure kind recurring. Report the counts as they stand.
2. **Secure.** What could leak, or run that nobody reviewed?
   - A secret, token or RubyGems credential committed to the tree. Quote the key and path, never
     the value. Publishing is OIDC: an API key for RubyGems anywhere is a finding.
   - Third-party actions pinned to a full commit SHA; workflow `permissions` declared and narrow;
     `persist-credentials: false` on checkouts; no `pull_request_target`.
   - The dependency audits still reach every resolved set: `bundle-audit` on `Gemfile.lock`, and
     `bin/audit-advisories` on the matrix gemfiles, with no exception wider than a reviewed
     advisory id at a reviewed version.
   - In the gem: code that runs at install or `require` beyond compiling the extension; a file in
     `spec.files` that is build output from this machine.
3. **Fast.** How long does a change wait for its answer?
   - CI that repeats work: serial jobs that could run side by side, a matrix entry compiling what
     an earlier step built, a job installing a bundle it does not use.
   - Superseded CI runs left running (`concurrency`).
   - `bin/check fast` still answers in seconds: a slow step added to the inner loop is a finding.
4. **Efficient.** What does this repository carry that it does not use?
   - A gem in `Gemfile` nothing requires, two tools doing one job, a file in the packaged gem that
     users never load.
   - A generated artifact committed beside its source (`lib/ruby2html/*.so`, the escaper jar,
     `pkg/`, `tmp/` are never committed).
5. **Cheap.** What costs money every day without paying for itself?
   - A scheduled workflow or checkup far more frequent than its result is read; a matrix wider
     than the Ruby, Rails and platform versions supported (the matrices are generated: a
     hand-added entry is the finding).
   - Workflow artifacts (benchmark JSON, built gems) kept with no expiry.
   - Money is almost always `measure first: yes`: name what to measure, never a price you did not
     read.

**CI configuration is graded, never filed.** Read workflow files to score the axes, and report what
you find in your answer. Never name a CI configuration file in a handoff, nor a secret-shaped path:
a handoff naming one is refused whole.

## Rows

One per axis; a handoff reports one failing row.

- `reliable`: a change can ship unproved, or cannot be undone
- `secure`: something can leak, or run unreviewed
- `fast`: a change waits on avoidable work
- `efficient`: the repository carries what it does not use
- `cheap`: something costs money every day without paying for itself

## How to judge

- Confirm before you claim: read the file that does the thing, not only a file that mentions it.
- Rank by blast radius: what breaks or leaks for users first, money last.
- Skip specs, fixtures, generated and vendored code.
- A check that does not apply to this repository is not a failure.
- One handoff per row: every defect on an axis goes in it, worst first.
- A row that already has an open issue is scored, not filed again.

## Every finding

Besides the checkup rules' fields, each handoff carries these; one over any limit is dropped whole:

- **work**: one sentence naming the defect and the fix, at most 300 characters.
- **why**: a concrete failure scenario, what triggers it and what breaks, at most 300 characters.
- **evidence**: at most 10 lines of at most 280 characters each. One line `path:line: the code` per
  site. The last line starts `measure first:`, `no` with the reason or `yes` with what to measure
  and how.
- **paths**: at most 20 files.
- **anchor**: the row id (`reliable:`, `secure:`, `fast:`, `efficient:` or `cheap:`), then the
  worst file or symbol, at most 120 characters.
- **metric**: the number the fix moves, at most 200 characters.

## Report

First the score, then the findings.

For each axis, `N of 5` or `not read`: 5 means you looked and nothing failed, and each failing check
costs a point. One line per point lost, with its evidence. Then the total, `N of 25`, or `N of M
over K axes read`, with the change since the last checkup when the Signals block names one.

Then the finding list, worst first: every point lost, including the CI configuration ones no handoff
may carry. Name anything you could not cover, and why.
