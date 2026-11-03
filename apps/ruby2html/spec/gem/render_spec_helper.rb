# frozen_string_literal: true

# Inside the demo app's bundle, boot Rails like the other specs. Under
# gemfiles/standalone.gemfile (JRuby/TruffleRuby/Ruby matrix CI) there is no
# Rails: load the gem plus ActiveSupport's SafeBuffer only.
if Gem.loaded_specs.key?('rails')
  require 'rails_helper'
else
  require 'active_support'
  require 'active_support/core_ext/string/output_safety'
  require 'ruby2html'
end

# Runs render specs against every available implementation: the C extension
# (Ruby2html::Render itself, unless RUBY2HTML_DISABLE_EXT=1) and the
# pure-Ruby fallback, mixed into a Render subclass so both can be compared in
# one process.
module RenderSpecHelper
  PURE_RENDER = Class.new(Ruby2html::Render) { include Ruby2html::PureRuby }

  def self.implementations
    { 'native' => (Ruby2html::Render if Ruby2html.native?), 'pure Ruby' => PURE_RENDER }.compact
  end

  # Defines one example group per implementation; `renderer_class` is set.
  def self.describe_each(description, &block)
    implementations.each do |name, renderer_class|
      RSpec.describe("#{description} (#{name})") do
        include RenderSpecHelper

        let(:renderer_class) { renderer_class }

        class_exec(&block)
      end
    end
  end

  def render_html(context = nil, &block)
    renderer_class.new(context, &block).render
  end
end
