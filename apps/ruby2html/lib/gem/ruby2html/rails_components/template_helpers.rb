# frozen_string_literal: true

require_relative 'output_capture'
require_relative 'base_component'
require_relative 'link_to'
require_relative 'button_to'
require_relative 'image_tag'
require_relative 'form_with'

module Ruby2html
  module RailsComponents
    # Receiver for the Rails helper calls of a compiled .html.rb template
    # (see TemplateCompiler). Routes each helper through its RailsComponents
    # wrapper so the helper's markup lands in the Ruby2html buffer.
    class TemplateHelpers
      include OutputCapture

      COMPONENTS = {
        link_to: LinkTo,
        button_to: ButtonTo,
        image_tag: ImageTag,
        form_with: FormWith
      }.freeze

      def initialize(render, context)
        @render = render
        @context = context
      end

      COMPONENTS.each do |name, component|
        define_method(name) do |*args, **options, &block|
          component.new(@render, @context, name, *args, **options).render(&block)
        end
      end

      # Ruby2html::Component instances write straight into the template's
      # buffer; anything else (partials, ViewComponents, ...) goes through the
      # view's render and is appended. A block is captured from the Ruby2html
      # buffer so its tags end up inside the rendered output.
      def render(*args, **options, &block)
        first = args.first
        if args.size == 1 && options.empty? && first.is_a?(Ruby2html::Component)
          first.render_into(@render.current_output, @context, block)
        else
          @render.plain(@context.render(*args, **options, &capturing(block)))
        end
        nil
      end

      # ActionView's capture only sees the view's output buffer, so a block of
      # Ruby2html tags would be written to the page and capture nothing.
      # Redirect the renderer's buffer instead (same return rule as Rails).
      def capture(*args, &block)
        return @context.capture(*args) unless block

        value = capture_output(*args, &block)
        value.is_a?(String) ? ERB::Util.html_escape(value) : nil
      end

      def content_for(name, content = nil, **options, &block)
        content = capture(&block) if block
        @context.content_for(name, content, **options)
      end

      def provide(name, content = nil, &block)
        content = capture(&block) if block
        @context.provide(name, content)
      end

      # Kept for templates written against the old instance_exec evaluation,
      # where Render's private escape_html was callable. Returns a plain String.
      def escape_html(text)
        ERB::Util.unwrapped_html_escape(text.to_s)
      end
    end
  end
end
