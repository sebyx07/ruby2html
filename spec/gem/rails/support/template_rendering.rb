# frozen_string_literal: true

# Renders in-memory .html.rb templates through the real ActionView pipeline
# (resolver -> TemplateHandler -> compiled method), without touching app/views.
module TemplateRendering
  class SpecController < ActionController::Base
    layout false

    def self.name
      'SpecController'
    end
  end

  def render_template(templates, template: 'spec/show', assigns: {}, locals: {}, layout: false)
    controller = Class.new(SpecController)
    controller.view_paths = [ActionView::FixtureResolver.new(templates)]
    controller.render(template:, assigns:, locals:, layout:)
  end

  # Shortcut for a single template at spec/show.html.rb.
  def render_source(source, **options)
    render_template({ 'spec/show.html.rb' => source }, **options)
  end
end
