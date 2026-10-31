# frozen_string_literal: true

require 'bigdecimal'
require_relative 'render_spec_helper'

RenderSpecHelper.describe_each 'Ruby2html::Render' do
  describe '#render' do
    it 'renders basic HTML' do
      expect(render_html { div { p 'Hello, World!' } }).to eq('<div><p>Hello, World!</p></div>')
    end

    it 'renders nested elements' do
      html = render_html do
        div do
          h1 'Title'
          p 'Paragraph'
        end
      end
      expect(html).to eq('<div><h1>Title</h1><p>Paragraph</p></div>')
    end

    it 'renders attributes in the order given' do
      html = render_html { div(class: 'container', id: 'main') { p 'Content' } }
      expect(html).to eq('<div class="container" id="main"><p>Content</p></div>')
    end

    it 'escapes HTML in content' do
      expect(render_html { p '<script>alert("XSS")</script>' })
        .to eq('<p>&lt;script&gt;alert(&quot;XSS&quot;)&lt;/script&gt;</p>')
    end

    it 'renders void elements without a closing tag' do
      expect(render_html { img src: 'image.jpg', alt: 'An image' }).to eq('<img src="image.jpg" alt="An image" />')
      expect(render_html { br }).to eq('<br />')
    end

    it 'ignores content and blocks given to void elements' do
      expect(render_html { br('text') { p 'x' } }).to eq('<br />')
    end

    it 'renders every HTML5 tag, none shadowed by Render\'s own methods' do
      Ruby2html::Render::HTML5_TAGS.each do |tag|
        method_name = tag.tr('-', '_')
        expected = Ruby2html::Render::VOID_ELEMENTS.include?(tag) ? "<#{tag} id=\"x\" />" : "<#{tag} id=\"x\">y</#{tag}>"
        expect(render_html { public_send(method_name, 'y', id: 'x') }).to eq(expected), tag
      end
    end

    it 'renders hyphenated tags through underscored methods' do
      expect(render_html { turbo_frame(id: 'f') { 'x' } }).to eq('<turbo-frame id="f">x</turbo-frame>')
    end

    it 'renders empty elements' do
      expect(render_html { div }).to eq('<div></div>')
      expect(render_html { div(nil) }).to eq('<div></div>')
    end

    it 'returns a UTF-8 SafeBuffer' do
      html = render_html { p 'é' }
      expect(html).to be_a(ActiveSupport::SafeBuffer)
      expect(html.encoding).to eq(Encoding::UTF_8)
      expect(html).to be_valid_encoding
    end

    it 'delegates to the context render when given arguments' do
      context = double('context', instance_variables: [])
      allow(context).to receive(:render).with(partial: 'item').and_return('<b>partial</b>'.html_safe)
      expect(render_html(context) { div { render partial: 'item' } }).to eq('<div><b>partial</b></div>')
    end
  end

  describe 'content arguments' do
    it 'renders non-String content with to_s, escaped' do
      expect(render_html { p 42 }).to eq('<p>42</p>')
      expect(render_html { p(-7) }).to eq('<p>-7</p>')
      expect(render_html { p 2**70 }).to eq("<p>#{2**70}</p>")
      expect(render_html { p 1.5 }).to eq('<p>1.5</p>')
      expect(render_html { p :'<sym>' }).to eq('<p>&lt;sym&gt;</p>')
      expect(render_html { p false }).to eq('<p>false</p>')
      expect(render_html { p Struct.new(:to_s).new('<obj>') }).to eq('<p>&lt;obj&gt;</p>')
    end

    it 'renders html_safe content raw' do
      expect(render_html { p '<b>bold</b>'.html_safe }).to eq('<p><b>bold</b></p>')
    end

    it 'raises on extra positional arguments' do
      expect { render_html { p 'a', 'b' } }.to raise_error(ArgumentError)
    end
  end

  describe 'blocks' do
    it 'uses a String returned by a block that wrote nothing, escaped' do
      expect(render_html { div { 'a & b' } }).to eq('<div>a &amp; b</div>')
    end

    it 'renders String, Symbol and Numeric block results and ignores everything else' do
      results = {
        'a<b' => 'a&lt;b', :sym => 'sym', 3 => '3', 1.5 => '1.5', BigDecimal('2.5') => BigDecimal('2.5').to_s,
        Rational(1, 3) => '1/3', nil => '', true => '', false => '', [1, 2] => '', { a: 1 } => '',
        Struct.new(:to_s).new('<obj>') => ''
      }
      results.each do |result, content|
        expect(render_html { td { result } }).to eq("<td>#{content}</td>"), result.inspect
      end
    end

    it 'renders an html_safe block result raw' do
      expect(render_html { div { '<i>x</i>'.html_safe } }).to eq('<div><i>x</i></div>')
    end

    it 'ignores other block results such as the Array from #each' do
      expect(render_html { ul { [].each { li 'x' } } }).to eq('<ul></ul>')
      expect(render_html { div { nil } }).to eq('<div></div>')
      expect(render_html { div { true } }).to eq('<div></div>')
    end

    it 'ignores the block result once the block wrote markup' do
      expect(render_html { div { span 'a'; 'ignored' } }).to eq('<div><span>a</span></div>')
    end

    it 'prefers the block over a content argument' do
      expect(render_html { div('arg') { span 'block' } }).to eq('<div><span>block</span></div>')
    end

    it 'yields no arguments, so lambdas work' do
      expect(render_html { div(&-> { 'x' }) }).to eq('<div>x</div>')
    end

    it 'supports deep nesting' do
      html = render_html do
        build = ->(depth) { depth.zero? ? plain('leaf') : div { build.(depth - 1) } }
        build.(50)
      end
      expect(html).to eq("#{'<div>' * 50}leaf#{'</div>' * 50}")
    end

    it 'supports break and next inside blocks' do
      html = render_html do
        ul do
          %w[a b c].each do |item|
            next if item == 'b'

            li item
          end
        end
      end
      expect(html).to eq('<ul><li>a</li><li>c</li></ul>')
    end

    it 'keeps the partial output and stays usable when a block raises' do
      renderer = renderer_class.new { nil }
      expect { renderer.div { raise 'boom' } }.to raise_error('boom')
      renderer.p 'after'
      expect(renderer.current_output).to eq('<div><p>after</p>')
    end
  end

  describe 'return values' do
    it 'returns nil from tag methods, plain and component' do
      renderer = renderer_class.new { nil }
      expect([renderer.div('x'), renderer.br, renderer.plain('x'), renderer.component('<x>')]).to all(be_nil)
    end
  end

  describe '#plain' do
    it 'renders unescaped content for ActiveSupport::SafeBuffer' do
      expect(render_html { plain '<strong>Safe HTML</strong>'.html_safe }).to eq('<strong>Safe HTML</strong>')
    end

    it 'escapes regular strings' do
      expect(render_html { plain '<em>Unsafe HTML</em>' }).to eq('&lt;em&gt;Unsafe HTML&lt;/em&gt;')
    end

    it 'renders nil as nothing and other objects with to_s' do
      expect(render_html { plain nil; plain 5; plain :'a&b' }).to eq('5a&amp;b')
    end

    it 'can append the output buffer to itself' do
      renderer = renderer_class.new { plain 'a<' }
      renderer.render
      renderer.plain(renderer.current_output)
      expect(renderer.current_output).to eq('a&lt;a&amp;lt;')
    end
  end

  describe '#component' do
    it 'renders component output raw' do
      component_output = '<custom-component>Content</custom-component>'
      expect(render_html { component component_output }).to eq(component_output)
    end

    it 'renders nil as nothing' do
      expect(render_html { component nil }).to eq('')
    end
  end

  describe '#current_output' do
    it 'writes into a swapped-in buffer (used to capture output)' do
      captured = nil
      html = render_html do
        div do
          previous = current_output
          self.current_output = ''.b # binary, like a bare String.new
          span 'é'
          captured = current_output
          self.current_output = previous
          nil # the assignment's value is a String, which would become the content
        end
      end
      expect(html).to eq('<div></div>')
      expect(captured).to eq('<span>é</span>')
      expect(captured.encoding).to eq(Encoding::UTF_8)
    end
  end

  describe 'method_missing' do
    let(:context) { double('context', instance_variables: []) }

    it 'delegates unknown methods to the context' do
      allow(context).to receive(:custom_helper).and_return('Custom Helper Output')
      expect(render_html(context) { plain(custom_helper) }).to eq('Custom Helper Output')
    end

    it 'passes positional hashes, keywords and blocks through unchanged' do
      allow(context).to receive(:helper) { |*args, **kw, &blk| "#{args.inspect} #{kw.inspect} #{blk.call}" }
      expect(render_html(context) { plain helper({ a: 1 }, b: 2) { 'blk' } })
        .to eq(ERB::Util.html_escape("#{[{ a: 1 }].inspect} #{{ b: 2 }.inspect} blk")) # Hash#inspect differs by Ruby version
    end

    it 'raises NoMethodError for methods nobody defines' do
      expect { render_html(context) { undefined_method } }.to raise_error(NameError)
      expect { render_html { undefined_method(1) } }.to raise_error(NoMethodError)
    end

    it 'responds to tags and to context methods' do
      allow(context).to receive(:custom_helper)
      renderer = renderer_class.new(context)
      expect(renderer).to respond_to(:div, :turbo_frame, :custom_helper)
      expect(renderer).not_to respond_to(:nope)
    end
  end

  describe 'instance variables' do
    it 'copies the context instance variables, except internal ones' do
      context = Object.new
      context.instance_variable_set(:@test_var, 'Test Value')
      context.instance_variable_set(:@_internal, 'hidden')
      context.instance_variable_set(:@output_buffer, 'hidden')
      html = render_html(context) { plain "#{@test_var}|#{@_internal}|#{@output_buffer}" }
      expect(html).to eq('Test Value||')
    end
  end

  describe 'concurrency' do
    it 'renders independently in parallel threads' do
      klass = renderer_class
      results = Array.new(8) do |i|
        Thread.new do
          Array.new(50) { klass.new { ul { 20.times { |j| li "#{i}-#{j}", class: "c#{i}" } } }.render }.uniq
        end
      end.map(&:value)
      results.each_with_index do |htmls, i|
        expected = "<ul>#{Array.new(20) { |j| "<li class=\"c#{i}\">#{i}-#{j}</li>" }.join}</ul>"
        expect(htmls).to eq([expected])
      end
    end

    it 'supports renderers nested inside a block' do
      inner_class = renderer_class
      html = render_html do
        div { component(inner_class.new { span 'inner' }.render) }
      end
      expect(html).to eq('<div><span>inner</span></div>')
    end

    it 'gives a nested Render its own buffer instead of writing to the outer page' do
      inner_class = renderer_class
      inner = nil
      outer = render_html do
        div do
          inner = inner_class.new { p 'x' }.render
          nil # otherwise the block's String result would become the div's content
        end
      end
      expect(inner).to eq('<p>x</p>')
      expect(outer).to eq('<div></div>')
    end
  end
end

RSpec.describe Ruby2html do
  it 'exposes which implementation is loaded' do
    expect(described_class.native?).to eq(ENV['RUBY2HTML_DISABLE_EXT'] != '1') if RUBY_ENGINE == 'ruby'
    expect(Ruby2html::Render.include?(Ruby2html::PureRuby)).to eq(!described_class.native?)
  end

  it 'defines the same methods in the C extension and the pure-Ruby fallback' do
    skip 'C extension not loaded' unless described_class.native?

    expect(Ruby2html::Native.public_instance_methods.sort).to eq(Ruby2html::PureRuby.public_instance_methods.sort)
  end

  it 'no longer keeps a global attribute cache' do
    expect(described_class.const_defined?(:ATTRIBUTE_CACHE)).to be(false)
  end
end
