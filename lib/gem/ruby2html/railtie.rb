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
end

ActionView::Template.register_template_handler :rb, Ruby2html::TemplateHandler if defined? ActionView::Template
