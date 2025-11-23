## Project Overview

Ruby2html is a Ruby gem that converts pure Ruby code into HTML. It features **C extension optimizations** for high-performance HTML rendering, escaping, and attribute generation. The project is both a standalone gem and a Rails demo application.

**Performance Philosophy**: Prioritize speed over memory usage. Modern systems have abundant memory, so optimize for execution speed. The C extension implements fast string operations with pre-allocated buffers and direct memory manipulation.

## Development Commands

### Setup
```bash
bin/setup              # Install dependencies, prepare database, compile C extension
bundle install         # Install gem dependencies
rake compile           # Compile the C extension (ext/ruby2html/ruby2html.c)
```

### Testing
```bash
bundle exec rspec                           # Run all tests
bundle exec rspec spec/features/            # Run feature tests
bundle exec rspec spec/gem/                 # Run gem unit tests
bundle exec rspec spec/benchmarks/          # Run benchmark tests
```

### Rails Server
```bash
bin/rails server       # Start Rails server (demo app)
bin/rails console      # Rails console
```

### Building the Gem
```bash
rake build             # Runs rake compile first, then builds gem
gem build ruby2html.gemspec
```

## Architecture

### Dual-Mode System

The codebase operates in two modes:
1. **Gem mode**: Core library in `lib/gem/ruby2html/` - standalone rendering engine
2. **Rails demo mode**: Full Rails app in `app/`, `config/`, demonstrating gem usage

### C Extension Performance Layer

Located in `ext/ruby2html/ruby2html.c`:
- `fast_escape_html`: Two-pass HTML escaping (pre-calculate size, then escape)
- `fast_attributes_to_s`: Direct string buffer manipulation for attribute generation
- `fast_buffer_append`: Optimized string concatenation

These C methods are called by `lib/gem/ruby2html/render.rb` for performance-critical operations.

### Core Rendering System

**lib/gem/ruby2html/render.rb** - Main renderer with metaprogramming for HTML tag generation:
- Pre-generates methods for all HTML5 tags at class load time via `class_eval(METHOD_DEFINITIONS)`
- Uses `String.new(capacity: N)` for pre-allocated buffers to minimize allocations
- Dynamically delegates to Rails helpers via `method_missing` when context responds
- Thread-safe via `Thread.current[:__ruby2html_renderer__]` for nested components

Key methods:
- `initialize(context, &block)`: Sets up renderer with 4KB pre-allocated output buffer
- `render`: Executes root block, returns HTML string (safe buffer in Rails)
- `plain(text)`: Outputs raw HTML or escaped text
- Tag methods: `div`, `h1`, `p`, etc. - dynamically generated

### Rails Integration

**lib/gem/ruby2html/railtie.rb**:
- Registers `.rb` template handler via `ActionView::Template.register_template_handler`
- Ignores `*.html.rb` files from Zeitwerk autoloading
- Templates are executed in context of view with access to instance variables

**lib/gem/ruby2html/rails_helper.rb**:
- `html(context, &block)` helper for use in ERB templates
- Include in controllers to access in views

**lib/gem/ruby2html/rails_components/**:
- Wrappers for Rails helpers: `link_to`, `image_tag`, `form_with`, `button_to`
- These integrate Rails view helpers with Ruby2html's rendering pipeline

### ViewComponent Integration

**lib/gem/ruby2html/component_helper.rb**:
- Provides `html(&block)` method for components
- Thread-local renderer storage for nested component rendering
- Method missing delegation to current renderer

Components extend `ApplicationComponent` which includes `Ruby2html::ComponentHelper`.

### Template Resolution

Files ending in `.html.rb` are treated as Ruby2html templates:
- `app/views/home/index.html.rb` - View template
- `app/components/first_component.html.rb` - Component template

Components can also define `call` method with `html do ... end` block instead of template file.

## Performance Optimizations in Code

When writing or modifying code:

1. **String allocation**: Use `String.new(capacity: N)` with estimated sizes to avoid reallocation
2. **Buffer reuse**: The `@current_output` buffer is reused for nested content generation
3. **C extension fallback**: All C methods have Ruby fallbacks if extension fails to load
4. **Method caching**: Tag methods are pre-generated at class load, not defined dynamically per-call
5. **Minimal object creation**: Prefer string concatenation over array joins or template interpolation

## Key Files

- `ext/ruby2html/ruby2html.c` - C extension for performance-critical operations
- `lib/gem/ruby2html/render.rb` - Core rendering engine with tag generation
- `lib/gem/ruby2html/railtie.rb` - Rails template handler registration
- `lib/gem/ruby2html/component_helper.rb` - ViewComponent integration
- `app/components/application_component.rb` - Base component class for demo
- `spec/benchmarks/requests_spec.rb` - Performance comparison benchmarks

## Benchmarking

The demo app includes benchmarks comparing Ruby2html to ERB, Slim, and Phlex in `spec/benchmarks/requests_spec.rb`. Run via `bundle exec rspec spec/benchmarks/`.

## HTML Beautification

Optional middleware `Ruby2html::HtmlBeautifierMiddleware` formats HTML output for development/testing. Enable in `config/environments/development.rb`.
