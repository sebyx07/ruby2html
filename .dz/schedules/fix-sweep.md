# Post-merge fix sweep

Weekly sweep, Thursdays 18:00 UTC, OFFERED and off: the `fix-sweep` entry in
`.dz/maintainer/maintainer.yml` is commented out, and uncommenting it is the opt-in. It runs as a
devops task (`mode: devops`: a shell on a checkout, at most one pull request). It is the
developerz.ai platform's standard fix sweep, adapted to ruby2html: the changes merged into `main`
in the last 7 days, read again for the defects their own review let through, and fixed in one pull
request. Read `CLAUDE.md` first, then the nested `CLAUDE.md` of each directory you touch: their
invariants bind every fix.

## 1. Find the touched area

```bash
bin/setup
git log --since='7 days ago' --first-parent --format='%h %s' origin/main
git diff --stat "$(git rev-list -1 --before='7 days ago' origin/main)" origin/main
```

The touched area is those files, their direct callers, and the twin of each renderer file: a
change under `ext/ruby2html/` pulls in `lib/gem/ruby2html/render/pure_ruby.rb` and the reverse, and
an escape change pulls in `ext/java/Ruby2htmlJrubyService.java`. Nothing merged, or only dependency
bumps that change nothing the gem ships: say so and stop.

## 2. Hunt

Read the touched area for, worst first:

- **escaping**: a text or attribute value that reaches the output unescaped without an
  `html_safe?` check, a plain `String` treated as safe, a helper wrapper that escapes twice or not
  at all, a tag or attribute name escaped instead of validated
- **parity**: output, encoding or a raised error that differs between `Ruby2html::Native` and
  `Ruby2html::PureRuby` for the same input; a rule changed on one side only
- **memory**: in C, a `VALUE` read after an allocating or yielding call with no `RB_GC_GUARD`, a
  buffer pointer kept across a growth, a start tag left half-written when an exception unwinds
- **Rails integration**: a helper that writes outside the captured block, a template local
  rewritten into a tag call, behaviour that holds on one Rails line only
- **cost**: a new per-call allocation or lookup on a hot path (tag methods, `plain`, attributes,
  escape)
- **reuse**: a new copy of a helper the repository already has; name both
- **drift**: a line in `README.md`, `llms.txt`, `CHANGELOG.md`, `docs/` or a `CLAUDE.md` that the
  merged change made false

Skip specs, fixtures and generated files. Confirm before you claim: a defect is one you can make
fail.

## 3. Fix

- One pull request for the whole sweep, one goal: the defects this week's merges brought in.
- For each defect, a spec that fails before the fix and passes after. A renderer rule goes in a
  `RenderSpecHelper.describe_each` group or `spec/gem/render_parity_spec.rb`, so it runs on both
  implementations. Run it red first.
- After any `ext/` edit: `bundle exec rake compile` before the specs, or they pass on the stale
  build. Then `RUBY2HTML_DISABLE_EXT=1 bundle exec rspec spec/gem` for the pure-Ruby process.
- A Rails-side fix also runs `CI=1 bundle exec rspec spec/gem/rails spec/features`.
- A cost fix carries before and after numbers from `bundle exec rake bench` on one machine.
- A fix users can see gets a `CHANGELOG.md` `## [Unreleased]` line, and `llms.txt` when DSL
  behaviour changes.
- Delete what the fix makes dead.
- `bin/check` must be green before you open the pull request. Exit 75 means the environment is
  missing, not that a check failed: `bin/setup`, then rerun. The required check is `CI OK`, which
  also runs what `bin/check` cannot (the Ruby and Rails matrices, JRuby, TruffleRuby, `-Werror`,
  the sanitizers): watch it, and fix a red job in this pull request.
- A defect you cannot make fail is not fixed here: name it in the report, with no pull request for
  it.
- A suspected escaping bypass or memory-safety hole that is exploitable is a security report
  (`SECURITY.md`): stop and write it for the owner, not in a public pull request.
- A fix that would change the public API or the documented output is breaking: report it for the
  owner.
- Do not edit `.github/`, `.dz/`, `bin/`, the gemspec or `lib/gem/ruby2html/version.rb`: a release
  is the `release-due` checkup's, on a version bump, never this sweep's.

No defect: no pull request. A clean week is a good result; say so and stop.

## Report

The range of merges you read, each defect with its `path:line`, its spec and its fix, and what you
could not cover, with why.
