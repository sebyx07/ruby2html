# frozen_string_literal: true

require 'rails_helper'
require_relative 'support/template_rendering'

# Blocks given to `render` from Ruby2html code (.html.rb templates,
# Ruby2html::Component, ComponentHelper#html) follow ActionView's capture
# rule: the block's markup lands inside the rendered output, and a String it
# returns without writing anything is used (escaped) as the content.
RSpec.describe 'render with a block from Ruby2html code' do
  include TemplateRendering

  let(:view) { ApplicationController.new.tap { |c| c.request = ActionDispatch::TestRequest.create }.view_context }

  before do
    stub_const('BoxComponent', Class.new(ViewComponent::Base) { def call = content_tag(:section, content) })
    stub_const('CardComponent', Class.new(Ruby2html::Component) { def view_template = div(class: 'card') { content } })
    stub_const('LinkCardComponent', Class.new(Ruby2html::Component) { def view_template = link_to('/x') { content } })
  end

  context 'with a ViewComponent' do
    it 'captures the block from a Ruby2html::Component' do
      stub_const('OuterComponent', Class.new(Ruby2html::Component) { def view_template = div { render(BoxComponent.new) { b 'in' } } })
      expect(view.render(OuterComponent.new)).to eq('<div><section><b>in</b></section></div>')
    end

    it 'captures the block from a ComponentHelper#html block' do
      stub_const('OuterComponent', Class.new(ApplicationComponent) { def call = html { div { render(BoxComponent.new) { b 'in' } } } })
      expect(view.render(OuterComponent.new)).to eq('<div><section><b>in</b></section></div>')
    end

    it 'captures the block from an .html.rb template' do
      expect(render_source("div { render(BoxComponent.new) { b 'in' } }")).to eq('<div><section><b>in</b></section></div>')
    end
  end

  context 'with a Ruby2html::Component' do
    it 'uses a returned String as escaped content in an .html.rb template' do
      expect(render_source("render(CardComponent.new) { '<i>' }")).to eq('<div class="card">&lt;i&gt;</div>')
    end

    it 'uses a returned String as escaped content in a parent component' do
      stub_const('ParentComponent', Class.new(Ruby2html::Component) { def view_template = render(CardComponent.new) { '<i>' } })
      expect(view.render(ParentComponent.new)).to eq('<div class="card">&lt;i&gt;</div>')
    end

    it 'writes the block inside the component from a ComponentHelper#html block' do
      stub_const('OuterComponent', Class.new(ApplicationComponent) { def call = html { div { render(CardComponent.new) { b 'in' } } } })
      expect(view.render(OuterComponent.new)).to eq('<div><div class="card"><b>in</b></div></div>')
    end

    it 'yields the component to the block, as render_in does from ERB' do
      expect(render_source('render(CardComponent.new) { |card| plain card.class.name }')).to eq('<div class="card">CardComponent</div>')
    end

    it 'emits content where the component asks for it, inside its own captured helpers' do
      expect(render_source("render(LinkCardComponent.new) { em 'in' }")).to eq('<a href="/x"><em>in</em></a>')
      stub_const('ParentComponent', Class.new(Ruby2html::Component) { def view_template = render(LinkCardComponent.new) { em 'in' } })
      expect(view.render(ParentComponent.new)).to eq('<a href="/x"><em>in</em></a>')
    end
  end
end
