# `.dz/`

Repo-scoped configuration for the [developerz.ai](https://developerz.ai) maintainer agent, which runs
this repository as an AI-managed project.

- `maintainer/maintainer.yml`: the maintainer policy (triage, PRs, review, releases, schedules).
- `pipeline/agent-pipeline.json`: the agent pipeline definition.
- `briefs/`: the scheduled checkups (`release-due`, `security-release`, `health`) the policy fires.

Agent instructions for working on the code live in `AGENTS.md` (`CLAUDE.md` is a symlink to it).
Docs: https://developerz.ai/docs/maintainer-yml
