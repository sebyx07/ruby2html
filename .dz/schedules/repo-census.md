# Repository census

Weekly report, Mondays 12:00 UTC, fired by `schedules: repo-census` in
`.dz/maintainer/maintainer.yml` as a read-only scout. It is the developerz.ai platform's standard
census, adapted to ruby2html: how the automated work on this repository went this week against the
week before, and what in the repository makes it fail. You read files only: no shell, network or
database. Your numbers are the Signals block's, and nothing else.

**A report, never a change.** This census files no handoff and asks for no work: what it finds is
its report, for the people who maintain this repository to read and act on.

**Evidence or nothing.** Every number you quote is a Signals line, with both weeks' counts. A
section marked missing is reported `not read`, never an estimate.

## 1. Compare the two weeks

Read the failed tasks of the last 7 days beside the 7 days before that. Each line is
`origin/kind count`; one missing from a week counts 0 there.

- **regressed**: this week is at least 3 more than the week before and at least double it. Only
  these get a cause.
- **rose**: present the week before and higher this week, short of `regressed`.
- **new**: absent the week before, under 3 this week.
- **fell** or **steady**.

## 2. Find the cause

For each `regressed` kind, read the files a failure of that kind runs through. Here that is the
gate and what it reads: `bin/check` and its steps (`bin/repo-guards`, `bundle-audit` on
`Gemfile.lock`, `rake compile` in the `Rakefile` and `ext/ruby2html/extconf.rb`, `bin/rubocop` with
`.rubocop.yml`, RSpec under `spec/`, `bin/brakeman`, `rake smoke` through `bin/gem-smoke`),
`bin/setup` with `mise.toml` and `.ruby-version` (the one Ruby pin), `bin/audit-advisories`, and the
source the failing spec names. A cause is a `path:line` you read.

Three things here look like defects and are not:

- **Exit 75.** A `bin/check` run that exited 75 graded nothing: the environment was missing (no
  bundle, no `bundle-audit`). Report it as environment, with `bin/setup` as the remedy, never as a
  defect in the code and never as a pass.
- **A stale extension.** Specs run after an `ext/` edit without `bundle exec rake compile` load the
  old `.so` (or the pure-Ruby renderer when none exists). A task that failed, or passed, on code it
  did not build is a process failure: name the missing compile step.
- **CI-only jobs.** `bin/check` does not run the Ruby and Rails matrices, arm64 and macOS,
  `-Werror`, ASAN/UBSAN, the `RUBY2HTML_DISABLE_EXT=1` run, JRuby or TruffleRuby
  (`.github/CLAUDE.md` lists the jobs). A task green locally and red in `CI OK` usually diverged
  between the C extension and `lib/gem/ruby2html/render/pure_ruby.rb`: read both sides.

A failure the repository's files cannot cause or fix, such as a machine lost mid-run or a service
outage, is reported as that, with no cause in the repository. Failing CI jobs are evidence for a
cause, never a finding alone.

## Rows

The one row this census reports on. It files no handoff for it.

- `task-failure`: a failed-task kind that regressed, with its cause in this repository

## Report

1. Every kind with both weeks' counts and its verdict, worst first.
2. Each regressed kind's cause: one line `path:line: the code` per site, and what it does to each
   run.
3. What you could not read, and why.

Nothing regressed is a result: say so plainly.
