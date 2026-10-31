# frozen_string_literal: true

require 'rails_helper'
require_relative 'support/template_rendering'

RSpec.describe 'Capturing inside .html.rb templates' do
  include TemplateRendering

  it 'captures Ruby2html tags with capture instead of writing them to the page' do
    html = render_source(<<~RUBY)
      card = capture { span 'inner' }
      div { plain card }
    RUBY

    expect(html).to eq('<div><span>inner</span></div>')
  end

  it 'escapes an unsafe String returned by a capture block that wrote nothing' do
    html = render_source("plain capture { '<b>' }")

    expect(html).to eq('&lt;b&gt;')
  end

  it 'stores content_for blocks for the layout and leaves the page alone' do
    html = render_template(
      { 'spec/show.html.rb' => "content_for(:sidebar) { nav { a 'Home', href: '/' } }\np 'body'",
        'layouts/spec.html.erb' => '<aside><%= yield :sidebar %></aside><main><%= yield %></main>' },
      layout: 'spec'
    )

    expect(html).to eq('<aside><nav><a href="/">Home</a></nav></aside><main><p>body</p></main>')
  end

  it 'renders a nested Ruby2html::Render into its own string' do
    html = render_source(<<~RUBY)
      inner = Ruby2html::Render.new { p 'x' }.render
      div { plain inner }
    RUBY

    expect(html).to eq('<div><p>x</p></div>')
  end
end
