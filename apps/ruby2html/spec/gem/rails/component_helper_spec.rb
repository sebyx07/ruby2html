# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ruby2html::ComponentHelper do
  let(:component_class) do
    Class.new do
      include Ruby2html::ComponentHelper

      def initialize(child = nil)
        @child = child
      end

      def heading_text
        'Title'
      end

      def subtitle
        h2 'emitted via method_missing'
      end

      def build(&block)
        html(&block)
      end
    end
  end

  it 'renders the block and returns an html_safe string' do
    output = component_class.new.build { h1 heading_text }
    expect(output).to eq('<h1>Title</h1>')
    expect(output).to be_html_safe
  end

  it 'delegates tag calls from component methods to the active renderer' do
    output = component_class.new.build { subtitle }
    expect(output).to eq('<h2>emitted via method_missing</h2>')
  end

  it 'nests components three levels deep and clears every renderer afterwards' do
    leaf = component_class.new
    middle = component_class.new(leaf)
    root = component_class.new(middle)
    output = root.build do
      div do
        component(@child.build do
          section { component(@child.build { span 'leaf' }) }
          subtitle
        end)
      end
      p 'after'
    end
    expect(output).to eq('<div><section><span>leaf</span></section><h2>emitted via method_missing</h2></div><p>after</p>')
    expect([root, middle, leaf].map(&:__ruby2html_renderer__)).to all(be_nil)
  end

  it 'supports re-entrant html calls on the same component' do
    component = component_class.new
    output = component.build do
      div { component(component.build { span 'inner' }) }
      subtitle # must reach the outer renderer again
    end
    expect(output).to eq('<div><span>inner</span></div><h2>emitted via method_missing</h2>')
  end

  it 'leaves no stale renderer when a nested render raises' do
    inner = component_class.new
    outer = component_class.new(inner)
    output = outer.build do
      begin
        @child.build { raise 'boom' }
      rescue RuntimeError
        nil
      end
      subtitle
    end
    expect(output).to eq('<h2>emitted via method_missing</h2>')
    expect([outer.__ruby2html_renderer__, inner.__ruby2html_renderer__]).to eq([nil, nil])
  end

  it 'keeps interleaved renders in two fibers isolated' do
    log = []
    fibers = %w[a b].map do |name|
      Fiber.new do
        component_class.new.build do
          h1 name
          Fiber.yield
          subtitle # resolved via the component's own renderer, not ambient state
          plain name
        end
      end
    end
    fibers.each(&:resume) # both renders are now suspended mid-block
    results = fibers.reverse.map(&:resume)
    log.concat(results)
    expect(log).to eq(['<h1>b</h1><h2>emitted via method_missing</h2>b', '<h1>a</h1><h2>emitted via method_missing</h2>a'])
  end

  it 'pairs method_missing with respond_to_missing?' do
    component = component_class.new
    expect(component.respond_to?(:div)).to be(false)
    answers = []
    component.build { answers << component.respond_to?(:div) << component.respond_to?(:no_such_method) }
    expect(answers).to eq([true, false])
  end

  it 'raises NoMethodError for unknown methods, with or without a renderer' do
    component = component_class.new
    expect { component.no_such_method }.to raise_error(NoMethodError)
    expect { component.build { component.no_such_method } }.to raise_error(NoMethodError)
  end
end

RSpec.describe Ruby2html::RailsHelper do
  it 'returns html_safe output without copying the SafeBuffer' do
    helper = Class.new { include Ruby2html::RailsHelper }.new
    output = helper.html(nil) { div 'x' }
    expect(output).to eq('<div>x</div>')
    expect(output).to be_html_safe
  end

  it 'can be included in classes without helper_method' do
    expect { Module.new { include Ruby2html::RailsHelper } }.not_to raise_error
  end
end
