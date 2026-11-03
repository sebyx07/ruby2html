# frozen_string_literal: true

# Entry point. Loads only the renderer eagerly; everything else is autoloaded
# on first use, so `require 'ruby2html'` outside Rails stays small and fast
# (no Prism, no ActionView glue, no htmlbeautifier).
require_relative 'ruby2html/version'
require_relative 'ruby2html/render'

module Ruby2html
  class Error < StandardError; end

  autoload :Component, File.expand_path('ruby2html/component', __dir__)
  autoload :ComponentHelper, File.expand_path('ruby2html/component_helper', __dir__)
  autoload :RailsHelper, File.expand_path('ruby2html/rails_helper', __dir__)
  autoload :HtmlBeautifierMiddleware, File.expand_path('ruby2html/html_beautifier_middleware', __dir__)

  # Rails helper wrappers and the .html.rb template compiler (needs Prism).
  module RailsComponents
    {
      OutputCapture: 'output_capture',
      BaseComponent: 'base_component',
      LinkTo: 'link_to',
      ButtonTo: 'button_to',
      ImageTag: 'image_tag',
      FormWith: 'form_with',
      TemplateHelpers: 'template_helpers',
      TemplateCompiler: 'template_compiler'
    }.each { |name, file| autoload name, File.expand_path("ruby2html/rails_components/#{file}", __dir__) }
  end
end

# Template handler + Railtie. Registers lazily via ActiveSupport.on_load, so
# it costs nothing until ActionView loads; a no-op without ActiveSupport.
require_relative 'ruby2html/railtie' if defined?(ActiveSupport)
