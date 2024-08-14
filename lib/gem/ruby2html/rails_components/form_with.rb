# frozen_string_literal: true

module Ruby2html
  module RailsComponents
    class FormWith < BaseComponent
      include ActionView::Helpers::FormHelper
      def render(&block)
        model = @options[:model]
        scope = @options[:scope]
        url = @options[:url]
        method = @options[:method]
        local = @options[:local]

        form_options = @options.except(:model, :scope, :url, :method, :local)
        form_options[:action] = determine_url(model, url)
        form_options[:method] = determine_method(model, method)
        form_options['data-remote'] = 'true' unless local
        @model = model
        @scope = determine_scope(model, scope)

        @render.form(**form_options) do
          authenticity_token_tag
          utf8_enforcer_tag
          block.call(self)
        end
      end

      def label(method, text = nil, options = {})
        @render.label(**options.merge(for: field_id(method))) do
          text || method.to_s.humanize
        end
      end

      def text_field(method, options = {})
        @render.input(**options.merge(type: 'text', name: field_name(method), id: field_id(method), value: object_value_for(method)))
      end

      def hidden_field(method, options = {})
        @render.input(**options.merge(type: 'hidden', name: field_name(method), id: field_id(method), value: object_value_for(method)))
      end

      def password_field(method, options = {})
        @render.input(**options.merge(type: 'password', name: field_name(method), id: field_id(method)))
      end

      def file_field(method, options = {})
        @render.input(**options.merge(type: 'file', name: field_name(method), id: field_id(method)))
      end

      def submit(value = nil, options = {})
        @render.input(**options.merge(type: 'submit', value: value || submit_default_value))
      end

      private
        def determine_url(model, url)
          return url if url
          return polymorphic_path(model) if model && model.respond_to?(:persisted?)
          nil
        end

        def determine_method(model, method)
          return method if method
          return 'post' unless model
          model.respond_to?(:persisted?) && model.persisted? ? 'patch' : 'post'
        end

        def determine_scope(model, scope)
          return scope if scope
          model.model_name.param_key if model.respond_to?(:model_name)
        end

        def authenticity_token_tag
          @render.input(type: 'hidden', name: 'authenticity_token', value: @context.form_authenticity_token)
        end

        def utf8_enforcer_tag
          @render.input(type: 'hidden', name: 'utf8', value: '✓')
        end

        def field_name(method)
          @scope ? "#{@scope}[#{method}]" : method.to_s
        end

        def field_id(method)
          @scope ? "#{@scope}_#{method}" : method.to_s
        end

        def object_value_for(method)
          @model&.public_send(method) if @model
        end
    end
  end
end
