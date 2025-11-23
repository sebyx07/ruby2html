# frozen_string_literal: true

begin
  require 'ruby2html/ruby2html'
rescue LoadError
  puts 'ruby2html not installed'
end

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

    # Pre-generate all HTML tag methods as a single string
    METHOD_DEFINITIONS = HTML5_TAGS.map do |tag|
      method_name = tag.tr('-', '_')
      is_void = VOID_ELEMENTS.include?(tag)
      <<-RUBY
        def #{method_name}(*args, **options, &block)
          content = args.first.is_a?(String) ? args.shift : nil
          escape_content = !content.nil?

          # Handle block execution to get nested content
          #{unless is_void
              <<-BLOCK_LOGIC
                if block
                  prev_output = @current_output
                  nested_content = String.new(capacity: 1024)
                  @current_output = nested_content
                  block_result = block.call
                  @current_output = prev_output
                  if block_result.is_a?(String)
                    content = block_result
                    escape_content = true
                  else
                    content = nested_content
                    escape_content = false
                  end
                end
              BLOCK_LOGIC
            end}

          # Use fast C function to render complete tag
          tag_html = fast_render_tag('#{tag}', options, content, #{is_void}, escape_content)
          fast_buffer_append(@current_output, tag_html)
        end
      RUBY
    end.join("\n")

    # Evaluate all method definitions at once
    class_eval(METHOD_DEFINITIONS, __FILE__, __LINE__ + 1)

    attr_reader :output
    attr_accessor :current_output

    def initialize(context = nil, &root)
      @context = context
      @root = root
      @output = String.new(capacity: 4096)
      @current_output = @output
    end

    def __render_from_rails(template_path)
      result = render
      return result unless annotate_rendered_view_with_filenames?

      template_path = template_path.sub("#{Rails.root}/", '')
      comment_start = "<!-- BEGIN #{template_path} -->"
      comment_end = "<!-- END #{template_path} -->"

      final_result = String.new(capacity: result.length + comment_start.length + comment_end.length)
      final_result << comment_start
      final_result << result
      final_result << comment_end
      final_result.html_safe
    end if defined?(ActionView)

    def render(*args, **options, &block)
      set_instance_variables

      return plain @context.render(*args, **options, &block) if !args.empty? || !options.empty? || block_given?

      instance_exec(&@root)
      result = @output
      result = ActiveSupport::SafeBuffer.new(result) if defined?(ActiveSupport)
      result
    end

    def respond_to?(method_name, include_private = false)
      HTML5_TAGS.include?(method_name.to_s.tr('_', '-')) || super
    end

    def plain(text)
      if defined?(ActiveSupport) && (text.is_a?(ActiveSupport::SafeBuffer) || text.html_safe?)
        fast_buffer_append(@current_output, text)
      else
        fast_buffer_append(@current_output, fast_escape_html(text.to_s))
      end
    end

    def component(component_output)
      fast_buffer_append(@current_output, component_output)
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

      def escape_html(text)
        fast_escape_html(text.to_s)
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
