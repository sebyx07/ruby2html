# frozen_string_literal: true

module Ruby2html
  class Render
    HTML5_TAGS = %w[
      a abbr address area article aside audio b base bdi bdo blockquote body br button canvas caption
      cite code col colgroup data datalist dd del details dfn dialog div dl dt em embed fieldset
      figcaption figure footer form h1 h2 h3 h4 h5 h6 head header hr html i iframe img input ins
      kbd label legend li link main map mark meta meter nav noscript object ol optgroup option
      output p param picture pre progress q rp rt ruby s samp script section select small source
      span strong style sub summary sup table tbody td template textarea tfoot th thead time title
      tr track u ul var video wbr turbo-frame turbo-stream
    ].freeze

    VOID_ELEMENTS = %w[area base br col embed hr img input link meta param source track wbr].freeze

    COMMON_RAILS_METHOD_HELPERS = %w[link_to image_tag form_with button_to].freeze

    attr_reader :output
    attr_accessor :current_output

    def initialize(context = nil, &root)
      @context = context
      @root = root
      @output = StringIO.new
      @current_output = @output
    end

    def __render_from_rails(template_path)
      result = render
      return result unless annotate_rendered_view_with_filenames?

      template_path = template_path.sub("#{Rails.root}/", '')

      "<!-- BEGIN #{template_path} -->#{result}<!-- END #{template_path} -->".html_safe
    end if defined?(ActionView)

    def render(*args, **options, &block)
      set_instance_variables

      return plain @context.render(*args, **options, &block)  if !args.empty? || !options.empty? || block_given?

      instance_exec(&@root)
      result = @output.string

      result = ActiveSupport::SafeBuffer.new(result) if defined?(ActiveSupport)

      result
    end

    HTML5_TAGS.each do |tag|
      define_method(tag.tr('-', '_')) do |*args, **options, &block|
        html!(tag, *args, **options, &block)
      end
    end

    def respond_to?(method_name, include_private = false)
      HTML5_TAGS.include?(method_name) || super
    end

    def html!(name, *args, **options)
      content = args.first.is_a?(String) ? args.shift : nil
      attributes = options

      tag_content = StringIO.new
      tag_content << "<#{name}"
      tag_content << attributes_to_s(attributes)

      if VOID_ELEMENTS.include?(name)
        tag_content << ' />'
      else
        tag_content << '>'

        if block_given?
          prev_output = @current_output
          nested_content = StringIO.new
          @current_output = nested_content
          block_result = yield
          @current_output = prev_output
          tag_content << (block_result.is_a?(String) ? escape_html(block_result) : nested_content.string)
        elsif content
          tag_content << escape_html(content)
        end

        tag_content << "</#{name}>"
      end

      @current_output << tag_content.string
    end

    def plain(text)
      if defined?(ActiveSupport) && (text.is_a?(ActiveSupport::SafeBuffer) || text.html_safe?)
        @current_output << text
      else
        @current_output << escape_html(text.to_s)
      end
    end

    def component(component_output)
      @current_output << component_output
    end

    private
      def method_missing(method_name, *args, **options, &block)
        if @context.respond_to?(method_name)
          @context.send(method_name, *args, **options, &block)
        else
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        @context.respond_to?(method_name) || super
      end

      COMMON_RAILS_METHOD_HELPERS.each do |method|
        define_method(method) do |*args, **options, &block|
          constant = "Ruby2html::RailsComponents::#{method.to_s.camelize}".constantize
          constant.new(self, @context, method, *args, **options).render(&block)
        end
      end if defined?(ActionView)

      def attributes_to_s(attributes)
        return '' if attributes.empty?

        result = StringIO.new
        attributes.compact.each do |k, v|
          result << " #{k}=\"#{escape_html(v)}\""
        end
        result.string
      end

      def escape_html(text)
        CGI.escapeHTML(text.to_s)
      end

      def annotate_rendered_view_with_filenames?
        return @annotate_rendered_view_with_filenames if defined?(@annotate_rendered_view_with_filenames)
        @annotate_rendered_view_with_filenames = Rails.application.config.action_view.annotate_rendered_view_with_filenames
      end

      def set_instance_variables
        @context.instance_variables.each do |name|
          instance_variable_set(name, @context.instance_variable_get(name))
        end
      end
  end
end
