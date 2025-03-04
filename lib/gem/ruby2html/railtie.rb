# frozen_string_literal: true

if defined?(Rails)
  module Ruby2html
    class TemplateHandler
      class_attribute :default_format
      self.default_format = :html

      def self.call(template, source)
        <<-RUBY
begin
previous_renderer = Thread.current[:__ruby2html_renderer__]
renderer = Ruby2html::Render.new(self) do
#{source}
end
Thread.current[:__ruby2html_renderer__] = renderer
renderer.__render_from_rails(#{template.identifier.inspect})
ensure
Thread.current[:__ruby2html_renderer__] = previous_renderer
end
        RUBY
      end

      def self.handles_encoding?
        true
      end
    end

    class Railtie < Rails::Railtie
      initializer 'ruby2html.initializer' do
        Rails.autoloaders.main.ignore(
          Rails.root.join('app/views/**/*.html.rb'),
          Rails.root.join('app/components/**/*.html.rb')
        )
      end
    end
  end

  ActionView::Template.register_template_handler :rb, Ruby2html::TemplateHandler
end
