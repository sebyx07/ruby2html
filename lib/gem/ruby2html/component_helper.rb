# frozen_string_literal: true

module Ruby2html
  module ComponentHelper
    def html(&block)
      Ruby2html::Render.new(self, &block).render.html_safe
    end
  end
end
