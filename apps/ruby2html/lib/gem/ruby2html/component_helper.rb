# frozen_string_literal: true

module Ruby2html
  # Mixed into ViewComponents (or any object) to render with Ruby2html.
  #
  # The active renderer is stored on the component itself (+@__r2h+), never in
  # thread/fiber-global state, so interleaved renders (fiber schedulers,
  # Falcon, async) can't see each other's renderer. Component methods called
  # while rendering (e.g. a helper that emits +div+) reach it through
  # method_missing. +.html.rb+ templates set the same ivar on their view or
  # component (see TemplateHandler).
  #
  # Each render saves the previous value and restores it in +ensure+, so
  # re-entrant +html+ calls and exceptions leave no stale renderer behind.
  # The ivar starts with '@_' so Render does not copy it into itself.
  module ComponentHelper
    def html(&block)
      previous_renderer = @__r2h
      renderer = Ruby2html::Render.new(self, &block)
      @__r2h = renderer
      output = renderer.render
      # Render#render already returns a SafeBuffer under Rails; avoid copying it.
      output.html_safe? ? output : output.html_safe
    ensure
      @__r2h = previous_renderer
    end

    # The renderer currently rendering this object, or nil.
    def __ruby2html_renderer__
      @__r2h
    end

    private
      def method_missing(name, ...)
        renderer = @__r2h
        return super if renderer.nil? || !renderer.respond_to?(name)

        renderer.__send__(name, ...)
      end

      # Only claims the renderer's own methods (tags, plain, component, ...).
      # Asking the renderer's respond_to? here could recurse back into this
      # object, because the renderer delegates respond_to? to its context.
      def respond_to_missing?(name, include_private = false)
        (@__r2h && Ruby2html::Render.method_defined?(name)) || super
      end
  end
end
