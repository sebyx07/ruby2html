# frozen_string_literal: true

# The template handler and Railtie only make sense with ActiveSupport/ActionView.
return unless defined?(ActiveSupport)

require 'active_support/core_ext/class/attribute'
require_relative '../ruby2html' unless defined?(Ruby2html::RailsComponents) # autoloads

module Ruby2html
  # ActionView template handler for +*.html.rb+ views, partials and
  # ViewComponent sidecar templates.
  #
  # Templates are compiled once by ActionView; all decisions that don't depend
  # on the request (rewriting, annotations, whether helpers are needed) are
  # made here so the compiled method does as little as possible per render.
  #
  # Two strategies:
  # * compiled (default): TemplateCompiler rewrites the source so it runs in
  #   the view itself. No instance variable copying, no instance_exec, helper
  #   calls go straight to the view.
  # * closure (fallback when Prism is unavailable or the source doesn't
  #   parse): the source becomes a block instance_exec'd on a Render that
  #   copies the view's instance variables, as in 1.x.
  class TemplateHandler
    # Render#render runs its root block; compiled templates have already
    # written their output, so they pass this shared no-op.
    NOOP = proc { }

    # Every generated prologue ends on the template's first line so that
    # backtrace line numbers point at the right line of the .html.rb file.
    # Locals are prefixed because the template code shares their scope.
    #
    # The renderer is held in a local and published on the view/component as
    # +@__r2h+ (the slot ComponentHelper#method_missing reads), restoring the
    # previous value afterwards so nested partials/components on the same
    # object stay correct. No thread/fiber-global state is involved.
    SAVE_PREVIOUS = '__r2h_prev = @__r2h; begin; '
    COMPILED_PROLOGUE = "#{SAVE_PREVIOUS}__r2h_renderer = Ruby2html::Render.new(nil, &Ruby2html::TemplateHandler::NOOP); "
    HELPERS_PROLOGUE = '__r2h_helpers = Ruby2html::RailsComponents::TemplateHelpers.new(__r2h_renderer, self); '
    PUSH_RENDERER = '@__r2h = __r2h_renderer'
    CLOSURE_PROLOGUE = "#{SAVE_PREVIOUS}__r2h_renderer = Ruby2html::Render.new(self) do; "
    EPILOGUE = "\nensure\n@__r2h = __r2h_prev\nend"

    class_attribute :default_format
    self.default_format = :html

    class << self
      def call(template, source)
        compiled = RailsComponents::TemplateCompiler.compile(source, template_locals(template))
        compiled ? compiled_code(template, compiled) : closure_code(template, source)
      end

      # This handler does no encoding work of its own, so let ActionView
      # transcode the source to Encoding.default_external (honouring an
      # `# encoding:` magic comment) before it reaches #call.
      def handles_encoding?
        false
      end

      private
        def template_locals(template)
          template.respond_to?(:locals) ? Array(template.locals) : []
        end

        def compiled_code(template, compiled)
          helpers = compiled.uses_helpers ? HELPERS_PROLOGUE : ''
          "#{COMPILED_PROLOGUE}#{helpers}#{PUSH_RENDERER}; #{compiled.source}\n" \
            "#{render_expression(template)}#{EPILOGUE}"
        end

        def closure_code(template, source)
          "#{CLOSURE_PROLOGUE}#{source}\nend\n#{PUSH_RENDERER}\n#{render_expression(template)}#{EPILOGUE}"
        end

        # Mirrors the ERB handler: wrap HTML templates in BEGIN/END comments
        # when config.action_view.annotate_rendered_view_with_filenames is on.
        def render_expression(template)
          return '__r2h_renderer.render' unless annotate?(template)

          path = template.short_identifier
          "ActiveSupport::SafeBuffer.new(#{"<!-- BEGIN #{path} -->".inspect})" \
            '.safe_concat(__r2h_renderer.render)' \
            ".safe_concat(#{"<!-- END #{path} -->".inspect})"
        end

        def annotate?(template)
          defined?(ActionView::Base) &&
            ActionView::Base.annotate_rendered_view_with_filenames &&
            template.respond_to?(:format) && template.format == :html &&
            template.respond_to?(:short_identifier)
        end
    end
  end

  if defined?(Rails::Railtie)
    class Railtie < Rails::Railtie
      # Lazy by default (dev, tests, plain `require`). When the app eager-loads
      # (production), load everything up front instead: no first-request
      # latency, and forking servers share these pages copy-on-write.
      config.before_eager_load do
        Ruby2html::RailsComponents::TemplateCompiler.available? # loads Prism
        Ruby2html::RailsComponents.constants.each { |name| Ruby2html::RailsComponents.const_get(name) }
        Ruby2html::Component
        Ruby2html::ComponentHelper
      end

      initializer 'ruby2html.initializer' do
        # *.html.rb files are templates, not constants: keep Zeitwerk from
        # trying to autoload/eager-load them anywhere under app/.
        Rails.autoloaders.main.ignore(Rails.root.join('app/**/*.html.rb'))
      end
    end
  end
end

# Register lazily so requiring the gem doesn't force ActionView to load.
ActiveSupport.on_load(:action_view) do
  ActionView::Template.register_template_handler :rb, Ruby2html::TemplateHandler
end
