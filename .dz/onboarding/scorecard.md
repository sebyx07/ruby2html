# AI-first scorecard

> Written by the developerz.ai maintainer agent — established by dz-runner setup mode. Each onboarding run rewrites this file whole; the latest run wins, and the same card is stored on the platform.

- Run: `run_2a4f7da500244060bd628bed79c06268`
- Computed: 2026-11-03T03:16:15.989Z
- Proof: **proved with gaps** — `bin/check` ran green at head; the head commands that did not are named below.
- Score: 13 of 15 items ok

## `policy` — ok

- .dz/maintainer/maintainer.yml already present, left alone
- .dz/maintainer/reviewer.md established

## `brain` — ok

- CLAUDE.md already present, left alone

## `roster` — ok

- .claude/agents already present, left alone

## `skills` — ok

- .claude/skills already present, left alone

## `scripts` — ok

- bin/setup already present, left alone
- bin/dev established
- bin/check established
- bin/stop established
- down: ./bin/stop (bin)
- ./bin/setup exited 0 at head (4.6s)

## `wiring` — ok

- .mcp.json established

## `commands` — ok

- .claude/commands/planx.md established
- .claude/commands/feature.md established

## `access` — gap

- landed 0 of 1 asked
- still missing: RAILS_MASTER_KEY

## `layout` — gap

- migration to the house layout filed as tasks
- apps/ruby2html: 22 move(s) planned as one task

## `smoke_test` — ok

- spec/gem/render_parity_spec.rb in the repository
- run by ./bin/check exited 0 at head (17.4s)

## `env_example` — ok

- .env.example established

## `agents_md` — ok

- AGENTS.md already present, left alone

## `per_workspace_brains` — ok

- single-package repository: 0 workspaces
- CLAUDE.md already present, left alone

## `docs_readme` — ok

- docs/README.md established

## `gate_proved` — ok

- ./bin/check exited 0 at head (17.4s)
