## What & why

<!-- One or two sentences. Link issues: Fixes #123 -->

## Changes

-

## Checklist

- [ ] `bundle exec rake compile` (no new C warnings, if `apps/ruby2html/ext/` changed)
- [ ] `CI=1 bundle exec rspec` passes; new behavior has specs (`apps/ruby2html/spec/gem/` for the renderer)
- [ ] `bundle exec rubocop` passes
- [ ] Escaping unchanged, or the change is intentional and covered by specs
- [ ] C change mirrored in `apps/ruby2html/lib/gem/ruby2html/render/pure_ruby.rb` (byte-identical output; parity specs pass)
- [ ] `CHANGELOG.md` `## [Unreleased]` updated for user-visible changes
- [ ] `apps/ruby2html/llms.txt` / `AGENTS.md` updated if DSL behavior or commands changed

## Performance (if relevant)

<!-- Before/after from apps/ruby2html/bench/ or apps/ruby2html/spec/benchmarks/, same machine. Include `ruby -v` (YJIT?). -->

| Benchmark | Before (i/s) | After (i/s) | Ratio |
|---|---|---|---|
