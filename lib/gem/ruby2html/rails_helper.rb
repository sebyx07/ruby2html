# frozen_string_literal: true

module Ruby2html
  module RailsHelper
    def html(context, &block)
      Ruby2html::Render.new(context, &block).render.html_safe
    end

    def self.included(base)
      base.helper_method :html
    end
  end
end
