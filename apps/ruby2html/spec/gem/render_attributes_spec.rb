# frozen_string_literal: true

require_relative 'render_spec_helper'

RenderSpecHelper.describe_each 'Ruby2html attributes' do
  def attrs(**attributes)
    render_html { span(**attributes) }.delete_prefix('<span').delete_suffix('></span>')
  end

  it 'renders String, Symbol and numeric values, escaped' do
    expect(attrs(title: %q(<"Tom" & 'Jerry'>), role: :button, tabindex: -1, step: 0.5))
      .to eq(' title="&lt;&quot;Tom&quot; &amp; &#39;Jerry&#39;&gt;" role="button" tabindex="-1" step="0.5"')
  end

  it 'renders other objects with to_s, escaped' do
    expect(attrs(value: Struct.new(:to_s).new('a"b'), big: 2**70)).to eq(%( value="a&quot;b" big="#{2**70}"))
  end

  it 'omits nil values' do
    expect(attrs(id: nil, class: 'x')).to eq(' class="x"')
  end

  it 'renders true as a bare attribute and omits false' do
    expect(attrs(disabled: true, hidden: false, required: true)).to eq(' disabled required')
  end

  it 'renders true/false as strings where the value matters' do
    expect(attrs('aria-hidden': true, 'aria-expanded': false, 'data-turbo': false))
      .to eq(' aria-hidden="true" aria-expanded="false" data-turbo="false"')
    expect(attrs(draggable: true, spellcheck: false, contenteditable: true))
      .to eq(' draggable="true" spellcheck="false" contenteditable="true"')
  end

  it 'expands nested hashes, dasherizing their keys' do
    expect(attrs(data: { user_id: 1, controller: 'menu', turbo: false, empty: nil }, aria: { label: 'Open' }))
      .to eq(' data-user-id="1" data-controller="menu" data-turbo="false" aria-label="Open"')
    expect(attrs(data: { a: { b_c: 'd' } })).to eq(' data-a-b-c="d"')
    expect(attrs(data: {})).to eq('')
  end

  it 'keeps underscores in top-level keys, as 1.x did' do
    expect(attrs(data_foo: 'x', 'accept-charset': 'utf-8')).to eq(' data_foo="x" accept-charset="utf-8"')
  end

  it 'joins arrays as space-separated tokens, skipping nil and false' do
    expect(attrs(class: ['btn', nil, :primary, false, ['nested', '<x>']])).to eq(' class="btn primary nested &lt;x&gt;"')
    expect(attrs(class: [])).to eq(' class=""')
  end

  it 'accepts String keys' do
    expect(attrs('data-remote' => 'true', 'class' => 'x')).to eq(' data-remote="true" class="x"')
  end

  it 'rejects names that could break out of the tag' do
    ['a b', 'a"b', "a'b", 'a>b', 'a<b', 'a/b', 'a=b', "a\nb", "a\tb", "a\0b", "a\x7Fb", ''].each do |name|
      expect { attrs(name => 'x') }.to raise_error(ArgumentError), name.inspect
      expect { attrs(data: { name => 'x' }) }.to raise_error(ArgumentError), name.inspect
    end
  end

  it 'refuses absurdly deep or self-referencing nesting instead of overflowing the stack' do
    recursive_hash = {}
    recursive_hash[:a] = recursive_hash
    recursive_array = []
    recursive_array << recursive_array
    expect { attrs(data: recursive_hash) }.to raise_error(ArgumentError, /nested/)
    expect { attrs(class: recursive_array) }.to raise_error(ArgumentError, /nested/)
    expect(attrs(class: ['', 'a', [''], 'b'])).to eq(' class=" a  b"')
  end

  it 'allows non-ASCII names' do
    expect(attrs('dätä': 'x')).to eq(' dätä="x"')
  end

  it 'renders attributes on void elements' do
    expect(render_html { input type: 'checkbox', checked: true, disabled: false }).to eq('<input type="checkbox" checked />')
  end

  # 1.x cached attribute strings by `attributes.hash`: two different Hashes
  # with the same #hash got each other's attributes.
  it 'never mixes up attribute hashes with colliding #hash values' do
    colliding = Struct.new(:to_s) do
      def hash
        42
      end

      def eql?(_other)
        true
      end
    end
    first = colliding.new('first')
    second = colliding.new('second')
    expect({ id: first }.hash).to eq({ id: second }.hash)

    html = render_html do
      div(id: first)
      div(id: second)
      img(id: first)
      img(id: second)
    end
    expect(html).to eq('<div id="first"></div><div id="second"></div><img id="first" /><img id="second" />')
  end

  it 'does not retain anything per distinct attribute value' do
    skip 'ObjectSpace.count_objects is CRuby-only' unless ObjectSpace.respond_to?(:count_objects)

    GC.start
    before = ObjectSpace.count_objects[:T_STRING]
    5_000.times { |i| render_html { a href: "/items/#{i}", id: "item-#{i}" } }
    GC.start
    expect(ObjectSpace.count_objects[:T_STRING] - before).to be < 2_000
  end
end
