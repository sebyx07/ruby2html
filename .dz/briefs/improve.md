# Brief: monthly improvement

Fired every Monday by `schedules: improve` in `.dz/maintainer/maintainer.yml`. **Act only on the first
Monday of the month (UTC day 1-7); on any other Monday stop here and do nothing.**

ruby2html is maintained by agents only. Once a month, leave it measurably better and one step ahead
of the next Ruby and Rails release. Read `AGENTS.md` first: its invariants (Native/PureRuby byte
parity, escaping, GC safety, no per-call allocations) and "How to verify a change" bind every change.

## 1. Canary first

`gh run list --workflow canary.yml --limit 1 --json conclusion,url,createdAt`: Ruby head and Rails
edge (rails/rails main). If it failed, find the cause in the log and fix it here. If the break is
upstream and not ours to fix, open one issue upstream-linked and don't work around it with shims.
If no run is younger than 7 days, start one: `gh workflow run canary.yml`, and read it before step 3.

## 2. Pick at most three improvements, in this order

1. Anything the canary found.
2. Dependency majors Dependabot can't do (grouped bumps that failed, Rails/ViewComponent/Phlex majors
   in the demo app): `upgrade-deps` skill.
3. Speed and memory: run `bundle exec rake bench` on `main`. Look for allocations or hot-path work
   in `ext/ruby2html/` and `render/pure_ruby.rb`; a change counts only with before/after numbers
   from the `benchmark` skill.
4. Correctness and safety: open issues labelled bug, then a look at escaping and parity with the
   `review` skill checklist. Every fix comes with a spec in both implementations.
5. Docs drift: every claim in `llms.txt`, `README.md` and `AGENTS.md` still matches the code.
6. Simplification: dead code, duplicated logic, slow or flaky specs.

## 3. Ship

One pull request per improvement, small and reviewable, titled with what it changes. The body gives
the evidence: failing canary log, before/after benchmark table, or the spec that failed before.
User-visible changes get a CHANGELOG `## [Unreleased]` entry. Never bump the version here (the
`release-due` checkup does that); a breaking change escalates to the owner instead of merging.

If nothing is worth changing this month, do nothing: no empty PRs, no churn.
