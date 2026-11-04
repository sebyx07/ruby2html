# frozen_string_literal: true

module Ruby2html
  module RailsComponents
    # Bridges Ruby2html blocks and Rails helpers that take a block.
    #
    # Rails helpers (link_to, button_to, form_with, FormBuilder#label, ...) run
    # their block through ActionView's +capture+, which only sees the view's
    # output buffer. Ruby2html tag methods write into the renderer's buffer
    # instead, so without this bridge nested tags would leak out *before* the
    # helper's markup. Including classes must set +@render+.
    module OutputCapture
      private
        # Wraps +block+ in a proc for a Rails helper. The proc redirects the
        # renderer's output into a scratch buffer while the block runs and
        # returns that markup as html_safe. +block_arg+ lets subclasses swap
        # yielded objects (e.g. wrap a FormBuilder) before the user sees them.
        def capturing(block)
          return unless block

          proc { |*yielded| capture_output(*yielded.map! { |arg| block_arg(arg) }, &block) }
        end

        def capture_output(*args)
          previous = @render.current_output
          buffer = String.new(capacity: 256)
          @render.current_output = buffer
          value = yield(*args)
          # Same rule as ActionView's capture: markup written to the buffer wins,
          # otherwise the block's return value is used (Rails escapes it if unsafe).
          buffer.empty? ? value : buffer.html_safe
        ensure
          @render.current_output = previous
        end

        def block_arg(arg)
          arg
        end
    end
  end
end
