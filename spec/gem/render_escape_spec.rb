# frozen_string_literal: true

require_relative 'render_spec_helper'

RenderSpecHelper.describe_each 'Ruby2html escaping' do
  escapes = { '&' => '&amp;', '<' => '&lt;', '>' => '&gt;', '"' => '&quot;', "'" => '&#39;' }

  def reference_escape(str)
    str.gsub(/[&<>"']/, '&' => '&amp;', '<' => '&lt;', '>' => '&gt;', '"' => '&quot;', "'" => '&#39;')
  end

  it 'escapes each of & < > " \'' do
    escapes.each do |char, entity|
      expect(render_html { plain "a#{char}b" }).to eq("a#{entity}b")
    end
  end

  it 'leaves everything else alone' do
    others = (1..127).map(&:chr).join.delete(escapes.keys.join)
    expect(render_html { plain others }).to eq(others)
  end

  it 'handles empty strings and strings made only of escapable bytes' do
    expect(render_html { p '' }).to eq('<p></p>')
    expect(render_html { plain %q(&<>"') * 20 }).to eq(escapes.values.join * 20)
  end

  # The C scanner works on 16-byte chunks: check every position around the
  # chunk boundaries, for every escapable byte, in strings of many lengths.
  it 'finds escapable bytes at every offset around 16-byte chunk boundaries' do
    [1, 15, 16, 17, 31, 32, 33, 47, 48, 64, 65].each do |length|
      escapes.each_key do |char|
        (0...length).each do |offset|
          str = 'x' * length
          str[offset] = char
          expect(render_html { plain str }).to eq(reference_escape(str)), "length #{length}, #{char} at #{offset}"
        end
      end
    end
  end

  it 'escapes many bytes spread over chunks' do
    str = Array.new(500) { |i| (i % 7).zero? ? %q(&<>"').chars.sample(random: Random.new(i)) : 'a' }.join
    expect(render_html { plain str }).to eq(reference_escape(str))
  end

  it 'escapes long strings' do
    clean = 'lorem ipsum ' * 1000
    dirty = 'Tom & Jerry <3 "quotes" ' * 1000
    expect(render_html { p clean }).to eq("<p>#{clean}</p>")
    expect(render_html { p dirty }).to eq("<p>#{reference_escape(dirty)}</p>")
  end

  it 'keeps multibyte UTF-8 intact, also across chunk boundaries' do
    [15, 16, 31, 32].each do |offset|
      str = "#{'a' * offset}é<ü>日本語&🎉"
      html = render_html { plain str }
      expect(html).to eq("#{'a' * offset}é&lt;ü&gt;日本語&amp;🎉")
      expect(html).to be_valid_encoding
    end
  end

  it 'transcodes strings in other encodings to UTF-8' do
    latin1 = 'café <b>'.encode(Encoding::ISO_8859_1)
    utf16 = 'naïve & co'.encode(Encoding::UTF_16LE)
    expect(render_html { plain latin1; plain utf16 }).to eq('café &lt;b&gt;naïve &amp; co')
  end

  it 'treats binary strings as UTF-8 bytes' do
    expect(render_html { plain 'é<'.b }).to eq('é&lt;')
  end

  it 'raises for strings that cannot be transcoded' do
    broken = (+"\xFF").force_encoding(Encoding::Shift_JIS)
    expect { render_html { plain broken } }.to raise_error(EncodingError)
  end
end

RSpec.describe 'Ruby2html.escape_html' do
  it 'escapes and converts to a String' do
    expect(Ruby2html.escape_html(%q(<a href="x">'&'</a>))).to eq('&lt;a href=&quot;x&quot;&gt;&#39;&amp;&#39;&lt;/a&gt;')
    expect(Ruby2html.escape_html(5)).to eq('5')
    expect(Ruby2html.escape_html(nil)).to eq('')
  end

  it 'never returns the caller\'s mutable string' do
    str = +'clean'
    result = Ruby2html.escape_html(str)
    expect(result).to eq(str)
    expect(result).not_to be(str)
  end

  it 'returns frozen clean strings as they are' do
    str = 'clean'
    expect(Ruby2html.escape_html(str)).to be(str)
  end

  it 'matches the pure-Ruby implementation' do
    ['', 'plain', %q(&<>"'), "é<\u{1F389}>", 'x' * 40 + '&'].each do |str|
      expect(Ruby2html.escape_html(str)).to eq(Ruby2html::PureRuby.escape_html(str))
    end
  end
end
