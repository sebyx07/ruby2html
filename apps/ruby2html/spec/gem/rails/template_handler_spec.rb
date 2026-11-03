# frozen_string_literal: true

require 'rails_helper'
require_relative 'support/template_rendering'

RSpec.describe Ruby2html::TemplateHandler do
  include TemplateRendering

  it 'renders tags, instance variables and locals' do
    html = render_template(
      { 'spec/show.html.rb' => "h1 @title\np greeting\n" },
      assigns: { title: 'Hello' }, locals: { greeting: 'Hi' }
    )
    expect(html).to eq('<h1>Hello</h1><p>Hi</p>')
  end

  it 'returns an html_safe string' do
    expect(render_source("div 'x'")).to be_html_safe
  end

  it 'runs the template in the view, so assigned instance variables reach the layout' do
    html = render_template(
      { 'spec/show.html.rb' => "@page_title = 'From template'\nh1 'body'",
        'layouts/spec.html.erb' => '<title><%= @page_title %></title><%= yield %>' },
      layout: 'spec'
    )
    expect(html).to eq('<title>From template</title><h1>body</h1>')
  end

  it 'renders partials in place, without double escaping them' do
    html = render_template(
      { 'spec/show.html.rb' => "div do\n  render partial: 'spec/item', locals: { name: '<b>' }\nend",
        'spec/_item.html.rb' => 'span name' }
    )
    expect(html).to eq('<div><span>&lt;b&gt;</span></div>')
  end

  it 'routes Rails helpers through Ruby2html so they are emitted in place' do
    html = render_source("div do\n  link_to 'Home', '/'\nend")
    expect(html).to eq('<div><a href="/">Home</a></div>')
  end

  it 'keeps backtrace line numbers aligned with the template source' do
    templates = { 'spec/show.html.rb' => "# frozen_string_literal: true\n\nh1 'ok'\nraise 'boom'\n" }
    expect { render_template(templates) }.to raise_error(ActionView::Template::Error) { |error|
      expect(error.cause.backtrace_locations.first.lineno).to eq(4)
    }
  end

  it 'keeps no renderer in thread/fiber-global state' do
    keys_before = Thread.current.keys
    render_source("h1 'x'")
    expect(Thread.current.keys).to eq(keys_before)
  end

  it 'restores the view renderer slot when a nested partial raises' do
    templates = {
      'spec/show.html.rb' => "div do\n  begin\n    render partial: 'spec/bad'\n  rescue ActionView::Template::Error\n  end\n  " \
                             "p @__r2h.nil? ? 'lost' : 'kept'\nend",
      'spec/_bad.html.rb' => "raise 'boom'"
    }
    expect(render_template(templates)).to eq('<div><p>kept</p></div>')
  end

  it 'transcodes binary template sources so non-ASCII literals work' do
    html = render_source("h1 'café ✓'".b)
    expect(html).to eq('<h1>café ✓</h1>')
    expect(html.encoding).to eq(Encoding::UTF_8)
  end

  it 'leaves methods defined inside a template alone' do
    source = "def self.shout(text) = text.upcase\nh1 shout('hi')"
    expect(render_source(source)).to eq('<h1>HI</h1>')
  end

  context 'with annotate_rendered_view_with_filenames' do
    around do |example|
      previous = ActionView::Base.annotate_rendered_view_with_filenames
      ActionView::Base.annotate_rendered_view_with_filenames = true
      example.run
    ensure
      ActionView::Base.annotate_rendered_view_with_filenames = previous
    end

    it 'wraps HTML templates in BEGIN/END comments computed at compile time' do
      html = render_source("h1 'x'")
      # FixtureResolver identifiers start with '/', real templates are relative to Rails.root.
      expect(html).to match(%r{\A<!-- BEGIN /?spec/show\.html\.rb --><h1>x</h1><!-- END /?spec/show\.html\.rb -->\z})
      expect(html).to be_html_safe
    end
  end

  context 'with the closure fallback (no Prism / unparsable source)' do
    before { allow(Ruby2html::RailsComponents::TemplateCompiler).to receive(:compile).and_return(nil) }

    it 'renders the same output' do
      html = render_template(
        { 'spec/show.html.rb' => "h1 @title\ndiv do\n  link_to 'Home', '/'\nend\np greeting" },
        assigns: { title: 'Hello' }, locals: { greeting: 'Hi' }
      )
      expect(html).to eq('<h1>Hello</h1><div><a href="/">Home</a></div><p>Hi</p>')
    end
  end

  describe 'XSS' do
    let(:evil) { '<script>alert(1)</script>' }
    let(:escaped) { '&lt;script&gt;alert(1)&lt;/script&gt;' }

    it 'escapes tag content, plain text and attribute values' do
      html = render_template(
        { 'spec/show.html.rb' => "div @evil\nplain @evil\nspan(title: @evil) { @evil }" },
        assigns: { evil: }
      )
      expect(html).not_to include('<script>')
      expect(html).to include("<div>#{escaped}</div>")
    end

    it 'does not escape html_safe content passed to plain' do
      html = render_source("plain '<br>'.html_safe")
      expect(html).to eq('<br>')
    end

    it 'escapes link text but not the generated anchor' do
      html = render_source("link_to @evil, '/'", assigns: { evil: })
      expect(html).to eq(%(<a href="/">#{escaped}</a>))
    end
  end
end
