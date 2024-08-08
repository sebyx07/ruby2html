# Ruby2html 🔮✨

Transform your Ruby code into beautiful, structured HTML with ease! 🚀

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

### In your ApplicationController

File: `app/controllers/application_controller.rb`

```ruby
# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Ruby2html::RailsHelper
end
```

### In your views

File: `app/views/your_view.html.erb`

Replace your ERB with beautiful Ruby code:

```erb
<%=
  html(self) do
    h1 class: 'main-title', 'data-controller': 'welcome' do
      "Welcome to Ruby2html! 🎉"
    end
    div id: 'content', class: 'container' do
      link_to 'Home Sweet Home 🏠', root_path, class: 'btn btn-primary', 'data-turbo': false
    end

    @items.each do |item|
      h2 class: 'item-title', id: "item-#{item[:id]}" do
        plain item[:title]
      end
      p class: 'item-description' do
        plain item[:description]
      end
    end

    render partial: 'shared/navbar'
  end
%>
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
    html(self) do
      h1 class: 'greeting', 'data-user': @name do
        plain "Hello, #{@name}! 👋"
      end
      p class: 'welcome-message' do
        plain 'Welcome to the wonderful world of Ruby2html!'
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

File: `app/components/farewell_component.html.erb`

```erb
<div class="farewell">
  <h2>Goodbye, <%= @name %>! 👋</h2>
  <p>We hope you enjoyed using Ruby2html!</p>

  <%=
    html do
      link_to 'Home', root_path, class: 'btn btn-primary', 'data-turbo': false
    end
  %>
</div>
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
    html(self) do
      h1 id: 'first-component-title' do
        plain 'first component'
      end
      div class: 'content-wrapper' do
        h2 'A subheading'
      end
      p class: 'greeting-text', 'data-testid': 'greeting' do
        plain @item
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
    html(self) do
      h1 class: 'my-class', id: 'second-component-title', 'data-controller': 'second' do
        plain 'second component'
      end
      link_to 'Home', root_path, class: 'nav-link', 'data-turbo-frame': false
    end
  end
end
```

## Without Rails
```ruby
html = Ruby2html::Render.new(nil) do # nil is the context, you can use self or any other object
  html do
    h1 'Hello, World!'
  end
end

puts html.render
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