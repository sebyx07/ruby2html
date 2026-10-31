# frozen_string_literal: true

module Ruby2html
  # Include in a controller to get +html(self) { ... }+ inside ERB/other views.
  module RailsHelper
    def self.included(base)
      # Only controllers can expose helpers to views; plain modules just get +html+.
      base.helper_method :html if base.respond_to?(:helper_method)
    end

    def html(context, &block)
      output = Ruby2html::Render.new(context, &block).render
      # Render#render already returns a SafeBuffer under Rails; avoid copying it.
      output.html_safe? ? output : output.html_safe
    end
  end
end
