# `.dz/`

Repo-scoped configuration for the [developerz.ai](https://developerz.ai) maintainer agent, which runs
this repository as an AI-managed project.

- `maintainer/maintainer.yml`: the maintainer policy (triage, PRs, review, releases, schedules).
- `pipeline/agent-pipeline.json`: the agent pipeline definition.
- `schedules/`: the scheduled checkup briefs the policy fires: this repo's own (`release-due`,
  `security-release`, `health`, `improve`) and the developerz.ai platform's standard ones (`repo-census` and
  `repo-score` on; `hygiene`, `devops` and `fix-sweep` offered, their entries commented out).

Product intent and direction (a draft for the owner): `docs/idea/`, indexed by `docs/README.md`.

Agent instructions for working on the code live in `CLAUDE.md` (`AGENTS.md` is a symlink to it) and the nested `ext/`, `lib/`, `spec/` and `.github/CLAUDE.md`.
Docs: https://developerz.ai/docs/maintainer-yml
