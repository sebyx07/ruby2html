# Hygiene checkup

Weekly checkup, Sundays 12:00 UTC, OFFERED and off: the `hygiene` entry in
`.dz/maintainer/maintainer.yml` is commented out, and uncommenting it is the opt-in. It is the
developerz.ai platform's standard hygiene checkup, adapted to a Ruby gem with a C extension and a
pure-Ruby twin: a deep read for the defects tests never show. A read-only scout: you read files
only, no shell, network or database, so a finding whose harm depends on a size or a rate you cannot
see (allocations per render, renders per second) is marked `measure first: yes`, never guessed.
Read `CLAUDE.md` and the nested `ext/CLAUDE.md` and `lib/CLAUDE.md` first: their invariants define
what a defect is here.

## What to look for

1. **Resource lifetimes.** In `ext/ruby2html/`: a `VALUE` whose `RSTRING_PTR` or inner pointer is
   read after a call that can allocate or yield, with no `RB_GC_GUARD` after its last use; a
   buffer pointer kept across a growth instead of re-read; length arithmetic done by hand where
   `buffer.h` has the primitive. In `lib/gem/`: a module-level cache or list that only grows; a
   cache keyed by `Object#hash`; renderer state kept thread- or fiber-global instead of on the
   view or component; a renderer not restored when a template raises.
2. **Algorithms.** Per-call work on a hot path (tag methods, `plain`, attributes, escape): an
   allocation, an `rb_intern` or `rb_funcall` inside a loop, a regular expression or frozen table
   built per call instead of at load, a string built and then copied where a direct buffer write
   fits. In the demo app (`app/`): one query per row of a loop.
3. **Reuse.** A hand-rolled copy of a helper the repository already has: buffer growth outside
   `buffer.h`, a second escape table, a Rails helper re-implemented in
   `lib/gem/ruby2html/rails_components/` where delegating to Rails' own fits. Name both the copy
   and the original.
4. **Data.** The gem has no database, and the demo app defines no schema: this area is clean
   unless a migration or schema file appears under `db/`. Then: an index that duplicates another
   or is the leading prefix of another non-unique one. A unique or foreign-key index earns its
   keep; do not file it.
5. **Documentation drift.** In `README.md`, `llms.txt`, `CHANGELOG.md` `## [Unreleased]`,
   `CLAUDE.md`, the nested `CLAUDE.md` files and `docs/`: a path that no longer exists, a command
   naming a script or rake task the repository does not define, a method, option or environment
   variable the code no longer has, a hardcoded version list or benchmark number (the CI matrix
   and the benchmark workflow are the source), a claim the code contradicts. Quote both the doc
   line and the code.
6. **Code quality.** Parity first: a rule in `content.c`, `attributes.c`, `tag_render.c` or
   `html_escape.c` with no twin in `lib/gem/ruby2html/render/pure_ruby.rb` (or the reverse), an
   escape rule the Java escaper `ext/java/Ruby2htmlJrubyService.java` does not share, an error
   message that differs between the two. Escaping: a text or attribute value appended raw without
   an `html_safe?` check, a plain `String` treated as safe, a tag or attribute name escaped
   instead of validated. Then: a file or function far beyond the repository's norm, dead code, a
   backwards-compatibility shim, syntax in `lib/` newer than RuboCop's `TargetRubyVersion`.
7. **Infrastructure.** `.devcontainer/Dockerfile` and `bin/docker-entrypoint`: a base image with
   no pinned tag or digest, no non-root user, a secret baked into a layer or an environment value,
   a package install whose cache is not cleaned in the same layer. `ruby2html.gemspec`: a runtime
   dependency, a file shipped in the gem that users never load, build output in `spec.files`.
   Quote the key, never the secret's value. Skip CI configuration (workflow files) and
   secret-shaped paths: a handoff naming one is refused whole.

## Rows

One per area above; a handoff reports one failing row.

- `leak`: resource lifetimes
- `algo`: algorithms
- `reuse`: reuse
- `index`: data
- `doc-drift`: documentation drift
- `quality`: code quality
- `infra`: infrastructure

## How to judge

- Confirm before you claim: read the call path on both implementations. A pattern is a finding
  only once you have seen that it runs where it hurts, and a parity gap only once you have read
  the other side's rule.
- Rank by blast radius: what breaks users first (an escaping hole, a GC hazard, divergent output,
  docs naming a command that does not exist), quality last.
- Skip specs, fixtures, generated and vendored code, `tmp/` and `pkg/`. Skip `.github/` and
  `.dz/`: a handoff naming one is refused whole.
- One handoff per row: every defect in an area goes in it, worst first.
- A suspected escaping bypass or memory-safety hole is a security report (`SECURITY.md`): write it
  in your answer for the owner, do not file it in the open.
- A fix that would change the public API (`lib/CLAUDE.md`) or the rendered output is breaking:
  report it, do not file it.

## Every finding

Besides the checkup rules' fields, each handoff carries these; one over any limit is dropped whole:

- **work**: one sentence naming the defect and the fix, at most 300 characters.
- **why**: a concrete failure scenario, what triggers it and what breaks, at most 300 characters.
- **evidence**: at most 10 lines of at most 280 characters each. Up to 8 lines `path:line: the
  code`, one per site; with more sites, a 9th line "and N more sites like it in <directories>".
  The last line starts `measure first:`, `no` with the reason when the code alone proves the harm,
  or `yes` with what to measure and how (`bundle exec rake bench` before and after, on one
  machine). The coding agent that takes the handoff measures first, and drops the fix if the
  number shows no harm.
- **paths**: at most 20 files.
- **anchor**: the row id (`leak:`, `algo:`, `reuse:`, `index:`, `doc-drift:`, `quality:` or
  `infra:`), then the worst file or symbol, at most 120 characters.
- **metric**: the number the fix moves, at most 200 characters.

## Report

For each of the seven areas: what you read and whether it was clean. Name any area you could not
cover, and why.
