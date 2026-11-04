# frozen_string_literal: true

require_relative 'base_component'

module Ruby2html
  module RailsComponents
    # Delegates to Rails' +form_with+ so the form tag, CSRF token, method
    # spoofing (_method), multipart detection and URL resolution match Rails
    # exactly. The yielded builder is wrapped in a FormBuilderProxy so that
    # calls like +f.text_field :name+ write straight into the Ruby2html output.
    class FormWith < BaseComponent
      private
        def block_arg(arg)
          FormBuilderProxy.wrap(@render, arg)
        end
    end

    # Forwards every call to the wrapped ActionView FormBuilder. Markup results
    # (html_safe strings) are appended to the renderer and +nil+ is returned so
    # a block's return value can't re-emit them; anything else (f.object,
    # f.field_id, ...) is returned unchanged. Builder methods that clash with
    # private Kernel methods (select, format, ...) still reach method_missing.
    class FormBuilderProxy
      include OutputCapture

      def self.wrap(render, arg)
        return arg unless defined?(ActionView::Helpers::FormBuilder) && arg.is_a?(ActionView::Helpers::FormBuilder)

        new(render, arg)
      end

      def initialize(render, builder)
        @render = render
        @builder = builder
      end

      # The underlying ActionView::Helpers::FormBuilder.
      def __builder__
        @builder
      end

      def method_missing(name, ...)
        return super unless @builder.respond_to?(name)

        forward(name, ...)
      end

      def respond_to_missing?(name, include_private = false)
        @builder.respond_to?(name, include_private)
      end

      private
        def forward(name, *args, **options, &block)
          result = @builder.public_send(name, *args, **options, &capturing(block))
          return result unless result.is_a?(String) && result.html_safe?

          @render.plain(result)
          nil
        end

        # Nested builders (fields_for / fields) are wrapped as well.
        def block_arg(arg)
          FormBuilderProxy.wrap(@render, arg)
        end
    end
  end
end
