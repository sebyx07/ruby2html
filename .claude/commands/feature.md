---
description: Take one change in sebyx07/ruby2html from idea to merged — explore, build, prove it with bin/check, open one pull request, watch it land. Use for feature, implement, build it, ship this, fix and merge.
argument-hint: <what you want built or fixed>
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Task
---

# /feature — idea to merged in sebyx07/ruby2html

> Workflow command — established by dz-runner setup mode. Correct it in place;
> setup never overwrites a command that exists.

**Done means MERGED.** A green local gate is not done, and an open pull request is not
done. Report what you verified, never what you assume happened.

## Goal

$ARGUMENTS

## Steps

1. Restate the goal in one line. If it names a URL or an issue, read it first.
2. **Distrust the paperwork.** Check any plan, status file or design doc against the code
   and `git log` before working from it — trackers rot in both directions. Say plainly
   which claims you falsified, and fix the doc in the same change.
3. Explore read-only, in parallel, into a ranked worklist of PR-sized batches.
4. Build primitive-first: one reusable primitive with its first real caller. No
   abstraction before a consumer.
5. **Prove it.** `bin/setup` after any dependency change, then `bin/check`, which here is
   six gates — compile, rubocop, bundle-audit, rspec, the pure-Ruby `rake spec:gem`
   fallback, brakeman — see the script.
   Red is not a pull request: fix the cause, never silence the gate. Add the failing test
   first — a green run that never went red proves nothing.
6. **One pull request in flight, start to finish.** Open it, watch it to merged, run
   `git fetch`, and only then start the next. Each merge rebases the base under the
   other, and green-when-opened is not green-to-merge.
7. Re-check the original symptom after the merge, and leave the issues and docs true.

## Fan-out rules — restate these to every agent you spawn

- **One checkout. No git worktrees.** Work would land in a directory nobody is looking at,
  and each tree costs its own install and its own test database. Disjoint file sets are a
  scheduling problem you can see; isolation is one you cannot.
- **Exclusive file sets.** Two agents never write one file, and a rename or a signature
  change pulls every caller into the same set.
- **No git in a spawned agent** — no add, commit, branch, stash or push. You own git, and
  you touch it only once every agent has returned.
- **Scope each agent to the files it edited.** The repo-wide gate is yours, run once, at
  the end.
