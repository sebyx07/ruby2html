# frozen_string_literal: true

require_relative 'render_spec_helper'

# Inputs where the C extension and the pure-Ruby implementation used to
# diverge (output, encoding or raised error). Each runs on both.
RenderSpecHelper.describe_each 'Ruby2html::Render robustness' do
  # Kernel#to_s, which is what Ruby (rb_obj_as_string) falls back to when
  # #to_s does not return a String.
  def any_to_s(obj) = Kernel.instance_method(:to_s).bind_call(obj)
  def escaped(text) = text.gsub('<', '&lt;').gsub('>', '&gt;')

  describe 'an object whose #to_s does not return a String' do
    let(:odd) { Object.new.tap { |o| def o.to_s = 42 } }

    it 'renders Kernel#to_s as tag content' do
      odd = self.odd
      expect(render_html { div odd }).to eq("<div>#{escaped(any_to_s(odd))}</div>")
    end

    it 'renders Kernel#to_s through plain' do
      odd = self.odd
      expect(render_html { plain odd }).to eq(escaped(any_to_s(odd)))
    end

    it 'renders Kernel#to_s through component' do
      odd = self.odd
      expect(render_html { component odd }).to eq(any_to_s(odd))
    end

    it 'renders Kernel#to_s as an attribute value and token' do
      odd = self.odd
      text = escaped(any_to_s(odd))
      expect(render_html { div(title: odd, class: [odd]) }).to eq(%(<div title="#{text}" class="#{text}"></div>))
    end

    it 'validates Kernel#to_s as an attribute name' do
      odd = self.odd
      expect { render_html { div(odd => 'x') } }.to raise_error(ArgumentError, /invalid attribute name/)
    end
  end

  it 'calls a private #to_s like string interpolation does' do
    odd = Object.new
    class << odd
      private def to_s = '<private>'
    end

    expect(render_html { div(odd, title: odd) }).to eq('<div title="&lt;private&gt;">&lt;private&gt;</div>')
  end

  it 'ignores a BasicObject returned from a block' do
    expect(render_html { div { BasicObject.new } }).to eq('<div></div>')
  end

  it 'reports an invalid nested attribute name with invalid UTF-8 bytes' do
    name = (+"\xFF_x y").force_encoding(Encoding::UTF_8)
    expect { render_html { div(data: { name => 1 }) } }
      .to raise_error(ArgumentError, "invalid attribute name: #{"data-\xFF-x y".dup.force_encoding(Encoding::UTF_8).inspect}")
  end

  it 'writes nothing for `li text` when the text cannot be transcoded' do
    broken = (+"\x81").force_encoding(Encoding::Shift_JIS)
    html = render_html do
      begin
        li broken
      rescue EncodingError
        nil
      end
      br
    end
    expect(html).to eq('<br />')
  end

  it 'renders boolean attributes whose names hold invalid UTF-8 bytes' do
    name = (+"x\xFF").force_encoding(Encoding::US_ASCII)
    expect(render_html { div(name => true, (+"data-\xFF").b => false) }.b).to eq(%(<div x\xFF data-\xFF="false"></div>).b)
  end

  describe 'US-ASCII strings holding non-ASCII bytes (read with LANG=C)' do
    let(:bytes) { (+"caf\xC3\xA9 <").force_encoding(Encoding::US_ASCII) }

    it 'writes them as UTF-8 bytes, like binary strings' do
      bytes = self.bytes
      html = render_html do
        plain bytes
        p '日本'
        span(title: bytes) { bytes }
      end
      expect(html).to eq('café &lt;<p>日本</p><span title="café &lt;">café &lt;</span>')
      expect(html.encoding).to eq(Encoding::UTF_8)
    end

    it 'keeps the buffer UTF-8 when they are written first' do
      bytes = self.bytes
      html = render_html { li bytes }
      expect(html.encoding).to eq(Encoding::UTF_8)
      expect(html).to eq('<li>café &lt;</li>')
    end
  end

  describe 'a swapped-in output buffer' do
    def capture_into(buffer, &block)
      captured = nil
      render_html do
        previous = current_output
        self.current_output = buffer
        begin
          instance_exec(&block)
          captured = current_output
        ensure
          self.current_output = previous
        end
        nil
      end
      captured
    end

    it 'relabels an ASCII-only binary buffer as UTF-8' do
      captured = capture_into(+''.b) { span 'x' }
      expect(captured).to eq('<span>x</span>')
      expect(captured.encoding).to eq(Encoding::UTF_8)
    end

    it 'relabels a US-ASCII buffer written by plain as UTF-8' do
      captured = capture_into(String.new(encoding: Encoding::US_ASCII)) { plain :x }
      expect(captured.encoding).to eq(Encoding::UTF_8)
    end

    it 'appends to a binary buffer that already holds non-ASCII bytes' do
      captured = capture_into(+"\xC3\xA9".b) { br; span 'é' }
      expect(captured.b).to eq('é<br /><span>é</span>'.b)
      expect(captured.encoding).to eq(Encoding::UTF_8)
    end

    it 'refuses a buffer in another encoding' do
      expect { capture_into(String.new(encoding: Encoding::ISO_8859_1)) { div 'x' } }
        .to raise_error(Encoding::CompatibilityError, 'ruby2html: output buffer must be UTF-8, not ISO-8859-1')
    end

    it 'refuses a buffer that is not a String' do
      expect { capture_into([]) { component 'x' } }
        .to raise_error(TypeError, 'ruby2html: @current_output must be a String')
      expect { capture_into(nil) { br } }.to raise_error(TypeError, 'ruby2html: @current_output must be a String')
    end
  end

  # The pure-Ruby renderer escapes through stdlib ERB::Escape, which CRuby
  # only marks Ractor-safe from 4.0; the C extension is Ractor-safe on every
  # supported CRuby.
  ractor_ready = defined?(Ractor) && RUBY_ENGINE == 'ruby' &&
                 (!description.end_with?('(pure Ruby)') || RUBY_VERSION >= '4.0')

  it 'renders inside a non-main Ractor', if: ractor_ready do
    renderer_class = self.renderer_class
    previous = Warning[:experimental]
    Warning[:experimental] = false
    ractor = Ractor.new(renderer_class) do |klass|
      html = klass.new { plain 'a<'; component '<b>'; div(data: { x_y: [1, :b] }, hidden: true) { 3 } }.render
      html.to_str + Ruby2html.escape_html('<')
    end
    Warning[:experimental] = previous

    result = ractor.respond_to?(:value) ? ractor.value : ractor.take
    expect(result).to eq('a&lt;<b><div data-x-y="1 b" hidden>3</div>&lt;')
  end
end

RSpec.describe 'Ruby2html escape_html robustness' do
  implementations = { 'native' => (Ruby2html::Native if Ruby2html.native?), 'pure Ruby' => Ruby2html::PureRuby }.compact

  implementations.each do |name, implementation|
    context "with #{name}" do
      it 'escapes Kernel#to_s when #to_s does not return a String' do
        odd = Object.new
        def odd.to_s = nil

        expect(implementation.escape_html(odd)).to eq(Kernel.instance_method(:to_s).bind_call(odd).gsub('<', '&lt;').gsub('>', '&gt;'))
      end

      it 'labels US-ASCII input holding non-ASCII bytes as UTF-8, like binary input' do
        input = (+"\xC3\xA9<").force_encoding(Encoding::US_ASCII)
        expect(implementation.escape_html(input)).to eq('é&lt;')
        expect(implementation.escape_html(input.byteslice(0, 2)).encoding).to eq(Encoding::UTF_8)
      end

      it 'keeps ASCII-only US-ASCII input US-ASCII' do
        expect(implementation.escape_html(+'a&'.encode(Encoding::US_ASCII)).encoding).to eq(Encoding::US_ASCII)
      end
    end
  end
end
