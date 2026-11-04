# Contributing

Bug reports and pull requests are welcome at https://github.com/sebyx07/ruby2html. AI-assisted contributions are welcome too; the same checks apply.

## Setup

Requirements: Ruby (see `apps/ruby2html/.ruby-version`; gem supports `>= 3.1`), a C compiler (`build-essential` on Debian/Ubuntu), SQLite (demo app).

```bash
cd apps/ruby2html
bundle install
bundle exec rake compile      # builds apps/ruby2html/ext/ruby2html -> apps/ruby2html/lib/ruby2html/ruby2html.so
CI=1 bundle exec rspec        # CI=1 skips the ~6 minute benchmark spec
RUBY2HTML_DISABLE_EXT=1 bundle exec rspec spec/gem   # pure-Ruby implementation
bundle exec rubocop
```

`lefthook` (installed via the bundle) autocorrects staged Ruby files with RuboCop on commit once enabled with `bundle exec lefthook install`.

## Where things are

- Gem code: `apps/ruby2html/lib/gem/ruby2html/` (renderer `render.rb`, pure-Ruby twin `render/pure_ruby.rb`), C extension: `apps/ruby2html/ext/ruby2html/`.
- Demo Rails app (not packaged): `apps/ruby2html/app/`, `apps/ruby2html/config/`.
- Specs: `apps/ruby2html/spec/gem/` (renderer units), `apps/ruby2html/spec/features/` (Rails), `apps/ruby2html/spec/benchmarks/`.
- Full map, rules and known sharp edges: [AGENTS.md](AGENTS.md). Internals: [docs/architecture.md](docs/architecture.md).

## Pull requests

1. Branch from `main`; keep PRs focused.
2. Add/adjust specs for any behavior change. Escaping changes need explicit specs.
3. C changes: recompile, keep `render/pure_ruby.rb` producing byte-identical output (parity specs), no new compiler warnings.
4. Performance claims: include before/after numbers (see `apps/ruby2html/bench/` and `apps/ruby2html/spec/benchmarks/`; `.claude/skills/benchmark/SKILL.md` has the procedure).
5. Add a line under `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md) for user-visible changes.
6. Update [llms.txt](apps/ruby2html/llms.txt) if user-facing behavior changes.

The PR template carries this checklist. Releases are done by the maintainer following [docs/release.md](docs/release.md).

## Style

rubocop-rails_config (`.rubocop.yml`, which lives in `apps/ruby2html/`): single quotes, `# frozen_string_literal: true`, nested `module`/`class`, Rails-style indented private methods. C: C99, `-Wall -Wextra` clean, `size_t` for lengths.

## License

By contributing you agree your contributions are licensed under the MIT License.

## How PRs get merged

This repo is maintained by [developerz.ai](https://developerz.ai). Its agent reviews every PR, may request changes, and merges every PR (contributors, members, bots) once you mark it ready for review and the `CI OK` check passes; keep it a draft until then (policy: `.dz/maintainer/maintainer.yml`). Commit with an email linked to your GitHub account. Changes to CI, release or publishing automation (`.github/`, `bin/`, the gemspec (`apps/ruby2html/ruby2html.gemspec`), `Ruby2html::VERSION`) are made by the owner only.

