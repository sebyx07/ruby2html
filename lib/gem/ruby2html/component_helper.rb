# frozen_string_literal: true

module Ruby2html
  module ComponentHelper
    def html(context, &block)
      Ruby2html::Render.new(context, &block).render.html_safe
    end
  end
end
