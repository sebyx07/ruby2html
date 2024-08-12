# frozen_string_literal: true

module Ruby2html
  module RailsComponents
    class ImageTag < BaseComponent
      def render(&block)
        @render.plain(@context.image_tag(*@args, **@options, &block))
      end
    end
  end
end
