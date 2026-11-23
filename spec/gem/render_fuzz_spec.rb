# frozen_string_literal: true

require_relative 'render_spec_helper'

# Differential fuzzing of the C extension against the pure-Ruby renderer with
# hostile input: random bytes in several encodings (invalid UTF-8 included),
# attribute names with markup characters, nested data:/aria: hashes and token
# arrays, objects with odd #to_s / #html_safe?, BasicObjects, raising blocks
# and swapped-in output buffers. Errors raised mid-render are rescued and
# written into the document, so a later byte difference still shows. Output
# bytes, encoding and every exception's class and message must be identical.
module RenderFuzz
  PIECES = ['a', 'b', '_', '-', '&', '<', '>', '"', "'", '`', '=', '/', ' ', "\t", "\0", 'é', '日', '🎉', 'x' * 17,
            "\x7F", "\xFF", "\xC3", "\x80", ':'].map(&:b).freeze
  ENCODINGS = [Encoding::UTF_8, Encoding::BINARY, Encoding::US_ASCII, Encoding::ISO_8859_1, Encoding::UTF_16LE,
               Encoding::Shift_JIS].freeze
  TAGS = %i[div span p li a td turbo_frame].freeze
  VOID_TAGS = %i[br img input].freeze
  NAMES = %i[class id data aria hidden data_x draggable title href].freeze

  Odd = Struct.new(:text, :safe) do
    def to_s = text
    def html_safe? = safe
  end

  NOT_A_STRING = Object.new.tap { |o| def o.to_s = 42 }
  PRIVATE_TO_S = Object.new.tap do |o|
    class << o
      private def to_s = '<p>'
    end
  end
  RAISING_TO_S = Object.new.tap { |o| def o.to_s = raise(IOError, 'to_s') }
  BASIC = BasicObject.new
  OBJECTS = [1.5, 2**70, 3r, BASIC, NOT_A_STRING, PRIVATE_TO_S, RAISING_TO_S].freeze

  module_function

  def string(random)
    bytes = Array.new(random.rand(0..6)) { PIECES.sample(random:) }.join
    encoding = ENCODINGS.sample(random:)
    return bytes.force_encoding(encoding) unless encoding == Encoding::UTF_16LE

    utf8 = bytes.force_encoding(Encoding::UTF_8)
    utf8.valid_encoding? ? utf8.encode(Encoding::UTF_16LE) : utf8
  end

  def symbol(random)
    string(random).to_sym
  rescue EncodingError
    :sym
  end

  def value(random, depth = 0)
    case random.rand(13)
    when 0 then nil
    when 1 then true
    when 2 then false
    when 3 then random.rand(-1000..1000)
    when 4 then symbol(random)
    when 5 then string(random).html_safe
    when 6 then depth < 3 ? Array.new(random.rand(0..3)) { value(random, depth + 1) } : 'leaf'
    when 7 then depth < 3 ? Array.new(random.rand(0..3)) { [key(random), value(random, depth + 1)] }.to_h : 'leaf'
    when 8 then Odd.new(string(random), random.rand(2).zero?)
    when 9 then OBJECTS.sample(random:)
    else string(random)
    end
  end

  def key(random)
    case random.rand(4)
    when 0 then NAMES.sample(random:)
    when 1 then symbol(random)
    else string(random)
    end
  end

  def buffer(random)
    [+''.b, (+"\xC3\xA9").b, String.new(encoding: Encoding::US_ASCII), String.new(encoding: Encoding::ISO_8859_1),
     nil, '', ''.b.freeze, []].sample(random:)
  end

  # A block for Render.new: random calls, each error written into the output.
  def document(random, depth = 0)
    lambda do
      random.rand(1..4).times do
        attributes = random.rand(3).zero? ? {} : Array.new(random.rand(1..3)) { [RenderFuzz.key(random), RenderFuzz.value(random)] }.to_h
        begin
          case random.rand(9)
          when 0 then public_send(VOID_TAGS.sample(random:), **attributes)
          when 1 then plain RenderFuzz.value(random)
          when 2 then component RenderFuzz.value(random)
          when 3 then public_send(TAGS.sample(random:), RenderFuzz.value(random), **attributes)
          when 4
            public_send(TAGS.sample(random:), **attributes) do
              raise IOError, 'in block' if random.rand(4).zero?

              RenderFuzz.value(random)
            end
          when 5
            previous = current_output
            self.current_output = RenderFuzz.buffer(random)
            begin
              public_send(TAGS.sample(random:), RenderFuzz.value(random)) { plain RenderFuzz.value(random) }
              br
              component RenderFuzz.value(random)
              swapped = current_output
            ensure
              self.current_output = previous
            end
            plain [swapped.encoding.name, swapped.b]
          else
            child = depth < 3 ? RenderFuzz.document(random, depth + 1) : -> { RenderFuzz.value(random) }
            public_send(TAGS.sample(random:), **attributes, &child)
          end
        rescue StandardError => e
          plain "!#{e.class}: #{e.message}"
        end
      end
      random.rand(3).zero? ? RenderFuzz.value(random) : nil
    end
  end

  def outcome(renderer_class, seed)
    html = renderer_class.new(&document(Random.new(seed))).render.to_str
    [html.b, html.encoding]
  rescue StandardError => e
    [e.class, e.message]
  end
end

RSpec.describe 'Ruby2html native/pure-Ruby differential fuzzing' do
  before { skip 'C extension not loaded' unless Ruby2html.native? }

  it 'renders 2000 hostile random documents byte-identically' do
    2000.times do |seed|
      native = RenderFuzz.outcome(Ruby2html::Render, seed)
      pure = RenderFuzz.outcome(RenderSpecHelper::PURE_RENDER, seed)
      expect(pure).to eq(native), "seed #{seed}"
    end
  end
end
