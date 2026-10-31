# frozen_string_literal: true

require 'set'

module Ruby2html
  module RailsComponents
    # Compile-time rewrite of a .html.rb template.
    #
    # Instead of instance_exec'ing the template on a Render (which forces the
    # renderer to copy every view instance variable on each render and to
    # route every helper call through method_missing), the template runs
    # directly in the view/component. Prism finds the receiverless calls that
    # belong to Ruby2html and gives them an explicit receiver:
    #
    #   div class: 'x' do       =>  __r2h_renderer.div class: 'x' do
    #   link_to 'Home', '/'     =>  __r2h_helpers.link_to 'Home', '/'
    #   render partial: 'nav'   =>  __r2h_helpers.render partial: 'nav'
    #
    # Only text is inserted, never newlines, so line numbers are unchanged.
    class TemplateCompiler
      RENDERER = '__r2h_renderer'
      HELPERS = '__r2h_helpers'
      RENDERER_PREFIX = "#{RENDERER}."
      HELPERS_PREFIX = "#{HELPERS}."

      def self.helper_methods
        @helper_methods ||= TemplateHelpers.public_instance_methods(false).to_set.freeze
      end

      Result = Struct.new(:source, :uses_helpers)

      class << self
        # Prism is only loaded when the first template is compiled. Without it
        # (Ruby < 3.3 and no prism gem) TemplateHandler falls back to the
        # closure strategy (template block instance_exec'd on the renderer).
        def available?
          return @available if defined?(@available)

          @available = begin
            require 'prism'
            require_relative 'template_collector'
            true
          rescue LoadError
            false
          end
        end

        # Returns a Result, or nil when the source can't be parsed (the caller
        # then compiles it unchanged so Ruby reports the syntax error).
        # +locals+: the template's local names (partial locals, `locals:`).
        # Prism must know them, or `h2 title` would parse `title` as a call
        # and be rewritten into a <title> tag.
        def compile(source, locals = [])
          return unless available?

          parsed = locals.empty? ? Prism.parse(source) : Prism.parse(source, scopes: [locals.map(&:to_sym)])
          return unless parsed.success?

          collector = Collector.new(renderer_methods)
          parsed.value.accept(collector)
          Result.new(apply(source, collector.edits), collector.uses_helpers)
        end

        # Ruby2html methods a template may call without a receiver: every
        # tag method plus plain/component. Resolved lazily (and memoized) so
        # it reflects Render after it has been fully loaded.
        def renderer_methods
          @renderer_methods ||= begin
            tags = Ruby2html::Render::HTML5_TAGS.map { |tag| tag.tr('-', '_').to_sym }
            (tags + %i[plain component]).select { |name| Ruby2html::Render.public_method_defined?(name) }.to_set.freeze
          end
        end

        private
          # Edits are [byte_offset, text] insertions; Prism offsets are bytes.
          def apply(source, edits)
            return source if edits.empty?

            bytes = source.b
            out = String.new(capacity: bytes.bytesize + (edits.size * 16), encoding: Encoding::BINARY)
            cursor = 0
            edits.sort_by!.with_index { |(offset, _), index| [offset, index] }.each do |offset, text|
              out << bytes.byteslice(cursor, offset - cursor) << text
              cursor = offset
            end
            out << bytes.byteslice(cursor, bytes.bytesize - cursor)
            out.force_encoding(source.encoding)
          end
      end
    end
  end
end
