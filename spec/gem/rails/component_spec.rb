# frozen_string_literal: true

require 'rails_helper'
require_relative 'support/template_rendering'

RSpec.describe Ruby2html::Component do
  include TemplateRendering

  let(:card) do
    Class.new(described_class) do
      def initialize(title:)
        @title = title
      end

      def view_template
        div class: 'card' do
          h2 @title
          content
          link_to 'More', helpers.url_for('/more')
        end
      end
    end
  end

  let(:view) { ApplicationController.new.tap { |c| c.request = ActionDispatch::TestRequest.create }.view_context }

  before { stub_const('CardComponent', card) }

  it 'renders via render_in with escaping and helpers' do
    html = view.render(CardComponent.new(title: '<x>'))
    expect(html).to eq('<div class="card"><h2>&lt;x&gt;</h2><a href="/more">More</a></div>')
    expect(html).to be_html_safe
  end

  it 'captures a block given from ERB as content' do
    html = ApplicationController.render(inline: '<%= render(CardComponent.new(title: "T")) do %><b>hi</b><% end %>')
    expect(html).to eq('<div class="card"><h2>T</h2><b>hi</b><a href="/more">More</a></div>')
  end

  it 'renders nested components into the parent buffer without intermediate strings' do
    stub_const('ListComponent', Class.new(described_class) do
      def view_template
        ul { 3.times { |i| render(CardComponent.new(title: i.to_s)) { span 'c' } } }
      end
    end)
    html = view.render(ListComponent.new)
    expect(html).to eq("<ul>#{(0..2).map { |i| %(<div class="card"><h2>#{i}</h2><span>c</span><a href="/more">More</a></div>) }.join}</ul>")
  end

  it 'never builds a String for nested components' do
    child = CardComponent.new(title: 'x')
    expect(child).not_to receive(:render_in)
    parent = stub_const('ParentComponent', Class.new(described_class) do
      define_method(:view_template) { render child }
    end)
    view.render(parent.new)
  end

  it 'is written straight into .html.rb template buffers' do
    html = render_source("div do\n  render CardComponent.new(title: 'T') do\n    em 'inner'\n  end\nend")
    expect(html).to eq('<div><div class="card"><h2>T</h2><em>inner</em><a href="/more">More</a></div></div>')
  end

  it 'renders ViewComponents and partials through the view context' do
    stub_const('WrapperComponent', Class.new(described_class) do
      def view_template
        section { render ThirdComponent.new }
      end
    end)
    expect(view.render(WrapperComponent.new)).to eq('<section><h1>Third component</h1><div>Item value: Hello, World!</div></section>')
  end

  it 'supports #call and an overridden #template as the entry point' do
    via_call = stub_const('ViaCallComponent', Class.new(described_class) { def call = p('call') })
    via_template = stub_const('ViaTemplateComponent', Class.new(described_class) { def template = p('template') })
    expect(view.render(via_call.new)).to eq('<p>call</p>')
    expect(view.render(via_template.new)).to eq('<p>template</p>')
  end

  it 'raises a clear error without an entry point, and helpers outside a render' do
    stub_const('EmptyComponent', Class.new(described_class))
    expect { view.render(EmptyComponent.new) }.to raise_error(NotImplementedError, /view_template/)
    expect { CardComponent.new(title: 'x').helpers }.to raise_error(Ruby2html::Error)
  end

  it 'restores its state when the template raises, so it can be rendered again' do
    flaky = stub_const('FlakyComponent', Class.new(described_class) do
      attr_accessor :fail

      def view_template
        h1 'ok'
        raise 'boom' if fail
      end
    end).new
    flaky.fail = true
    expect { view.render(flaky) }.to raise_error('boom')
    expect(flaky.current_output).to be_nil
    flaky.fail = false
    expect(view.render(flaky)).to eq('<h1>ok</h1>')
  end

  it 'renders two components interleaved in fibers without crosstalk' do
    yielding = stub_const('YieldingComponent', Class.new(described_class) do
      def initialize(name) = @name = name

      def view_template
        h1 @name
        Fiber.yield
        p @name
      end
    end)
    fibers = %w[a b].map { |name| Fiber.new { view.render(yielding.new(name)) } }
    fibers.each(&:resume)
    expect(fibers.reverse.map(&:resume)).to eq(['<h1>b</h1><p>b</p>', '<h1>a</h1><p>a</p>'])
  end
end
