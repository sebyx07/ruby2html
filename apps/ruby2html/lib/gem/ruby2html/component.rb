# frozen_string_literal: true

require_relative 'render'

module Ruby2html
  # Lightweight component without ViewComponent:
  #
  #   class CardComponent < Ruby2html::Component
  #     def initialize(title:) = @title = title
  #
  #     def view_template
  #       div class: 'card' do
  #         h2 @title
  #         content            # block given to render, if any
  #         link_to 'More', helpers.root_path
  #       end
  #     end
  #   end
  #
  #   render CardComponent.new(title: 'Hi')   # ERB, controllers, .html.rb
  #
  # Why it is fast: the tag methods are mixed straight into the component and
  # write into a buffer it is handed, so templates run with +self+ = the
  # component (own ivars, no copying, no instance_exec, no method_missing).
  # Nested in another Ruby2html component or .html.rb template it writes into
  # the parent's buffer directly; only the outermost render allocates one.
  #
  # Define +view_template+ (or +call+). +template+ is accepted when a subclass
  # overrides it, but shadows the <template> tag for that component.
  class Component
    include Ruby2html::IMPLEMENTATION

    INITIAL_CAPACITY = 1024

    # Rails helpers whose markup must land in the component's buffer. The
    # component itself is the RailsComponents "renderer" (it has #plain and
    # #current_output). Constants are resolved lazily: they need ActionView.
    Render::RAILS_HELPER_COMPONENTS.each do |name, klass|
      define_method(name) do |*args, **options, &block|
        RailsComponents.const_get(klass).new(self, helpers, name, *args, **options).render(&block)
      end
    end

    class << self
      # Entry method, resolved once per class.
      def __r2h_entry
        @__r2h_entry ||=
          if method_defined?(:view_template) then :view_template
          elsif method_defined?(:call) then :call
          elsif instance_method(:template).owner != Ruby2html::IMPLEMENTATION then :template
          else raise NotImplementedError, "#{name} must define #view_template (or #call)"
          end
      end

      # Last output size, so the next top-level render pre-sizes its buffer.
      # A benign race between threads only affects the capacity hint.
      attr_writer :__r2h_capacity

      def __r2h_capacity
        @__r2h_capacity || INITIAL_CAPACITY
      end
    end

    # The buffer currently written to (RailsComponents swap it to capture blocks).
    attr_accessor :current_output

    # Rails' entry point: `render component` in views and controllers. Rails 8.2+ passes
    # `locals:` (render_in without options is deprecated there); a component takes its data
    # through #initialize, so options are accepted and ignored.
    def render_in(view_context, **_options, &block)
      buffer = String.new(capacity: self.class.__r2h_capacity, encoding: Encoding::UTF_8)
      content = block && -> { plain(view_context.capture(self, &block)) }
      render_into(buffer, view_context, content)
      self.class.__r2h_capacity = buffer.bytesize if buffer.bytesize > self.class.__r2h_capacity
      defined?(ActiveSupport::SafeBuffer) ? ActiveSupport::SafeBuffer.new(buffer) : buffer
    end

    # Writes the component into +buffer+ (a parent's output) and returns nil.
    # +content+ is a callable run by #content. Re-entrant: state is restored.
    def render_into(buffer, view_context, content = nil)
      previous_output = @current_output
      previous_helpers = @__r2h_helpers
      previous_content = @__r2h_content
      @current_output = buffer
      @__r2h_helpers = view_context
      @__r2h_content = content
      __send__(self.class.__r2h_entry)
      nil
    ensure
      @current_output = previous_output
      @__r2h_helpers = previous_helpers
      @__r2h_content = previous_content
    end

    # The view context (Rails helpers, routes, request, ...).
    def helpers
      return @__r2h_helpers if @__r2h_helpers

      raise Ruby2html::Error, "#{self.class.name}#helpers is only available while rendering"
    end

    # Emits the block given to render (see #render_in / #render).
    def content
      @__r2h_content&.call
      nil
    end

    # Renders another component into this buffer, or anything Rails can
    # render (partials, ViewComponents) via the view context.
    def render(*args, **options, &block)
      first = args.first
      if args.size == 1 && options.empty? && first.is_a?(Component)
        first.render_into(@current_output, helpers, block)
      else
        plain(helpers.render(*args, **options, &block))
      end
      nil
    end
  end
end
