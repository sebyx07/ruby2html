# frozen_string_literal: true

module Ruby2html
  module RailsComponents
    class BaseComponent
      def initialize(render, context, method, *args, **options)
        @render = render
        @context = context
        @method = method
        @args = args
        @options = options
      end

      def render(&block)
        raise NotImplementedError
      end
    end
  end
end
