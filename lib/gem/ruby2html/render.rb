# frozen_string_literal: true

begin
  require 'ruby2html/ruby2html'
rescue LoadError
  puts 'ruby2html not installed'
end

module Ruby2html
  # Global cache for attribute strings (similar to Phlex::ATTRIBUTE_CACHE)
  ATTRIBUTE_CACHE = {}

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

    # Pre-generate all HTML tag methods with Phlex-inspired optimizations
    METHOD_DEFINITIONS = HTML5_TAGS.map do |tag|
      method_name = tag.tr('-', '_')
      is_void = VOID_ELEMENTS.include?(tag)

      if is_void
        # Void elements: optimized with attribute caching
        <<-RUBY
          def #{method_name}(*args, **options)
            buffer = @current_output

            if options.empty?
              buffer << '<#{tag} />'
            else
              # Check attribute cache first
              cached = Ruby2html::ATTRIBUTE_CACHE[options.hash]
              if cached
                buffer << '<#{tag}' << cached << ' />'
              else
                attrs = fast_attributes_to_s(options)
                Ruby2html::ATTRIBUTE_CACHE[options.hash] = attrs.freeze
                buffer << '<#{tag}' << attrs << ' />'
              end
            end
          end
        RUBY
      else
        # Regular elements: optimized paths for ±attrs, ±block, ±content
        <<-RUBY
          def #{method_name}(*args, **options, &block)
            buffer = @current_output
            content = args.first.is_a?(String) ? args.shift : nil

            # Specialized path 1: no attributes, no block, with string content
            if options.empty? && !block && content
              buffer << '<#{tag}>'
              buffer << fast_escape_html(content)
              buffer << '</#{tag}>'
              return
            end

            # Specialized path 2: no attributes, no content, with block
            if options.empty? && block && !content
              buffer << '<#{tag}>'
              prev_output = @current_output
              nested_content = String.new(capacity: 1024)
              @current_output = nested_content
              block_result = block.call
              @current_output = prev_output
              if block_result.is_a?(String)
                buffer << fast_escape_html(block_result)
              else
                buffer << nested_content
              end
              buffer << '</#{tag}>'
              return
            end

            # General path: with attributes (uses cache)
            if options.any?
              cached = Ruby2html::ATTRIBUTE_CACHE[options.hash]
              attrs = cached || begin
                result = fast_attributes_to_s(options)
                Ruby2html::ATTRIBUTE_CACHE[options.hash] = result.freeze
                result
              end
              buffer << '<#{tag}' << attrs << '>'
            else
              buffer << '<#{tag}>'
            end

            # Content handling
            if block
              prev_output = @current_output
              nested_content = String.new(capacity: 1024)
              @current_output = nested_content
              block_result = block.call
              @current_output = prev_output
              if block_result.is_a?(String)
                buffer << fast_escape_html(block_result)
              else
                buffer << nested_content
              end
            elsif content
              buffer << fast_escape_html(content)
            end

            buffer << '</#{tag}>'
          end
        RUBY
      end
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
      # Optimized instance variable copying: only copy once and cache the list
      set_instance_variables if @context && !@__vars_copied

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

      # Optimized instance variable copying - only runs once per renderer instance
      def set_instance_variables
        # Skip internal renderer variables (start with @_ or renderer-specific)
        @context.instance_variables.each do |name|
          # Skip internal variables for performance
          next if name.to_s.start_with?('@_', '@output', '@current_output', '@context', '@root')

          instance_variable_set(name, @context.instance_variable_get(name))
        end

        # Mark that we've copied variables to avoid doing it again
        @__vars_copied = true
      end
  end
end
