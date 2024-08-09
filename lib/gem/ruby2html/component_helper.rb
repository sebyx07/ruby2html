# frozen_string_literal: true

module Ruby2html
  module ComponentHelper
    def html(&block)
      previous_renderer = __ruby2html_renderer__
      Ruby2html::Render.new(self, &block).yield_self do |component_renderer|
        Thread.current[:__ruby2html_renderer__] = component_renderer
        component_renderer.render.html_safe
      end
    ensure
      Thread.current[:__ruby2html_renderer__] = previous_renderer
    end

    def method_missing(method, *args, **options, &block)
      if __ruby2html_renderer__.respond_to?(method)
        __ruby2html_renderer__.send(method, *args, **options, &block)
      else
        super
      end
    end

    def __ruby2html_renderer__
      Thread.current[:__ruby2html_renderer__]
    end
  end
end
