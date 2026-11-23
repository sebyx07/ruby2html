# lib/ — the gem's Ruby code

Only `lib/gem/**/*.rb` ships in the gem (`ruby2html.gemspec`; `require_paths = ['lib/gem']`). The rest of `lib/` belongs to the checkout: `lib/ruby2html/ruby2html.so` is `rake compile` output (gitignored, found by `render.rb` through `require_relative`), `lib/tasks/` and `lib/assets/` are the demo app's. Never glob all of `lib/` into the gemspec.

## Code map (`lib/gem/`)

| File | Responsibility |
|---|---|
| `ruby2html.rb` | Entry point: eager-loads only `version` and `render`; everything else is `autoload`ed (`Component`, `ComponentHelper`, `RailsHelper`, `HtmlBeautifierMiddleware`, `RailsComponents::*`); requires `railtie` only when ActiveSupport is loaded |
| `ruby2html/render.rb` | Loads Native (or PureRuby) into `Ruby2html::IMPLEMENTATION`; `load_native_extension` returns false on JRuby and TruffleRuby; `Ruby2html.native?`, `Ruby2html.escape_html`; `Render`: `HTML5_TAGS`, `VOID_ELEMENTS`, defines the tags on both implementations through `define_tag`, includes the implementation; `render`, `method_missing` to the context, Rails helper wrappers, ivar copying |
| `ruby2html/render/pure_ruby.rb` | Ruby twin of Native: tag methods, `plain`, `component`, text and attribute rules, `escape_html`. `escape` picks the fastest escaper available: ERB's C escaper on CRuby, `Ruby2html::JavaNative` on JRuby, else a regex. All byte-identical |
| `ruby2html/railtie.rb` | `TemplateHandler` for `.rb` templates: compiled strategy through `TemplateCompiler` (the template runs with self = view or component, renderer in `@__r2h`); closure fallback when Prism is missing or the parse fails (`instance_exec` on a `Render`, with ivar copying); filename annotations; Zeitwerk ignores `app/**/*.html.rb` |
| `ruby2html/rails_components/template_compiler.rb`, `template_collector.rb` | Prism rewrite of receiverless tag, `plain`, `component`, `render` and helper calls. Prism is required lazily on the first compile (`available?`); the Railtie's `before_eager_load` loads it at boot in eager-loading apps |
| `ruby2html/rails_components/template_helpers.rb` | Receiver for `link_to button_to image_tag form_with render capture content_for provide` in compiled templates |
| `ruby2html/rails_components/{base_component,link_to,button_to,image_tag,form_with,output_capture}.rb` | Call the real Rails helper, capture nested ruby2html output for its block, append the result; `FormBuilderProxy` |
| `ruby2html/component.rb` | `Ruby2html::Component`: includes the implementation directly (self = component); `view_template` / `call`, `render_in(view_context)`, `render_into(buffer, ...)` for nesting into a parent buffer, `helpers`, `content`, Rails helper wrappers |
| `ruby2html/component_helper.rb` | ViewComponent `html(&block)`; current renderer in `@__r2h` (saved and restored in `ensure`, fiber-safe, no `Thread.current`); `__ruby2html_renderer__`; private `method_missing` to the renderer |
| `ruby2html/rails_helper.rb` | `html(context, &block)` for ERB; `helper_method` when included in a controller |
| `ruby2html/html_beautifier_middleware.rb` | Development middleware; requires `htmlbeautifier` lazily and raises a helpful `LoadError` when it is missing |

The C side of the renderer: `ext/CLAUDE.md`.

## Rules

- **`pure_ruby.rb` and the C extension change together.** A text, attribute, tag, escaping or error rule lands on both sides in one change, with a spec in a `RenderSpecHelper.describe_each` group or `spec/gem/render_parity_spec.rb`. A start-tag exception rolls the buffer back to before the tag.
- **Tag methods:** at most one positional argument; with a block, the block wins; a block's return value counts only when the block wrote nothing (String, Symbol, Numeric); void tags ignore content and block.
- **Adding a tag:** `HTML5_TAGS` (and `VOID_ELEMENTS`) only. Skill `add-html-tag`.
- **Never add a public `Render` method named like a tag.** `Render#output` once hid `<output>`.
- **`method_missing` on the renderer** forwards only **public** context methods, and a forwarded return value is not appended.
- **Who is `self`.** Compiled `.html.rb` templates and `Ruby2html::Component` run with self = view or component (no forwarding). `ComponentHelper#html` blocks and the closure fallback run on the renderer, so **a tag name beats a same-named component method or slot** (`header` renders `<header>`).
- **`capture`, `content_for`, `provide`** in compiled templates route to `TemplateHelpers`, which swaps the renderer buffer (ActionView's own capture cannot see ruby2html output). Inside ViewComponent `html` blocks they still go to the view.
- **`TemplateCompiler` inserts text only, never a newline**, so template line numbers stay correct. It skips `def`, `class` and `module` bodies, explicit-receiver calls, and `Render.new { }` blocks (those run on their own renderer).
- **Keep `require 'ruby2html'` light:** no Prism, no ERB engine, no `htmlbeautifier` at load. New files are `autoload`ed.
- **Helper output in `rails_components/`** is `html_safe`-aware: never double-escaped, never under-escaped.
- **No runtime dependency** in the gemspec. `htmlbeautifier` is optional and lazy.
- RuboCop `TargetRubyVersion` is the gemspec floor: no syntax newer than that in `lib/gem/`.

## Public API (a contract)

`Render.new(ctx, &blk)`, `#render`, `#plain`, `#component`, the tag methods, `Ruby2html.escape_html`, `Ruby2html.native?`, `Ruby2html::Component`, `RailsHelper#html`, `ComponentHelper#html` and `#__ruby2html_renderer__`, the `.rb` template handler, `HtmlBeautifierMiddleware`.

Breaking any of these: the owner decides first; then a CHANGELOG "Upgrading" entry and a major bump. User-visible behavior change: `CHANGELOG.md` `## [Unreleased]` and `llms.txt`.

## Verify

| Changed | Run |
|---|---|
| `render.rb`, `render/pure_ruby.rb` | `CI=1 bundle exec rspec spec/gem`, then `RUBY2HTML_DISABLE_EXT=1 bundle exec rspec spec/gem`; `bundle exec rake bench` when on a hot path |
| `railtie.rb`, `rails_components/**`, `component.rb`, `component_helper.rb` | `CI=1 bundle exec rspec spec/gem/rails spec/features`; try the demo pages with `bin/dev` |
| `html_beautifier_middleware.rb` | `bundle exec rspec spec/gem/rails/html_beautifier_middleware_spec.rb` |
| `version.rb` | Only in a release PR: `.github/CLAUDE.md` |
| Anything | `bin/check` before the PR |
