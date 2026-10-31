# frozen_string_literal: true

# Loaded by TemplateCompiler.available? after Prism (Prism::Visitor must exist).
module Ruby2html
  module RailsComponents
    class TemplateCompiler
      # Walks the AST collecting insertions. Method/class bodies are skipped:
      # the renderer local isn't visible there.
      class Collector < Prism::Visitor
        attr_reader :edits, :uses_helpers

        def initialize(renderer_methods)
          super()
          @renderer_methods = renderer_methods
          @edits = []
          @uses_helpers = false
        end

        def visit_call_node(node)
          rewrite(node) if node.receiver.nil?
          return super unless own_renderer_block?(node)

          # The block belongs to a fresh renderer (e.g. Ruby2html::Render.new
          # { p 'x' }) and is instance_exec'd on it, so its receiverless calls
          # must stay receiverless. Visit everything except the block body.
          node.receiver&.accept(self)
          node.arguments&.accept(self)
        end

        def visit_def_node(_node); end
        def visit_class_node(_node); end
        def visit_module_node(_node); end
        def visit_singleton_class_node(_node); end

        private
          # `Render.new { ... }` / `Ruby2html::Render.new { ... }`
          def own_renderer_block?(node)
            return false unless node.name == :new && node.block.is_a?(Prism::BlockNode)

            receiver = node.receiver
            case receiver
            when Prism::ConstantReadNode then receiver.name == :Render
            when Prism::ConstantPathNode then receiver.name == :Render
            else false
            end
          end

          def rewrite(node)
            name = node.name
            return unless node.message_loc

            if @renderer_methods.include?(name)
              @edits << [node.message_loc.start_offset, TemplateCompiler::RENDERER_PREFIX]
            elsif TemplateCompiler.helper_methods.include?(name)
              @edits << [node.message_loc.start_offset, TemplateCompiler::HELPERS_PREFIX]
              @uses_helpers = true
            end
          end
      end
    end
  end
end
