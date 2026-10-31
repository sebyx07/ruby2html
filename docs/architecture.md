# Architecture

How ruby2html turns Ruby into HTML. Paths refer to `lib/gem/` and `ext/ruby2html/`. The authoritative rule text lives in the header comments of `ext/ruby2html/content.c`, `attributes.c`, `tag_render.c` and `html_escape.c`; `render/pure_ruby.rb` mirrors them.

## Layers

```
.html.rb template ──TemplateHandler──► compiled view method (self = view)  ─┐
ViewComponent + ComponentHelper#html ──► Ruby2html::Render (instance_exec) ─┼─► tag methods from IMPLEMENTATION
ERB html(self) { } (RailsHelper)     ──► Ruby2html::Render (instance_exec) ─┤     (Ruby2html::Native in C, or
Ruby2html::Component#view_template   ──► self = component                  ─┘      Ruby2html::PureRuby)
                                                                                    write into one UTF-8 String buffer
```

## Load sequence

1. `require 'ruby2html'` → `lib/gem/ruby2html.rb` requires every `ruby2html/**/*.rb`.
2. `render.rb` requires `render/pure_ruby.rb`, then tries the extension: `require 'ruby2html/ruby2html'` (installed gem: built into `lib/gem/ruby2html/`), else `require_relative '../../ruby2html/ruby2html'` (checkout: `rake compile` output in `lib/ruby2html/`). `RUBY2HTML_DISABLE_EXT=1` skips it. Result: `Ruby2html::IMPLEMENTATION` = `Native` or `PureRuby`; `Ruby2html.native?`.
3. `Init_ruby2html` defines module `Ruby2html::Native` with instance methods `plain`, `component` and singleton methods `define_tag`, `escape_html`.
4. `Render` calls `define_tag(method, tag, void)` for every `HTML5_TAGS` entry on **both** PureRuby and the active implementation (so specs can compare them in one process), then `include IMPLEMENTATION`. `Ruby2html::Component` includes the same module.
5. With ActiveSupport loaded, `railtie.rb` defines `TemplateHandler` and registers it for `.rb` in `on_load(:action_view)`; with Rails, the Railtie makes Zeitwerk ignore `app/**/*.html.rb`.

## Tag methods and output rules

Every tag method reads the target buffer from `@current_output` of `self` (a `Render`, a `Ruby2html::Component`, or anything with that ivar) and writes straight into it:

1. `<tag` + attributes, then ` />` (void: done, content/block ignored) or `>`.
2. With a block: yield; if the buffer did not grow, append the block's return value when it is String/Symbol/Numeric. Without a block: append `content`.
3. `</tag>`; return `nil`.

Text (`content.c` / `__r2h_text`): `nil` → nothing; exact `String` → escaped; String subclass or other object that is `html_safe?` → raw; Symbol / Integer → escaped `to_s`; anything else → `to_s`, raw if `html_safe?` else escaped. `plain(x)` applies the same rule; `component(x)` appends `x.to_s` raw.

Attributes (`attributes.c` / `__r2h_attributes`): `nil` omitted; `true` bare name / `false` omitted, except `data-*`, `aria-*`, `draggable`, `spellcheck`, `contenteditable` which get `"true"`/`"false"`; Hash expands with prefix (`data: { user_id: 1 }` → `data-user-id`, `_` → `-` only in nested keys); Array → space-joined escaped tokens, `nil`/`false` skipped; otherwise `to_s` escaped. Names are validated (no control chars, space, `" ' < > / =`, not empty) and raise `ArgumentError`. Nothing is cached.

Escaping (`html_escape.c`): `& < > " '` → `&amp; &lt; &gt; &quot; &#39;`. 16-byte SSE2 (x86_64) or NEON (aarch64) scan, scalar with `-DR2H_NO_SIMD` (`RUBY2HTML_NO_SIMD=1 rake compile`). Clean input is one `memcpy`; dirty input gets its exact size computed, then one pass copying clean runs. Input encodings: UTF-8/US-ASCII/BINARY copied as bytes, ASCII-only copied, others transcoded to UTF-8 (raises if impossible). `Ruby2html.escape_html` never returns the caller's mutable string.

C buffer handling (`buffer.h`): reserve (at least doubling capacity, to keep long renders linear), `memcpy`, commit length. Tag methods are C functions bound through a fixed pool of 200 trampolines (`R2H_MAX_TAGS`); tag names must be `[a-z0-9-]`, ≤ 32 bytes. IDs are interned at Init.

## `Ruby2html::Render`

State: `@context`, `@root` block, `@output` (`String.new(capacity: 4096, encoding: UTF_8)`), `@current_output`.

- `render` (no args): copy context ivars once (skipping `@_*`, `@output`, `@current_output`, `@context`, `@root`), `instance_exec(&@root)`, return `@output` (wrapped in `ActiveSupport::SafeBuffer` when loaded).
- `render(*args, **opts, &blk)`: `plain(@context.render(...))`.
- Private `method_missing` forwards to the context if it publicly responds; return values are not appended.
- With ActionView: private `link_to image_tag form_with button_to` → `RailsComponents::<Name>`.

## Rails

### Template handler (`.html.rb`)

`TemplateHandler.call(template, source)` picks a strategy:

**Compiled** (default; needs Prism and a parseable template). `RailsComponents::TemplateCompiler` walks the Prism AST and inserts text (never newlines, so line numbers stay correct) in front of receiverless calls, skipping `def`/`class`/`module` bodies:

```ruby
div class: 'x' do      # => __r2h_renderer.div class: 'x' do
link_to 'Home', '/'    # => __r2h_helpers.link_to 'Home', '/'
render partial: 'nav'  # => __r2h_renderer.plain(render partial: 'nav')
```

The generated method body (source starts on the first line):

```ruby
__r2h_prev = @__r2h; begin; __r2h_renderer = Ruby2html::Render.new(nil, &NOOP); [__r2h_helpers = TemplateHelpers.new(__r2h_renderer, self); ]@__r2h = __r2h_renderer; <rewritten source>
__r2h_renderer.render      # or BEGIN/END filename comments when annotate_rendered_view_with_filenames
ensure
@__r2h = __r2h_prev
end
```

So the template runs with `self` = the view or component: ivars, locals, private helpers are native, nothing is copied. `TemplateHelpers` routes the four Rails helpers through `RailsComponents`.

**Closure** (no Prism, or parse failure so Ruby reports the syntax error): the source becomes the block of `Ruby2html::Render.new(self) do ... end` (1.x semantics: `instance_exec` on the renderer, ivars copied, `method_missing` to the view).

`handles_encoding?` is `false`, so ActionView transcodes the source first.

### Helper wrappers (`rails_components/`)

- `BaseComponent#render`: `@render.plain(@context.public_send(method, *args, **opts, &capturing(block)))`. `@render` is anything with `plain` and `current_output` (a `Render` or a `Ruby2html::Component`).
- `OutputCapture#capturing`: wraps the block so it runs with `@render.current_output` swapped to a scratch buffer; returns the buffer as `html_safe` if anything was written, else the block's value (ActionView `capture` semantics). Nested tags therefore land inside the helper's markup.
- `LinkTo`, `ButtonTo`, `ImageTag`: plain subclasses. `FormWith`: yields a `FormBuilderProxy` around Rails' `FormBuilder`; `html_safe` String results are appended and `nil` returned, other results returned as is; nested builders are wrapped too.
- `content_for`/`capture` blocks are not bridged: ruby2html tags inside them write to the ruby2html buffer.

### `RailsHelper#html(context, &block)`

`Render.new(context, &block).render` as `html_safe`; registered with `helper_method` when included in a controller.

## Components

### ViewComponent (`ComponentHelper`)

`html(&block)`: save `@__r2h`, set it to `Render.new(self, &block)`, render, restore in `ensure`. The renderer lives on the component (fiber-safe; no global state). Private `method_missing` forwards to `@__r2h` so component methods called during a render can emit tags; `respond_to_missing?` only claims `Render` methods (avoids recursion). The block runs on the renderer, so tag names shadow component methods/slots of the same name. Sidecar `.html.rb` templates use the template handler with `self` = component.

### `Ruby2html::Component`

Includes `IMPLEMENTATION` itself, so `view_template` (or `call`) runs with `self` = component and writes to `@current_output`.

- `render_in(view_context, &block)` (Rails entry): allocates a buffer pre-sized from the class's last output size (`__r2h_capacity`), calls `render_into`, returns a SafeBuffer.
- `render_into(buffer, view_context, content)`: swaps in buffer/helpers/content, calls the entry method, restores in `ensure` (re-entrant).
- `render(component)` writes a nested `Ruby2html::Component` into the same buffer; other arguments go through `helpers.render` and are appended.
- `helpers` = view context (raises `Ruby2html::Error` outside a render); `content` runs the caller's block via `view_context.capture`.
- `link_to button_to image_tag form_with` → `RailsComponents` with the component as renderer.

## HtmlBeautifierMiddleware

Lazy-requires `htmlbeautifier` at construction (clear `LoadError` if absent). Beautifies only buffered (`to_ary`) `text/html` bodies with status ≥ 200 (not 204/304) and no `Content-Encoding`/`Transfer-Encoding`; joins chunks, beautifies, sets `Content-Length`, closes the original body. Header lookup is case-insensitive.

## Demo app, specs, benchmarks

- `config/application.rb` loads the gem with `require_relative '../lib/gem/ruby2html'`.
- `BenchmarkController` renders `COMPLEX_DATA` via ERB, Slim, `.html.rb`, a ViewComponent (`BenchmarkComponent`) and Phlex; `spec/benchmarks/requests_spec.rb` compares them.
- `bench/render_bench.rb` (page render vs Phlex/Erubi, allocations), `bench/tag_bench.rb` (per-tag call shapes), `bench/escape_bench.rb` (escaping throughput); `rake bench` runs all.
- `spec/gem/render_spec_helper.rb` defines groups once and runs them for Native and PureRuby; `render_parity_spec.rb` compares outputs directly.

## Design constraints

- Speed over memory: one buffer per top-level render, direct writes from C, compile-time template rewriting, no per-call allocations on hot paths.
- Secure by default: text and attribute values escaped; raw only for `html_safe?` and `component`; attribute/tag names validated.
- Native and PureRuby are behaviorally identical; JRuby or failed builds still work.
- No runtime dependencies.
