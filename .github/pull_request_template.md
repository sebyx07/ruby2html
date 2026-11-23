## What & why

<!-- One or two sentences. Link issues: Fixes #123 -->

## Changes

-

## Checklist

- [ ] `bin/check` is green (repo guards, audit, compile, RuboCop, full RSpec, Brakeman, smoke)
- [ ] New behavior has specs (`spec/gem/` for the renderer); no new C warnings if `ext/` changed (`bin/build-ext --werror`)
- [ ] Escaping unchanged, or the change is intentional and covered by specs
- [ ] C change mirrored in `lib/gem/ruby2html/render/pure_ruby.rb` (byte-identical output; parity specs pass)
- [ ] `CHANGELOG.md` `## [Unreleased]` updated for user-visible changes
- [ ] `llms.txt` / `CLAUDE.md` (or the nested `CLAUDE.md`) updated if DSL behavior or commands changed

## Performance (if relevant)

<!-- Before/after from bench/ or spec/benchmarks/, same machine. Include `ruby -v` (YJIT?). -->

| Benchmark | Before (i/s) | After (i/s) | Ratio |
|---|---|---|---|
