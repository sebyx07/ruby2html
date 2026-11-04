---
description: Write a self-contained implementation plan under docs/plans/ for another agent to execute. Use for plan, planx, design the work, break this down.
argument-hint: <what you want planned>
allowed-tools: Read, Glob, Grep, Bash, Write
---

# /planx — plan a piece of work in sebyx07/ruby2html

> Workflow command — established by dz-runner setup mode. Correct it in place;
> setup never overwrites a command that exists.

**Plan only.** No implementation, no edits outside the plan directory. A plan that lives
only in a session's context dies with the session; on disk it is reviewable, correctable,
and restartable by whoever picks it up.

## Goal

$ARGUMENTS

## Steps

1. Resolve the directory: `date +%Y %m %d`, then the highest existing `1NN-*` under
   `docs/plans/<YYYY>/<MM>/<DD>/` plus 1, else `101`. Slug kebab-case, 5 words max.
2. Explore read-only first — find the patterns to follow and the files to change.
3. Write `overview.md`: goal (1-2 sentences), context (only the facts the executor needs,
   as `path:line`), the slice files in execution order, done-when, risks.
4. Write one `<NN>-<aspect>.md` per separable AREA OF WORK — `01-data-model.md`,
   `02-api.md`, `03-frontend.md`. Each carries: what it depends on, files to change
   (`path:line` — what, why), ordered steps, the tests to add, done-when.
5. Write `status.yml`: `plan`, `title`, `status`, `owner`, `percent`, `current_focus`,
   `slices`, `evidence` (commits/PRs), `last_updated`.

## Rules

- **Reference, never restate.** Cite `path:line`; pasted code is stale the day it is pasted.
- **Self-contained.** The executor reads `overview.md`, its own slice, and what those cite.
- **Split by area of work, never by chapter.** A slice boundary is the file-set boundary the
  build fans out on, and that file set is one pull request.
- **`status.yml` is the only tracker.** No checkboxes in a `.md` — two trackers disagree.
- **Skip the plan for a one-file fix.** Writing it costs more than the change.
