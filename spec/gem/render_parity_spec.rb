# frozen_string_literal: true

require_relative 'render_spec_helper'

# Renders random documents with the C extension and the pure-Ruby fallback
# and requires identical output (or the same error).
RSpec.describe 'Ruby2html native/pure-Ruby parity' do
  before { skip 'C extension not loaded' unless Ruby2html.native? }

  texts = ['', 'plain', 'a & b', '<"quoted">', "it's", 'é日本🎉<', 'x' * 15 + '<', 'y' * 33 + '&',
           'ä'.encode(Encoding::ISO_8859_1), '<b>safe</b>'.html_safe, :sym, 42, -3, 1.25, nil, true]
  values = texts + [false, [:a, nil, 'b<'], { x_y: 1, z: false }, Object.new.tap { |o| def o.to_s = '<o>' }]
  names = [:class, :id, :data, :aria, :hidden, :data_x, 'data-y', :draggable, :'aria-pressed', :title]
  tags = %i[div span p li ul a h1 td section turbo_frame]
  void_tags = %i[br img input hr]

  random_document = lambda do |random, depth|
    lambda do
      random.rand(1..4).times do
        attributes = Array.new(random.rand(0..3)) { [names.sample(random:), values.sample(random:)] }.to_h
        case random.rand(5)
        when 0 then public_send(void_tags.sample(random:), **attributes)
        when 1 then plain texts.sample(random:)
        when 2 then public_send(tags.sample(random:), texts.sample(random:), **attributes)
        else
          child = depth < 4 ? random_document.(random, depth + 1) : -> { texts.sample(random:) }
          public_send(tags.sample(random:), **attributes, &child)
        end
      end
      random.rand(3).zero? ? texts.sample(random:) : nil
    end
  end

  outcome = lambda do |renderer_class, seed|
    renderer_class.new(&random_document.(Random.new(seed), 0)).render.to_str
  rescue StandardError => e
    e.class
  end

  it 'renders 500 random documents identically' do
    500.times do |seed|
      native = outcome.(Ruby2html::Render, seed)
      pure = outcome.(RenderSpecHelper::PURE_RENDER, seed)
      expect(pure).to eq(native), "seed #{seed}"
    end
  end
end
