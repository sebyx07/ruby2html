# Stack

- **Gem:** Ruby (`lib/gem/`), no runtime dependency. The Ruby floor is `required_ruby_version` in
  `ruby2html.gemspec`, and RuboCop's `TargetRubyVersion` in `.rubocop.yml` holds `lib/` to it.
- **C extension:** gnu99 C under `ext/ruby2html/`, built by `rake-compiler` (`bundle exec rake
  compile`) with `-Wall -Wextra`; SSE2 and NEON escape paths with a scalar fallback. Strict, clang
  and sanitizer builds: `bin/build-ext`.
- **Other engines:** JRuby runs the pure-Ruby renderer plus a Java escaper built from `ext/java/`
  into the `-java` platform gem; TruffleRuby runs pure Ruby.
- **Rails integration:** a Railtie, a `.rb` template handler and a Prism-based template compiler
  (`lib/gem/ruby2html/railtie.rb`, `lib/gem/ruby2html/rails_components/`). ViewComponent is
  optional.
- **Demo app:** Rails with SQLite, ViewComponent, Slim and Phlex (the last two as benchmark
  baselines), from the root `Gemfile`.
- **Tests:** RSpec under `spec/`: renderer specs that run on both implementations
  (`spec/gem/render_spec_helper.rb`), Rails integration (`spec/gem/rails/`), Capybara features
  (`spec/features/`), guard specs for the tooling (`spec/ci/`, `spec/bin/`). Benchmarks: `bench/`
  and `spec/benchmarks/`.
- **Lint and security:** RuboCop (rubocop-rails_config), Brakeman on the demo app, `bundle-audit`
  and `bin/audit-advisories` on dependencies; actionlint and zizmor on workflows in CI.
- **Toolchain:** the dev Ruby is `.ruby-version`, the single pin (`mise.toml` reads it);
  `bin/setup` installs everything. lefthook runs RuboCop on commit.
- **Gate:** `bin/check` locally (exit 75 means the environment is missing, not that a check
  failed) and the aggregate `CI OK` job of `.github/workflows/ci.yml`, which runs the same
  `bin/check` plus the Ruby and Rails matrices, other platforms and engines.

Exact versions are in `Gemfile.lock` and the generated CI matrices; Dependabot keeps them current.
Supported versions are never listed in docs: `.github/CLAUDE.md` says where they come from.
