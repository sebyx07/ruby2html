# frozen_string_literal: true

module Ruby2html
  module RailsComponents
    class LinkTo < BaseComponent
      include ActionView::Helpers::UrlHelper
      def render(&block)
        name = @args[0]
        options = @args[1]
        html_options = @args[2] || {}

        html_options = convert_options_to_data_attributes(options, html_options)
        url = url_target(name, options)
        html_options['href'] ||= url

        @render.a(**html_options) do
          if block_given?
            @render.instance_exec(&block)
          else
            name || url
          end
        end
      end
    end
  end
end
