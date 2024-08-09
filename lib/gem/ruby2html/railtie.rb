# frozen_string_literal: true

module Ruby2html
  class TemplateHandler
    class_attribute :default_format
    self.default_format = :html

    def self.call(template, source)
      new.call(template, source)
    end

    def call(_template, source)
      <<-RUBY
        Ruby2html::Render.new(self) do
          #{source}
        end.render
      RUBY
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

ActionView::Template.register_template_handler :rb, Ruby2html::TemplateHandler if defined? ActionView::Template
