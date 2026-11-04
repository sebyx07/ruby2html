# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ruby2html::RailsComponents::TemplateCompiler do
  def rewrite(source)
    described_class.compile(source).source
  end

  it 'prefixes receiverless tag calls with the renderer' do
    expect(rewrite("div class: 'a' do\n  h1 'x'\nend")).to eq("__r2h_renderer.div class: 'a' do\n  __r2h_renderer.h1 'x'\nend")
  end

  it 'maps dashed tags and plain/component' do
    expect(rewrite("turbo_frame id: 1\nplain 'x'")).to eq("__r2h_renderer.turbo_frame id: 1\n__r2h_renderer.plain 'x'")
  end

  it 'routes render through the helpers proxy' do
    expect(rewrite("render partial: 'x'")).to eq("__r2h_helpers.render partial: 'x'")
  end

  it 'routes Rails helpers through the helpers proxy and reports it' do
    compiled = described_class.compile("link_to 'a', '/'")
    expect(compiled.source).to eq("__r2h_helpers.link_to 'a', '/'")
    expect(compiled.uses_helpers).to be(true)
  end

  it 'leaves calls with receivers, locals, unknown methods and def bodies alone' do
    source = "f.label :x\nfoo = 1\nfoo\nroot_path\ntap { }\ndef bar = div"
    expect(rewrite(source)).to eq(source)
  end

  it 'keeps line structure and multibyte text intact' do
    source = "h1 'café'\n\np 'ü'"
    expect(rewrite(source)).to eq("__r2h_renderer.h1 'café'\n\n__r2h_renderer.p 'ü'")
  end

  it 'returns nil for invalid Ruby so the original error surfaces' do
    expect(described_class.compile('div do')).to be_nil
  end
end
