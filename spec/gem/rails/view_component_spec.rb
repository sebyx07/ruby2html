# frozen_string_literal: true

require 'rails_helper'

# Ruby2html::ComponentHelper inside ViewComponent (3.x and 4.x).
RSpec.describe 'ViewComponent integration' do
  let(:view) { ApplicationController.new.tap { |c| c.request = ActionDispatch::TestRequest.create }.view_context }

  before do
    stub_const('PanelComponent', Class.new(ApplicationComponent) do
      renders_one :heading # not `header`: tag names win inside html blocks
      renders_many :items

      def call
        html do
          section class: 'panel' do
            div(class: 'header') { plain heading } if heading?
            ul { items.each { |item| li { plain item } } }
            div(class: 'body') { plain content }
            a 'Home', href: helpers.root_path
          end
        end
      end
    end)
  end

  it 'renders slots, content and helpers from an html block' do
    html = view.render(PanelComponent.new) do |panel|
      panel.with_heading { '<b>Head</b>'.html_safe }
      panel.with_item { 'one' }
      panel.with_item { '<two>' }
      'body text'
    end
    expect(html).to eq(
      '<section class="panel"><div class="header"><b>Head</b></div>' \
      '<ul><li>one</li><li>&lt;two&gt;</li></ul><div class="body">body text</div><a href="/">Home</a></section>'
    )
  end

  it 'renders a sidecar .html.rb template with component ivars and methods' do
    expect(view.render(FirstComponent.new)).to include('<div>Item value: Hello, World!</div><div class="another">')
  end

  it 'nests ViewComponents inside an html block' do
    stub_const('OuterComponent', Class.new(ApplicationComponent) do
      def call
        html { div { render ThirdComponent.new } }
      end
    end)
    expect(view.render(OuterComponent.new)).to eq('<div><h1>Third component</h1><div>Item value: Hello, World!</div></div>')
  end
end
