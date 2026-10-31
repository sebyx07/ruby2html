# frozen_string_literal: true

require_relative 'render_spec_helper'

# Regressions from the 2.0 XSS audit. Each must behave identically in the C
# extension and the pure-Ruby implementation.
RenderSpecHelper.describe_each 'Ruby2html::Render hardening' do
  it 'rolls back a start tag whose attributes raise, so later text is not parsed as attributes' do
    bio = ' autofocus onfocus=alert(1) x'
    html = render_html do
      begin
        div(class: 'card', 'bad key' => 1) { }
      rescue ArgumentError
        nil
      end
      plain bio
      span 'ok'
    end

    expect(html).to eq(' autofocus onfocus=alert(1) x<span>ok</span>')
  end

  it 'rolls back a void tag whose attribute value raises in to_s' do
    bad = Object.new
    def bad.to_s = raise('boom')

    html = render_html do
      begin
        img(src: bad)
      rescue RuntimeError
        nil
      end
      plain '<x>'
    end

    expect(html).to eq('&lt;x&gt;')
  end

  it 'escapes a plain String even if it defines a singleton html_safe?' do
    spoofed = +'<b>'
    def spoofed.html_safe? = true

    expect(render_html { div spoofed; plain spoofed }).to eq('<div>&lt;b&gt;</div>&lt;b&gt;')
  end

  it 'transcodes attribute names in other encodings' do
    html = render_html { div("\xE9".dup.force_encoding(Encoding::ISO_8859_1) => 'x') }

    expect(html).to eq('<div é="x"></div>')
    expect(html.encoding).to eq(Encoding::UTF_8)
  end

  it 'passes invalid UTF-8 bytes in attribute names through without raising' do
    expect(render_html { div("a\xFF" => 'x') }.b).to eq("<div a\xFF=\"x\"></div>".b)
    expect(render_html { div(data: { "a\xFF" => 'x' }) }.b).to eq("<div data-a\xFF=\"x\"></div>".b)
  end

  it 'reports the full nested attribute name when it is invalid' do
    expect { render_html { div(data: { 'x onclick' => 1 }) } }
      .to raise_error(ArgumentError, 'invalid attribute name: "data-x onclick"')
  end
end

RSpec.describe 'Ruby2html.escape_html encoding' do
  it 'labels the result of binary input as UTF-8' do
    expect(Ruby2html.escape_html("<\xFF".b).encoding).to eq(Encoding::UTF_8)
    expect(Ruby2html.escape_html('ab'.b).encoding).to eq(Encoding::UTF_8)
  end

  it 'escapes invalid UTF-8 without raising in the pure-Ruby implementation' do
    expect(Ruby2html::PureRuby.escape("\xFF<").b).to eq("\xFF&lt;".b)
  end
end

RenderSpecHelper.describe_each 'Ruby2html::Render rollback edge cases' do
  it 'keeps the original exception when an attribute replaces the buffer and raises' do
    renderer = nil
    evil = Object.new
    evil.define_singleton_method(:to_s) do
      renderer.current_output.replace('ab')
      raise 'boom'
    end

    renderer = renderer_class.new { div(id: evil) }
    expect { renderer.render }.to raise_error(RuntimeError, 'boom')
  end

  it 'keeps the original exception when an attribute shares the buffer and raises' do
    renderer = nil
    evil = Object.new
    evil.define_singleton_method(:to_s) do
      renderer.current_output.dup
      raise 'boom'
    end

    renderer = renderer_class.new do
      plain 'x' * 100
      begin
        div(id: evil)
      rescue RuntimeError
        nil
      end
    end
    expect(renderer.render).to eq('x' * 100)
  end
end

RSpec.describe 'Ruby2html::Native.define_tag' do
  it 'renders a 32-character void tag without truncation' do
    skip 'C extension not loaded' unless Ruby2html.native?

    name = 'x' * 32
    Ruby2html::Native.define_tag(name, name, true)
    expect(Ruby2html::Render.new { __send__(name) }.render).to eq("<#{name} />")
  ensure
    # Keep the Native/PureRuby method sets identical for the parity spec.
    Ruby2html::Native.send(:remove_method, name) if Ruby2html::Native.method_defined?(name)
  end
end
