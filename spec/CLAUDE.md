# spec/ — RSpec

`.rspec` requires `spec_helper`; the Rails-booting specs require `rails_helper`. Run the whole suite as CI does with `CI=1 bundle exec rspec` (`bin/check` does).

## Layout

| Path | Covers | Boots Rails |
|---|---|---|
| `gem/render*_spec.rb` | Renderer, attributes, escaping, hardening, parity | Only inside the demo bundle (see below) |
| `gem/render_spec_helper.rb` | `RenderSpecHelper.describe_each`: one example group per implementation | - |
| `gem/rails/` | Template handler, compiler, capture, locals, components, ViewComponent, middleware; helpers in `gem/rails/support/` | Yes |
| `features/` | The demo app end to end (Capybara) | Yes |
| `benchmarks/requests_spec.rb` | Requests per second against ERB, Slim, Phlex (~6 min). **Skipped when `CI` is set** | Yes |
| `ci/advisory_audit_spec.rb` | Guard spec: the dependency audits in `ci.yml`, the `Rakefile` and `bin/audit-advisories` | No |
| `bin/` | Guard specs for `bin/setup`, `bin/brakeman` and the `.ruby-version` single source | No |

## Rules

- **A renderer rule is specified on both implementations.** Write it inside `RenderSpecHelper.describe_each('...') do ... end` and render with `render_html`; the helper defines one group for Native (when the `.so` loaded) and one for PureRuby, in the same process. Cross-implementation comparisons go in `gem/render_parity_spec.rb`.
- **A spec that only passes on one side is a failing spec.** Fix the implementation that diverges; never restrict the group.
- **Compile before trusting a result** after an `ext/` edit: `bundle exec rake compile`. A stale `.so` passes on code you did not test.
- `gem/render_spec_helper.rb` boots Rails when `rails` is in the bundle, and otherwise loads only ActiveSupport's `SafeBuffer` plus the gem. That is how `rake spec:standalone` (JRuby, TruffleRuby, the Ruby matrix; `gemfiles/standalone.gemfile`) runs `spec/gem` minus `gem/rails/`. A spec outside `gem/rails/` must not need Rails.
- A fix comes with the spec that failed before it. A green run that never went red proves nothing.
- Never weaken a guard spec to get green. `spec/ci` and `spec/bin` are the tests of the tooling: change the tool and the spec in one PR, and say why in the body.

## What the guard specs pin

`ci/advisory_audit_spec.rb` fails when:

- a CI job that installs an unlocked `gemfiles/*.gemfile` stops running a rake task that reaches `audit:advisories`, sets `SKIP_COMPILE` on the job, or audits in a workflow step instead of the `Rakefile`;
- the job `audit` (the committed root `Gemfile.lock`) leaves `ci-ok`'s `needs`, or a matrix job does;
- the `| CI |` row of the root `CLAUDE.md` (read through the `AGENTS.md` symlink) stops naming `bundle-audit`, `Gemfile.lock` and the matrix gemfiles;
- `bin/audit-advisories` accepts an advisory outside its reviewed list, or for a version other than the reviewed one.

`bin/setup_spec.rb` runs `bin/setup` with a `PATH` of stub executables: a new command in `bin/setup` needs a stub there.

## Commands

| Task | Command |
|---|---|
| Full suite | `CI=1 bundle exec rspec` |
| Renderer and Rails units | `bundle exec rspec spec/gem` |
| PureRuby process | `RUBY2HTML_DISABLE_EXT=1 bundle exec rspec spec/gem` |
| Without Rails | `bundle exec rake spec:standalone` |
| Rails integration | `CI=1 bundle exec rspec spec/gem/rails spec/features` |
| One example | `bundle exec rspec spec/gem/render_spec.rb:LINE` |
| Request benchmark | `bundle exec rspec spec/benchmarks/` (no `CI` in the environment) |

The rake spec tasks (`spec`, `spec:gem`, `spec:standalone`) compile first; `SKIP_COMPILE=1` keeps the build that is already there.
