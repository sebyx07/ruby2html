# frozen_string_literal: true

require 'rails_helper'
require_relative 'support/template_rendering'

RSpec.describe 'Template locals named like tags' do
  include TemplateRendering

  it 'reads partial locals instead of rewriting them into tag calls' do
    html = render_template(
      { 'spec/show.html.rb' => "render partial: 'spec/item', locals: { title: 'Hello', label: 'L' }",
        'spec/_item.html.rb' => "h2 title\np label" }
    )

    expect(html).to eq('<h2>Hello</h2><p>L</p>')
  end

  it 'reads render locals: in the main template' do
    expect(render_source('h2 label', locals: { label: 'L' })).to eq('<h2>L</h2>')
  end

  it 'reads strict locals (`# locals:` magic comment) instead of rewriting them into tag calls' do
    html = render_template(
      { 'spec/show.html.rb' => "render partial: 'spec/item', locals: { title: 'Hello' }",
        'spec/_item.html.rb' => "# locals: (title:, label: 'L', **rest)\nh2 title\np label\nspan rest.size" }
    )

    expect(html).to eq('<h2>Hello</h2><p>L</p><span>0</span>')
  end

  it 'keeps line numbers of strict-locals templates aligned' do
    templates = { 'spec/show.html.rb' => "# locals: (title: 'x')\nh1 title\nraise 'boom'\n" }
    expect { render_template(templates) }.to raise_error(ActionView::Template::Error) { |error|
      expect(error.cause.backtrace_locations.first.lineno).to eq(3)
    }
  end
end
