# frozen_string_literal: true

require_relative 'render/pure_ruby'

module Ruby2html
  # Loads the C extension (Ruby2html::Native). Without it (JRuby, a failed
  # build, or RUBY2HTML_DISABLE_EXT=1) the pure-Ruby twin is used instead.
  # Installed gems find the extension on the load path; this repo builds it
  # into lib/ruby2html.
  def self.load_native_extension
    return false if ENV['RUBY2HTML_DISABLE_EXT'] == '1'

    begin
      require 'ruby2html/ruby2html'
    rescue LoadError
      require_relative '../../ruby2html/ruby2html'
    end
    defined?(Native) ? true : false
  rescue LoadError
    false
  end
  private_class_method :load_native_extension

  # The module providing tag methods, #plain and #component: Native or PureRuby.
  IMPLEMENTATION = load_native_extension ? Native : PureRuby

  def self.native?
    IMPLEMENTATION != PureRuby
  end

  def self.escape_html(obj)
    IMPLEMENTATION.escape_html(obj)
  end

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
    # Rails helpers that write their markup into the ruby2html buffer, mapped
    # to their RailsComponents wrapper (shared by Render and Component).
    RAILS_HELPER_COMPONENTS = { link_to: :LinkTo, button_to: :ButtonTo, image_tag: :ImageTag, form_with: :FormWith }.freeze
    # Context ivars that would clobber the renderer's own state if copied.
    SKIPPED_IVAR_PREFIXES = %w[@_ @output @current_output @context @root].freeze

    # Both implementations get the tags so specs can compare them in one process.
    [PureRuby, IMPLEMENTATION].uniq.each do |implementation|
      HTML5_TAGS.each { |tag| implementation.define_tag(tag.tr('-', '_'), tag, VOID_ELEMENTS.include?(tag)) }
    end

    include IMPLEMENTATION

    # No `output` reader: it would shadow the <output> tag method.
    attr_accessor :current_output

    def initialize(context = nil, &root)
      @context = context
      @root = root
      @output = String.new(capacity: 4096, encoding: Encoding::UTF_8)
      @current_output = @output
    end

    # Without arguments renders the root block and returns the HTML (a
    # SafeBuffer under ActiveSupport). With arguments it is the context's
    # render (partials, components), appended to the output.
    def render(*args, **options, &block)
      copy_instance_variables if @context && !@__vars_copied

      return plain @context.render(*args, **options, &block) if !args.empty? || !options.empty? || block

      instance_exec(&@root)
      defined?(ActiveSupport::SafeBuffer) ? ActiveSupport::SafeBuffer.new(@output) : @output
    end

    private
      def method_missing(method_name, ...)
        if @context.respond_to?(method_name)
          @context.send(method_name, ...)
        else
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        @context.respond_to?(method_name) || super
      end

      # Resolved per call (const_get with a Symbol; autoloaded on first use).
      RAILS_HELPER_COMPONENTS.each do |method, component_name|
        define_method(method) do |*args, **options, &block|
          RailsComponents.const_get(component_name).new(self, @context, method, *args, **options).render(&block)
        end
      end if defined?(ActionView)

      def escape_html(text)
        IMPLEMENTATION.escape_html(text)
      end

      # Templates read the view's assigns (@users, ...) as their own ivars.
      def copy_instance_variables
        @context.instance_variables.each do |name|
          next if name.start_with?(*SKIPPED_IVAR_PREFIXES)

          instance_variable_set(name, @context.instance_variable_get(name))
        end
        @__vars_copied = true
      end
  end
end
