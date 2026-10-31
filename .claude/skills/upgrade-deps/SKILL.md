---
name: upgrade-deps
description: Upgrade ruby2html's development/demo dependencies (Rails, view_component, phlex-rails, slim, rspec-rails, rubocop, lefthook, rake-compiler, ...) safely - bundle outdated, bump in small groups, run the full suite and benchmarks, record changes. Use when asked to update gems, fix outdated or vulnerable dependencies, or move to a new Rails/Ruby.
---

# Upgrade dependencies

Patch and minor updates arrive as grouped Dependabot PRs and auto-merge when CI passes; this skill is for what is left: **major-version** bumps (Dependabot PRs that did not auto-merge, or a manual upgrade). Do not pin or list versions in docs; the lockfiles are the record.

The `Gemfile` serves the demo app and specs; the gem's only runtime dependency is in `ruby2html.gemspec` (keep it minimal; `htmlbeautifier` is optional at runtime via the middleware's lazy require). Do not add runtime dependencies to the gemspec while upgrading.

## Steps

1. Baseline: clean tree, `bundle exec rake compile`, `CI=1 bundle exec rspec` green, save `bundle exec rake bench` output (`benchmark` skill) to the scratch dir.
2. Survey: `bundle outdated --only-explicit` (and `bundle outdated` for transitive). Read each major bump's changelog/upgrade guide for breaking changes (Rails `config.load_defaults`, view_component major versions, phlex-rails majors, rspec-rails majors, lefthook config format).
3. Bump in groups, one commit-sized step each:
   - framework: `rails` (+ `sprockets-rails`, `web-console`, `bootsnap`, `puma`, `sqlite3`)
   - view layer: `view_component`, `phlex-rails`, `slim-rails`
   - test: `rspec-rails`, `capybara`, `benchmark-ips`, `faker`
   - tooling: `rubocop-rails_config`, `lefthook`, `brakeman`, `rake-compiler`
   Edit constraints in `Gemfile`, then `bundle update <gems> --conservative`. Check `gemfiles/*.gemfile` (CI matrix gemfiles, e.g. per Rails line, and `standalone.gemfile`) for constraints that need the same change; add a gemfile for a new Rails major. For Ruby: update `.ruby-version` (most CI jobs use it); the Ruby matrix itself is generated.
4. After each group: `bundle exec rake compile`, `CI=1 bundle exec rspec`, `RUBY2HTML_DISABLE_EXT=1 bundle exec rspec spec/gem`, `bundle exec rubocop` (new cops: autocorrect only safe ones, review the diff), `bin/brakeman --no-pager`, `bundle exec rake smoke`. Fix breakages in the demo app (`app/`, `config/`) or specs; touch `lib/gem/` only for genuine compatibility fixes and note them in CHANGELOG.
5. Framework/view-layer upgrades: rerun benchmarks (`bundle exec rake bench`; and `bundle exec rspec spec/benchmarks/` if Rails/ViewComponent/Phlex changed, ~6 min) and compare with the baseline. Report regressions; README tables only change on request.
6. Report: table of gem old → new, breakages fixed, test/benchmark results. CHANGELOG `### Changed` only if the gem's supported Ruby/Rails range or behavior changed.

## Never

- Never run `bundle update` with no arguments in one go.
- Never relax `required_ruby_version` or add gemspec runtime deps without asking.
- Never commit or push unless asked.
