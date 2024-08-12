# frozen_string_literal: true

module Ruby2html
  module RailsComponents
    class ButtonTo < BaseComponent
      def render(&block)
        @render.plain(@context.button_to(*@args, **@options, &block))
      end
    end
  end
end
