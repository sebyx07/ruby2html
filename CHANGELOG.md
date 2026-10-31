# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning: [SemVer](https://semver.org/spec/v2.0.0.html).
Entries before 1.6.6 were reconstructed from `git log` and RubyGems release dates (the repo has no git tags for them); they are best-effort summaries.

## [Unreleased]

## [2.0.0] - 2026-10-31

A rewrite of the renderer for speed, memory and correctness, plus a new component class, Rails 8.1 / ViewComponent 4 support, JRuby/TruffleRuby support and full CI/release automation. **Contains breaking changes: read "Upgrading to 2.0" below.**

### Performance

Measured on Ruby 3.4.7 x86_64 (`bench/render_bench.rb`, a 100-item page with attributes and escaped text):

- About 4.7x faster than 1.6.6 (≈620 → ≈2,950 renders/s) with about 8x fewer allocations per render (3,531 → 419).
- Faster than Erubi (Rails' ERB engine) and Phlex on the same page; see the README snapshot and the CI benchmark workflow for current numbers.
- HTML escaping uses SSE2 (x86_64) / NEON (arm64): up to 5.9x faster on large clean text, about 2x on typical strings.
- `require 'ruby2html'` costs about 0.4 MB and 19 ms (was about 9.5 MB and 116 ms): Prism, the Rails glue and htmlbeautifier load only when used; in eager-loading (production) Rails apps they load at boot instead.

### Added

- `Ruby2html::Component`: a lightweight component base class (no ViewComponent needed) with `view_template`/`call`, `render_in`, `helpers` and `content`; nested components write straight into the parent's buffer.
- Pure-Ruby implementation with byte-identical output (`Ruby2html::PureRuby`), used on JRuby, when the extension can't be built, or with `RUBY2HTML_DISABLE_EXT=1`. `Ruby2html.native?` and `Ruby2html::IMPLEMENTATION` tell which one is loaded.
- `Ruby2html.escape_html(obj)`.
- Attributes: `true` renders a bare attribute, `false` omits it; nested `data:`/`aria:` Hashes expand to `data-user-id="1"`; Arrays render as space-separated tokens (`class: ['btn', active && 'on']`).
- `.html.rb` templates are compiled with Prism to run directly in the view/component (no instance-variable copying, no `method_missing`).
- `capture`, `content_for` and `provide` with blocks of ruby2html tags work in `.html.rb` templates.
- Support for Rails 8.1, ViewComponent 4, JRuby and TruffleRuby; fiber-safe rendering (no thread/fiber-global state).
- `llms.txt`: complete reference for AI coding tools; `AGENTS.md` (with `CLAUDE.md` symlinked to it) and Claude Code skills/agents for maintainers.
- CI: generated CRuby matrix (all maintained versions), Rails matrix, Linux x86_64/arm64 and macOS builds, `-Werror` gcc/clang builds, sanitizers, JRuby/TruffleRuby, gem install smoke test, benchmarks in every PR; Dependabot with auto-merge for patch/minor updates; tag-triggered releases via RubyGems trusted publishing.

### Fixed

- Attribute cache keyed by `Object#hash`: a hash collision could render another element's attributes; the cache also grew without bound. Removed.
- `link_to` rendered a `button_to` form.
- `form_with` emitted its fields as escaped text, ignored `patch`/`delete` (`_method`), crashed on `submit` without a label, and ignored Rails' CSRF/`data-remote` settings. It now delegates to Rails' own `form_with` and `FormBuilder`.
- Tags inside `link_to`/`button_to` blocks were emitted before the link instead of inside it.
- `html_safe` content was escaped twice; non-String content (`p 42`) was silently dropped.
- A block's String return value replaced markup the block had already written.
- The `<output>` tag was unusable (shadowed by `Render#output`).
- Template backtraces were off by 3 lines; the renderer wasn't restored when a template raised; template locals could clash with internal variables or be rewritten into tag calls (`h2 title` in a partial with a `title` local).
- A rescued exception while writing attributes left a half-written start tag in the output.
- `HtmlBeautifierMiddleware` beautified each streamed chunk separately, didn't close the body, and touched gzip/204/304 responses.
- The packaged gem shipped a locally compiled `.so`; `rake build` didn't build a gem.

### Upgrading to 2.0

Templates and components:
1. `self` in `.html.rb` templates is now the view (or component), not a `Ruby2html::Render`. Replace `self.div` / `self.plain` with `div` / `plain`. Without Prism (Ruby < 3.3 and no `prism` gem) templates still use the 1.x path.
2. `Thread.current[:__ruby2html_renderer__]` is gone. The active renderer lives on the component/view; use `component.__ruby2html_renderer__`.
3. `form_with` output now matches Rails (`_method`, `accept-charset`, no forced `data-remote`, no `utf8` field); its builder is a proxy around Rails' `FormBuilder`.
4. `Ruby2html::ComponentHelper#method_missing` is now private.

HTML output:
5. Non-String content renders: `p 42` → `<p>42</p>` (1.x: `<p></p>`); `nil` renders nothing.
6. `html_safe` strings passed as content or returned from a block are inserted raw (1.x escaped them).
7. A block's return value is used only if the block wrote nothing, and only for String/Symbol/Numeric (1.x: a returned String replaced everything the block wrote).
8. Attributes: `true` → bare attribute and `false` omitted (except `data-*`, `aria-*`, `draggable`, `spellcheck`, `contenteditable`, which keep `"true"`/`"false"`); Hash values expand; Arrays join with spaces; invalid attribute names raise `ArgumentError`; Hashes/Arrays nested deeper than 32 levels raise `ArgumentError`.
9. Tag methods accept at most one positional argument (extra arguments raise `ArgumentError`).
10. The output buffer is UTF-8; strings in other encodings are transcoded (raising `EncodingError` if impossible).

Removed / packaging:
11. `Ruby2html::ATTRIBUTE_CACHE`, `Render::METHOD_DEFINITIONS`, `Render#output` and the `Render#fast_escape_html` / `#fast_attributes_to_s` / `#fast_buffer_append` / `#fast_render_tag` methods are removed. Use `Ruby2html.escape_html`, the value returned by `render`, or `current_output`.
12. Ruby >= 3.1 and (for Rails integration) Rails >= 7.2 are required.
13. `htmlbeautifier` is no longer a dependency: add `gem 'htmlbeautifier'` if you use `Ruby2html::HtmlBeautifierMiddleware`.
14. The gem's require path is `lib/gem` only.

## [1.6.6] - 2025-02-10

### Fixed
- Stop shipping a prebuilt `lib/ruby2html/ruby2html.so`; the extension is compiled on install (`*.so` gitignored).

## [1.6.4] - 2025-02-09

### Fixed
- Renderer fixes following the C extension introduction.

## [1.6.3] - 2025-02-09

### Fixed
- Template handler, `form_with` and gemspec fixes for the C extension build.

## [1.6.2] - 2025-02-09
## [1.6.1] - 2025-02-09

Published to RubyGems; no separate commits in the repository history.

## [1.6.0] - 2025-02-09

### Added
- C extension (`ext/ruby2html`) for HTML escaping, attribute serialization and buffer appends; `rake compile` via rake-compiler.

## [1.5.8] - 2024-11-01
## [1.5.7] - 2024-11-01

### Changed
- Load `htmlbeautifier` from the main entry file; renderer cleanup. Dependency updates.

## [1.5.6] - 2024-08-17
## [1.5.5] - 2024-08-17

### Changed
- Template handler declares `handles_encoding?`; Railtie cleanup.

## [1.5.4] - 2024-08-12

### Changed
- Gemspec cleanup.

## [1.5.3] - 2024-08-12

### Added
- `turbo_stream` tag (`<turbo-stream>`).

## [1.5.2] - 2024-08-12

### Added
- `turbo_frame` tag (`<turbo-frame>`).

## [1.5.1] - 2024-08-12

### Fixed
- `link_to` wrapper simplified.

## [1.5.0] - 2024-08-12

### Added
- Rails helper wrappers: `form_with` (with `label`, `text_field`, `hidden_field`, `password_field`, `file_field`, `submit`), `button_to`, `link_to`, `image_tag`.

## [1.4.0] - 2024-08-10

### Added
- `Ruby2html::HtmlBeautifierMiddleware`; runtime dependency on `htmlbeautifier`.

## [1.3.3] - 2024-08-10

### Added
- Support for `config.action_view.annotate_rendered_view_with_filenames`.

## [1.3.2] - 2024-08-09

### Fixed
- Keyword option handling in tag methods.

## [1.3.1] - 2024-08-09

### Fixed
- `ComponentHelper` renderer bug.

## [1.3.0] - 2024-08-09

### Added
- Calling component methods from component templates; nested renderer tracking.

## [1.2.0] - 2024-08-09

### Added
- ViewComponent support: `.html.rb` component templates, `Ruby2html::ComponentHelper`.

## [1.1.0] - 2024-08-08

### Added
- `.rb` ActionView template handler (`*.html.rb` views and partials).

## [1.0.0] - 2024-08-08

### Added
- Initial release: `Ruby2html::Render` DSL, `Ruby2html::RailsHelper#html` for ERB.

[Unreleased]: https://github.com/sebyx07/ruby2html/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/sebyx07/ruby2html/releases/tag/v2.0.0
[1.6.6]: https://rubygems.org/gems/ruby2html/versions/1.6.6
[1.6.4]: https://rubygems.org/gems/ruby2html/versions/1.6.4
[1.6.3]: https://rubygems.org/gems/ruby2html/versions/1.6.3
[1.6.2]: https://rubygems.org/gems/ruby2html/versions/1.6.2
[1.6.1]: https://rubygems.org/gems/ruby2html/versions/1.6.1
[1.6.0]: https://rubygems.org/gems/ruby2html/versions/1.6.0
[1.5.8]: https://rubygems.org/gems/ruby2html/versions/1.5.8
[1.5.7]: https://rubygems.org/gems/ruby2html/versions/1.5.7
[1.5.6]: https://rubygems.org/gems/ruby2html/versions/1.5.6
[1.5.5]: https://rubygems.org/gems/ruby2html/versions/1.5.5
[1.5.4]: https://rubygems.org/gems/ruby2html/versions/1.5.4
[1.5.3]: https://rubygems.org/gems/ruby2html/versions/1.5.3
[1.5.2]: https://rubygems.org/gems/ruby2html/versions/1.5.2
[1.5.1]: https://rubygems.org/gems/ruby2html/versions/1.5.1
[1.5.0]: https://rubygems.org/gems/ruby2html/versions/1.5.0
[1.4.0]: https://rubygems.org/gems/ruby2html/versions/1.4.0
[1.3.3]: https://rubygems.org/gems/ruby2html/versions/1.3.3
[1.3.2]: https://rubygems.org/gems/ruby2html/versions/1.3.2
[1.3.1]: https://rubygems.org/gems/ruby2html/versions/1.3.1
[1.3.0]: https://rubygems.org/gems/ruby2html/versions/1.3.0
[1.2.0]: https://rubygems.org/gems/ruby2html/versions/1.2.0
[1.1.0]: https://rubygems.org/gems/ruby2html/versions/1.1.0
[1.0.0]: https://rubygems.org/gems/ruby2html/versions/1.0.0
