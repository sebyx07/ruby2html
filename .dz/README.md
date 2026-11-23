# `.dz/`

Repo-scoped configuration for the [developerz.ai](https://developerz.ai) maintainer agent, which runs
this repository as an AI-managed project.

- `maintainer/maintainer.yml`: the maintainer policy (triage, PRs, review, releases, schedules).
- `pipeline/agent-pipeline.json`: the agent pipeline definition.
- `schedules/`: the scheduled checkup briefs (`release-due`, `security-release`, `health`, `improve`) the policy fires.

Agent instructions for working on the code live in `CLAUDE.md` (`AGENTS.md` is a symlink to it) and the nested `ext/`, `lib/`, `spec/` and `.github/CLAUDE.md`.
Docs: https://developerz.ai/docs/maintainer-yml
