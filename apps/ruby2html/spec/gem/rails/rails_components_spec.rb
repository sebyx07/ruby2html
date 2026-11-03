# frozen_string_literal: true

require 'rails_helper'
require_relative 'support/template_rendering'

RSpec.describe Ruby2html::RailsComponents do
  include TemplateRendering

  # Minimal ActiveModel record so form_with can resolve names, values and URLs.
  let(:post_class) do
    Class.new do
      include ActiveModel::Model
      include ActiveModel::Attributes
      attribute :id, :integer
      attribute :title, :string
      attribute :status, :string

      def self.name
        'Post'
      end

      def persisted?
        id.present?
      end
    end
  end

  describe 'link_to' do
    it 'renders an anchor (not a button_to form)' do
      expect(render_source("link_to 'Home', '/', class: 'nav'")).to eq('<a class="nav" href="/">Home</a>')
    end

    it 'captures Ruby2html tags from the block inside the anchor' do
      html = render_source("link_to '/' do\n  span 'icon'\n  plain 'Home'\nend")
      expect(html).to eq('<a href="/"><span>icon</span>Home</a>')
    end

    it 'escapes a string returned from the block' do
      expect(render_source("link_to('/') { '<i>' }")).to eq('<a href="/">&lt;i&gt;</a>')
    end
  end

  describe 'button_to' do
    it 'renders a button form with the block content inside the button' do
      html = render_source("button_to '/x' do\n  strong 'Go'\nend")
      expect(html).to include('<button type="submit"><strong>Go</strong></button>')
      expect(html).to start_with('<form class="button_to" method="post" action="/x">')
    end
  end

  describe 'image_tag' do
    it 'renders an img tag' do
      expect(render_source("image_tag 'http://x.test/a.png', alt: 'A'")).to eq('<img alt="A" src="http://x.test/a.png" />')
    end
  end

  describe 'form_with' do
    it 'renders fields inside the form without escaping them' do
      html = render_source(<<~RUBY)
        form_with url: '/s', method: :get do |f|
          f.label :q
          f.text_field :q, placeholder: 'Search'
          f.submit 'Go'
        end
      RUBY
      expect(html).to eq(
        '<form action="/s" accept-charset="UTF-8" method="get"><label for="q">Q</label>' \
        '<input placeholder="Search" type="text" name="q" id="q" />' \
        '<input type="submit" name="commit" value="Go" data-disable-with="Go" /></form>'
      )
    end

    it 'uses the model for names, values, method spoofing and escaping' do
      post = post_class.new(id: 1, title: '"><script>x</script>')
      html = render_template(
        { 'spec/show.html.rb' => "form_with model: @post, url: '/posts/1' do |f|\n  f.text_field :title\nend" },
        assigns: { post: }
      )
      expect(html).to include('<input type="hidden" name="_method" value="patch" autocomplete="off" />')
      expect(html).to include('name="post[title]" id="post_title"')
      expect(html).to include('value="&quot;&gt;&lt;script&gt;x&lt;/script&gt;"')
      expect(html).not_to include('<script>')
    end

    it 'supports labels with blocks, select (a private Kernel method) and nested tags' do
      html = render_template(
        { 'spec/show.html.rb' => <<~RUBY },
          form_with model: @post, url: '/posts' do |f|
            div class: 'field' do
              f.label :title do
                span 'Title'
              end
            end
            f.select :status, %w[draft live]
          end
        RUBY
        assigns: { post: post_class.new }
      )
      expect(html).to include('<div class="field"><label for="post_title"><span>Title</span></label></div>')
      expect(html).to include('<select name="post[status]" id="post_status"><option value="draft">draft</option>')
    end

    it 'wraps nested builders from fields_for' do
      html = render_source(<<~RUBY)
        form_with url: '/x', scope: :user do |f|
          f.fields_for :address do |a|
            a.text_field :city
          end
        end
      RUBY
      expect(html).to include('<input type="text" name="user[address][city]" id="user_address_city" />')
    end

    it 'sets multipart when a file field is used' do
      html = render_source("form_with url: '/u' do |f|\n  f.file_field :doc\nend")
      expect(html).to include('enctype="multipart/form-data"')
    end

    it 'returns non-markup builder values unchanged' do
      html = render_source("form_with url: '/u' do |f|\n  p f.field_id(:name)\nend")
      expect(html).to include('<p>name</p>')
    end
  end
end
