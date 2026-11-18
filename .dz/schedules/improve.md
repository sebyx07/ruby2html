# Brief: monthly improvement

Fired on the first Monday of the month (UTC days 1-7, `weeks_of_month: [1]`) by `schedules: improve`
in `.dz/maintainer/maintainer.yml`, after `canary.yml`'s run on the 1st.

ruby2html is maintained by agents only. Once a month, leave it measurably better and one step ahead
of the next Ruby and Rails release. Read `AGENTS.md` first: its invariants (Native/PureRuby byte
parity, escaping, GC safety, no per-call allocations) and "How to verify a change" bind every change.

## Rows

- `canary-red`: the latest `canary.yml` run (Ruby head, Rails edge) failed, or none ran in the last 35 days (§1).
- `dep-major`: a dependency major Dependabot could not land (a failed grouped bump, a Rails, ViewComponent or Phlex major in the demo app) (§2 item 2).
- `hot-path-alloc`: `bundle exec rake bench` on `main` shows a per-call allocation or avoidable work in `ext/ruby2html/` or `render/pure_ruby.rb`, with before/after numbers for the fix (§2 item 3).
- `parity-or-escaping`: an open `bug` issue, or a `review` skill pass, shows Native and PureRuby output differ or an escaping rule is wrong (§2 item 4).
- `docs-drift`: a claim in `llms.txt`, `README.md` or `AGENTS.md` no longer matches the code (§2 item 5).
- `dead-code`: dead code, duplicated logic, or a slow or flaky spec (§2 item 6).

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
