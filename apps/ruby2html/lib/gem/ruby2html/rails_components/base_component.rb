# frozen_string_literal: true

require_relative 'output_capture'

module Ruby2html
  module RailsComponents
    # Calls the Rails helper named +method+ on the view context and appends its
    # (html_safe) result to the renderer. A block given to the helper is
    # captured from the renderer's buffer, so nested Ruby2html tags end up
    # inside the helper's markup.
    class BaseComponent
      include OutputCapture

      def initialize(render, context, method, *args, **options)
        @render = render
        @context = context
        @method = method
        @args = args
        @options = options
      end

      def render(&block)
        @render.plain(@context.public_send(@method, *@args, **@options, &capturing(block)))
        nil
      end
    end
  end
end
