# Ruby2html 🔮✨

Transform your view logic into elegant, semantic HTML with the power of pure Ruby! 🚀✨

## 🌟 What is Ruby2html?

Ruby2html is a magical gem that allows you to write your views in pure Ruby and automatically converts them into clean, well-formatted HTML. Say goodbye to messy ERB templates and hello to the full power of Ruby in your views! 🎉

## 🚀 Installation

Add this line to your application's Gemfile:


```ruby
gem 'ruby2html'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install ruby2html

## 🎨 Usage

### In your views

File: `app/views/your_view.html.rb`

```ruby
div class: 'container' do
  h1 'Welcome to Ruby2html! 🎉', class: 'main-title', 'data-controller': 'welcome'
  link_to 'Home Sweet Home 🏠', root_path, class: 'btn btn-primary', 'data-turbo': false

  @products.each do |product|
    h2 class: 'item-title', id: "product-#{product[:id]}" do
      product.title
    end
    p class: 'item-description' do
      product.description
    end
  end
end

plain '<div>Inline html</div>'.html_safe

render partial: 'shared/navbar'
```

### (Optional) Nicely Format the HTML for source inspection

File: `config/environments/development.rb` or `config/environments/test.rb`
```ruby
config.middleware.use Ruby2html::HtmlBeautifierMiddleware
```

#### Or use your current .erb views

### In your ApplicationController

File: `app/controllers/application_controller.rb`

```ruby
# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Ruby2html::RailsHelper # to access the <%= html %> helper
end
```

File: `app/views/your_view.html.erb`

Replace your ERB with beautiful Ruby code:

```erb
<%=
  html(self) do
    h1 "Welcome to Ruby2html! 🎉", class: 'main-title', 'data-controller': 'welcome'
    div id: 'content', class: 'container' do
      link_to 'Home Sweet Home 🏠', root_path, class: 'btn btn-primary', 'data-turbo': false
    end

    @items.each do |item|
      h2 class: 'item-title', id: "item-#{item[:id]}" do
        item.title
      end
      p class: 'item-description' do
        item.description
      end
    end

    plain "<div>Inline html</div>".html_safe

    render partial: 'shared/navbar'
  end
%>
```

### Benchmark

```bash
ruby 3.4.7 (2025-10-08 revision 7a5688e2a2) +YJIT +PRISM [x86_64-linux]
Warming up --------------------------------------
GET /benchmark/html (ERB)
                        32.000 i/100ms
GET /benchmark/ruby (Ruby2html templates .html.rb)
                        17.000 i/100ms
GET /benchmark/ruby (Ruby2html + view components)
                        12.000 i/100ms
GET /benchmark/slim (Slim)
                        36.000 i/100ms
GET /benchmark/phlex (Phlex)
                        28.000 i/100ms
Calculating -------------------------------------
GET /benchmark/html (ERB)
                        330.530 (± 2.4%) i/s -     19.840k in  60.061301s
GET /benchmark/ruby (Ruby2html templates .html.rb)
                        180.060 (± 1.7%) i/s -     10.812k in  60.068993s
GET /benchmark/ruby (Ruby2html + view components)
                        121.379 (± 2.5%) i/s -      7.284k in  60.055909s
GET /benchmark/slim (Slim)
                        367.488 (± 2.2%) i/s -     22.068k in  60.078459s
GET /benchmark/phlex (Phlex)
                        284.998 (± 1.8%) i/s -     17.108k in  60.047103s

Comparison:
GET /benchmark/slim (Slim):      367.5 i/s
GET /benchmark/html (ERB):      330.5 i/s - 1.11x  slower
GET /benchmark/phlex (Phlex):      285.0 i/s - 1.29x  slower
GET /benchmark/ruby (Ruby2html templates .html.rb):      180.1 i/s - 2.04x  slower
GET /benchmark/ruby (Ruby2html + view components):      121.4 i/s - 3.03x  slower
```

### With ViewComponents

Ruby2html seamlessly integrates with ViewComponents, offering flexibility in how you define your component's HTML structure. You can use the `call` method with Ruby2html syntax, or stick with traditional `.erb` template files.

File: `app/components/application_component.rb`

```ruby
# frozen_string_literal: true

class ApplicationComponent < ViewComponent::Base
  include Ruby2html::ComponentHelper
end
```

#### Option 1: Using `call` method with Ruby2html

File: `app/components/greeting_component.rb`

```ruby
# frozen_string_literal: true

class GreetingComponent < ApplicationComponent
  def initialize(name)
    @name = name
  end

  def call
    html do
      h1 class: 'greeting', 'data-user': @name do
        "Hello, #{@name}! 👋"
      end
      p class: 'welcome-message' do
        'Welcome to the wonderful world of Ruby2html!'
      end
    end
  end
end
```

#### Option 2: Using traditional ERB template

File: `app/components/farewell_component.rb`

```ruby
# frozen_string_literal: true

class FarewellComponent < ApplicationComponent
  def initialize(name)
    @name = name
  end
end
```

File: `app/components/farewell_component.html.rb`

```rb
div class: 'farewell' do
  h1 class: 'farewell-message' do
    "Goodbye, #{@name}! 👋"
  end
  p class: 'farewell-text' do
    'We hope to see you again soon!'
  end
end
```

This flexibility allows you to:
- Use Ruby2html syntax for new components or when refactoring existing ones
- Keep using familiar ERB templates where preferred
- Mix and match approaches within your application as needed

### More Component Examples

File: `app/components/first_component.rb`

```ruby
# frozen_string_literal: true

class FirstComponent < ApplicationComponent
  def initialize
    @item = 'Hello, World!'
  end

  def call
    html do
      h1 id: 'first-component-title' do
        'first component'
      end
      div class: 'content-wrapper' do
        h2 'A subheading'
      end
      p class: 'greeting-text', 'data-testid': 'greeting' do
        @item
      end
    end
  end
end
```

File: `app/components/second_component.rb`

```ruby
# frozen_string_literal: true

class SecondComponent < ApplicationComponent
  def call
    html do
      h1 class: 'my-class', id: 'second-component-title', 'data-controller': 'second' do
        'second component'
      end
      link_to 'Home', root_path, class: 'nav-link', 'data-turbo-frame': false
    end
  end
end
```

## Without Rails
```ruby
renderer = Ruby2html::Render.new(nil) do # context by default is nil, you can use self or any other object
  html do
    head do
      title 'Ruby2html Example'
    end
    body do
      h1 'Hello, World!'
    end
  end
end

puts renderer.render # => "<html><head><title>Ruby2html Example</title></head><body><h1>Hello, World!</h1></body></html>"
```

## 🐢 Gradual Adoption

One of the best features of Ruby2html is that you don't need to rewrite all your views at once! You can adopt it gradually, mixing Ruby2html with your existing ERB templates. This allows for a smooth transition at your own pace.

### Mixed usage example

File: `app/views/your_mixed_view.html.erb`

```erb
<h1>Welcome to our gradually evolving page!</h1>

<%= render partial: 'legacy_erb_partial' %>

<%=
  html(self) do
    div class: 'ruby2html-section' do
      h2 "This section is powered by Ruby2html!"
      p "Isn't it beautiful? 😍"
    end
  end
%>

<%= render ModernComponent.new %>

<footer>
  <!-- More legacy ERB code -->
</footer>
```

In this example, you can see how Ruby2html seamlessly integrates with existing ERB code. This approach allows you to:

- Keep your existing ERB templates and partials
- Gradually introduce Ruby2html in specific sections
- Use Ruby2html in new components while maintaining older ones
- Refactor your views at your own pace

Remember, there's no rush! You can keep your `.erb` files and Ruby2html code side by side until you're ready to fully transition. This flexibility ensures that adopting Ruby2html won't disrupt your existing workflow or require a massive rewrite of your application. 🌈

## ⚡ Performance

Ruby2html features extensive C extension optimizations for high-performance HTML generation:

### Benchmark Results (50 users × 1-5 orders × 1-10 items)

#### Ruby 3.4.7 +YJIT (After Optimizations)

```
Slim:                367.5 i/s - fastest
ERB:                 330.5 i/s - 1.11x slower
Phlex:               285.0 i/s - 1.29x slower
Ruby2html templates: 180.1 i/s - 2.04x slower
Ruby2html components:121.4 i/s - 3.03x slower
```

**Improvement on Ruby 3.3.4 baseline**: 125.0 → 180.1 i/s = **44% faster!**
**Gap to Phlex narrowed**: From 2.63x slower to only **1.58x slower** (180.1 vs 285.0 i/s)

**Performance varies by Ruby version.** The results above are on Ruby 3.4.7.

### C Extension + Phlex-Inspired Optimizations

1. **SIMD HTML Escaping** (SSE4.2)
   - Vectorized character scanning (16 bytes at once)
   - 3-10x faster for clean strings
   - Early exit fast path for content without special characters

2. **Optimized Tag Generation**
   - Complete tag rendering in C
   - Pre-allocated buffers with size estimation
   - 2-3x faster than pure Ruby

3. **Attribute Caching** (Phlex-inspired)
   - Global cache by `options.hash`
   - Frozen strings for zero-copy cache hits
   - **32% faster** on attribute-heavy rendering
   - Eliminates regenerating identical attribute combinations

4. **Specialized Code Paths** (Phlex-inspired)
   - Separate fast paths for ±attributes, ±block
   - Early returns for common cases
   - Direct buffer operations with chained `<<`
   - **17% faster** on complex nested structures

5. **Direct Hash Iteration**
   - Uses `rb_hash_foreach` instead of array allocation
   - 30% fewer allocations for attributes

6. **Lookup Table Escaping**
   - Branch-free character lookups
   - Zero branch mispredictions
   - 4-5% faster than switch statements

7. **Type & Compiler Optimizations**
   - Proper `size_t` usage for lengths/indices
   - `restrict` keyword for non-aliasing pointers
   - `__attribute__((always_inline))` for hot paths
   - Loop unrolling by 4

8. **Optimized Template Usage**
   - Direct string arguments instead of `plain` method
   - Eliminates unnecessary method call overhead
   - **78% improvement** in template rendering speed

### Performance vs Phlex

While Ruby2html is slower than Phlex in benchmarks, the difference is architectural rather than optimization-related:

- **Phlex advantage**: Direct instantiation, no Rails template overhead
- **Ruby2html focus**: Rails integration, automatic escaping, template-based architecture

See [PERFORMANCE_ANALYSIS.md](PERFORMANCE_ANALYSIS.md) for detailed analysis.

### When to Choose Ruby2html

- ✅ Need `.html.rb` template files (Rails conventions)
- ✅ Want automatic HTML escaping (security-first)
- ✅ Prefer template-based architecture
- ✅ Working with existing Rails views/controllers

## 🛠 Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## 🤝 Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sebyx07/ruby2html. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/sebyx07/ruby2html/blob/master/CODE_OF_CONDUCT.md).

## 📜 License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## 🌈 Code of Conduct

Everyone interacting in the Ruby2html project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/sebyx07/ruby2html/blob/master/CODE_OF_CONDUCT.md).

## 🌟 Features

- Write views in pure Ruby 💎
- Seamless Rails integration 🛤️
- ViewComponent support with flexible template options 🧩
- Automatic HTML beautification 💅
- Easy addition of custom attributes and data attributes 🏷️
- Gradual adoption - mix with existing ERB templates 🐢
- Improved readability and maintainability 📚
- Full access to Ruby's power in your views 💪

Start writing your views in Ruby today and experience the magic of Ruby2html! ✨🔮