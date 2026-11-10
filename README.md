# Ruby2html

[![CI](https://github.com/sebyx07/ruby2html/actions/workflows/ci.yml/badge.svg)](https://github.com/sebyx07/ruby2html/actions/workflows/ci.yml)
[![Gem Version](https://img.shields.io/gem/v/ruby2html)](https://rubygems.org/gems/ruby2html)
[![Maintained by developerz.ai](https://img.shields.io/badge/maintained%20by-developerz.ai-6f42c1)](https://developerz.ai)

Write views in pure Ruby; get escaped, compact HTML. A C extension handles escaping, attribute serialization and tag rendering. Works standalone, as Rails `.html.rb` templates, inside ERB, and in ViewComponent.

```ruby
div class: 'card', 'data-controller': 'card' do
  h2 @product.title
  p @product.description
  a 'Details', href: product_path(@product), class: 'btn'
end
```

```html
<div class="card" data-controller="card"><h2>Lamp</h2><p>Warm &amp; bright</p><a href="/products/1" class="btn">Details</a></div>
```

## Why ruby2html

- **Fastest Ruby HTML renderer we've measured.** Page-render, per-tag, escaping and full-Rails-request benchmarks run in CI on every push and pull request; the current numbers are in [Performance](#performance).
- **Light.** No runtime dependencies and a 32 KB gem. Prism, the Rails glue and the optional beautifier load only when used, or at boot in eager-loading production apps.
- **Plain Ruby views.** `.html.rb` templates, ERB interop, ViewComponent, or the built-in `Ruby2html::Component`. Escaped by default.
- **Runs everywhere.** CRuby ≥ 3.1 with a C extension (SIMD escaping on x86_64 and arm64), JRuby with a Java escaper over the pure-Ruby implementation, and TruffleRuby on pure Ruby (faster there than the C extension) — all byte-identical. Rails 7.2+.
- **AI-ready.** One-file reference for coding agents: [`llms.txt`](llms.txt).

## Installation

Supports all maintained CRuby versions (>= 3.1; CI currently covers 3.3, 3.4 and 4.0), JRuby (pure Ruby plus a Java escaper), TruffleRuby (pure Ruby), and Rails 7.2+; the CI matrix is generated automatically, so new Ruby releases are picked up without edits.

```ruby
# Gemfile
gem 'ruby2html'
```

```bash
bundle install   # compiles the native extension (needs a C compiler); pure-Ruby fallback otherwise
```

## AI agents

**This project is maintained by [developerz.ai](https://developerz.ai).** Its maintainer agent triages issues, reviews every pull request, merges every pull request once its author marks it ready and CI passes, watches project health daily, and opens release PRs. The policy is in [`.dz/maintainer/maintainer.yml`](.dz/maintainer/maintainer.yml). Breaking changes and major releases stay with the owner.

- **Using ruby2html in your app?** Point your agent at [`llms.txt`](llms.txt), the complete reference in one file (DSL rules, escaping, Rails, components, forms, pitfalls). Paste this into your app's `CLAUDE.md` / `AGENTS.md`:
  ```markdown
  ## ruby2html views
  `*.html.rb` templates and `html do ... end` blocks use the ruby2html gem. Before editing them read
  https://github.com/sebyx07/ruby2html/blob/main/llms.txt
  ```
- **Working on this repo?** [`AGENTS.md`](AGENTS.md) is the only agent-instructions file (`CLAUDE.md` is a symlink to it): commands, code map, invariants, how to verify a change, CI/release automation.
- **Claude Code**: project skills in `.claude/skills/` (`release`, `benchmark`, `add-html-tag`, `review`, `debug-render`, `upgrade-deps`), read-only reviewer subagents in `.claude/agents/` (`perf-reviewer`, `xss-auditor`), and `.claude/settings.json` with a safe permission allowlist and a non-blocking recompile-reminder hook.

## Usage

### DSL basics

- Every HTML5 tag is a method (`div`, `p`, `ul`, `li`, `img`, `input`, ...), plus `turbo_frame` / `turbo_stream`.
- `tag content, **attrs` or `tag(**attrs) { nested tags }`. Text and attribute values are HTML-escaped; numbers and symbols are converted (`td 42`).
- Raw HTML only from `html_safe` strings (Rails helpers, `'<hr>'.html_safe`), as content or via `plain`. `plain 'text'` escapes.
- Attributes: `'data-id': 1` or `data: { id: 1 }`, `class: ['btn', active && 'on']`, `disabled: true` → bare `disabled`, `nil`/`false` omitted.

Full rules and pitfalls: [`llms.txt`](llms.txt).

### Rails views (`.html.rb`)

File: `app/views/products/index.html.rb`

```ruby
div class: 'container' do
  h1 'Products', class: 'main-title'
  link_to 'Home', root_path, class: 'btn btn-primary', 'data-turbo': false

  @products.each do |product|
    h2 product.title, class: 'item-title', id: "product-#{product.id}"
    p product.description, class: 'item-description'
  end
end

plain '<div>Inline html</div>'.html_safe
render partial: 'shared/navbar'
```

Controller instance variables are available. Partials can be `.html.rb` too. `link_to`, `image_tag`, `button_to`, `form_with` and `render` write their output directly; other helpers return a value you must output (`h1 t('.title')`, `plain some_safe_html_helper`).

### Inside ERB

```ruby
class ApplicationController < ActionController::Base
  include Ruby2html::RailsHelper # exposes the html(context) helper to views
end
```

```erb
<h1>Legacy ERB header</h1>
<%= html(self) do
  div class: 'ruby2html-section' do
    h2 'This section is powered by Ruby2html'
    @items.each { |item| p item[:title] }
  end
end %>
```

ERB, Slim and Ruby2html views, partials and components can be mixed freely, so adoption can be gradual.

### ViewComponent

```ruby
class ApplicationComponent < ViewComponent::Base
  include Ruby2html::ComponentHelper
end
```

Inline `call`:

```ruby
class GreetingComponent < ApplicationComponent
  def initialize(name)
    @name = name
  end

  def call
    html do
      h1 "Hello, #{@name}!", class: 'greeting', 'data-user': @name
      p 'Welcome to Ruby2html!', class: 'welcome-message'
    end
  end
end
```

Or a sidecar template, `app/components/farewell_component.html.rb`:

```ruby
div class: 'farewell' do
  h1 "Goodbye, #{@name}!", class: 'farewell-message'
end
```

Public component methods can be called from the template and may emit tags themselves (see `app/components/first_component.rb`).

### `Ruby2html::Component` (no ViewComponent required)

```ruby
class CardComponent < Ruby2html::Component
  def initialize(title:)
    @title = title
  end

  def view_template
    div class: 'card' do
      h2 @title
      content                              # block passed to render
      link_to 'More', helpers.root_path
    end
  end
end

# any view or controller
render CardComponent.new(title: 'Hi')
```

Tag methods run on the component itself (no instance-variable copying); nested ruby2html components write into the parent's buffer.

### Forms

```ruby
form_with model: @user do |f|
  f.label :email
  f.text_field :email
  f.submit 'Save'
end
```

### Without Rails

```ruby
require 'ruby2html'

Ruby2html::Render.new do # optional context object: its public methods and ivars become available
  html do
    head { title 'Ruby2html Example' }
    body { h1 'Hello, World!' }
  end
end.render
# => "<html><head><title>Ruby2html Example</title></head><body><h1>Hello, World!</h1></body></html>"
```

### Pretty HTML in development

```ruby
# Gemfile (development group): gem 'htmlbeautifier'
# config/environments/development.rb
config.middleware.use Ruby2html::HtmlBeautifierMiddleware
```

## Performance

Benchmarks run in CI on every push to `main` and every pull request ([`.github/workflows/benchmark.yml`](.github/workflows/benchmark.yml)): the latest run's summary page has the current table, and PRs get a sticky comment with the delta against `main`. Run them locally with `bundle exec rake bench` (standalone scripts in `bench/`) or `bundle exec rspec spec/benchmarks/` (request-level through the demo app, vs ERB, Slim, Phlex and ViewComponent).

### What is measured

- [`bench/render_bench.rb`](bench/render_bench.rb): a full page render (no Rails), ruby2html vs Erubi and Phlex, with per-render allocation counts. `RUBY2HTML_DISABLE_EXT=1` runs the pure-Ruby fallback.
- [`bench/tag_bench.rb`](bench/tag_bench.rb): per-tag cost for the common call shapes.
- [`bench/escape_bench.rb`](bench/escape_bench.rb): escaping throughput on short/medium/long, clean and dirty strings. Rebuild with `RUBY2HTML_NO_SIMD=1` to compare the scalar path.
- [`spec/benchmarks/requests_spec.rb`](spec/benchmarks/requests_spec.rb): full Rails requests through the demo app — `.html.rb` templates, ViewComponent and `Ruby2html::Component` vs ERB, Slim and Phlex.

How it is fast:

- **Tag methods in C**: each tag writes open tag, content/block output and close tag straight into one shared buffer (no nested buffers, no `*args`/`**kwargs` allocation without keywords).
- **HTML escaping**: 16-byte SSE2/NEON scan for `& < > " '`; clean strings are one `memcpy`, dirty strings get their exact size computed once.
- **Attributes**: written directly into the buffer, no intermediate strings, no cache to thrash or leak.
- **Lazy loading**: `require 'ruby2html'` loads only the renderer. Production Rails apps load everything at boot, so forked workers share it copy-on-write.
- **Templates and components**: `.html.rb` templates are rewritten at compile time (Prism) to run in the view itself; `Ruby2html::Component` runs tag methods on the component. No instance-variable copying or `method_missing` per render.
- A pure-Ruby implementation with identical output is used when the extension is unavailable.

## Development

```bash
bundle install
bundle exec rake compile   # build the C extension
CI=1 bundle exec rspec     # specs (CI=1 skips the slow benchmark spec)
bundle exec rubocop
bin/rails server           # demo app
```

The repository is both the gem (`lib/gem/`, `ext/ruby2html/`) and a Rails demo app (`app/`, `config/`). See [CONTRIBUTING.md](CONTRIBUTING.md), [docs/architecture.md](docs/architecture.md), [docs/release.md](docs/release.md) and [CHANGELOG.md](CHANGELOG.md).

## License

MIT. See [LICENSE](LICENSE).
