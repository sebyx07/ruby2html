# sebyx07/ruby2html — docs

The index of this directory. Add a line when you add a page. The agent brain is the root
[`CLAUDE.md`](../CLAUDE.md); the commands are `bin/setup`, `bin/dev`, `bin/check` and `bin/stop`.

| Page | What it holds |
|---|---|
| [`idea/direction.md`](idea/direction.md) | What the product is for, what "better" means here, what is out of bounds. A draft for the owner to correct |
| [`idea/overview.md`](idea/overview.md) | What ruby2html is and who uses it |
| [`idea/principles.md`](idea/principles.md) | Why the invariants exist: the promises a change is weighed against |
| [`idea/stack.md`](idea/stack.md) | Languages, build, test and lint tools |
| [`idea/data-model.md`](idea/data-model.md) | What the gem's data is: the tag table, value kinds, the output buffer, the public API |
| [`idea/deployment.md`](idea/deployment.md) | How the gems ship, and what reports the outcome |
| [`architecture.md`](architecture.md) | How the gem turns Ruby into HTML: load sequence, tag, attribute and escaping rules, the `.html.rb` template handler, components |
| [`standards/README.md`](standards/README.md) | The rules a change follows, and the check that enforces each |
| [`release.md`](release.md) | Release checklist: a version bump merged to `main` publishes the gem |

For users of the gem: [`README.md`](../README.md) and [`llms.txt`](../llms.txt). For contributors:
[`CONTRIBUTING.md`](../CONTRIBUTING.md) and [`SECURITY.md`](../SECURITY.md). For the maintainer
agent's policy and scheduled checkups: [`.dz/README.md`](../.dz/README.md).
