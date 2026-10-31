# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rails integration (demo app)', type: :request do
  it 'renders link_to as an anchor in .html.rb views, components and html() blocks' do
    get root_path
    expect(response.body).to include('<a href="/">Home</a>') # SecondComponent
    expect(response.body).to include('<div><a href="/">home 1</a></div>') # html(self) in ERB
    expect(response.body).not_to include('class="button_to"')
  end

  it 'renders form_with fields as markup, not escaped text' do
    get form_path
    expect(response.body).to include('<form action="/form" accept-charset="UTF-8" method="post">')
    expect(response.body).to include('<label for="name">Name</label><input type="text" name="name" id="name" />')
    expect(response.body).not_to include('&lt;input')
  end

  it 'renders .html.rb partials and helpers from an .html.rb view' do
    get rb_files_path
    expect(response.body).to include('<div>value</div>')
    expect(response.body).to include('<h1>Navbar</h1><h1>footer</h1>')
    expect(response.body).to include('<a href="http://www.example.com/">Home</a>')
  end

  it 'renders ViewComponent sidecar .html.rb templates with component state' do
    get root_path
    expect(response.body).to include('<h1>Third component</h1><div>Item value: Hello, World!</div>')
    expect(response.body).to include('<h1>Yet Another heading from component</h1><p>Hello, World!</p>')
  end

  it 'renders the benchmark .html.rb template and component' do
    get '/benchmark/ruby'
    expect(response).to have_http_status(:success)
    expect(response.body).to include('<h1>Benchmark: Ruby2html</h1>')
    get '/benchmark/compruby'
    expect(response.body).to include('<h2>User Statistics</h2>')
  end

  context 'with forgery protection enabled' do
    around do |example|
      previous = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      example.run
    ensure
      ActionController::Base.allow_forgery_protection = previous
    end

    it 'includes the authenticity token in form_with' do
      get form_path
      expect(response.body).to match(/<input type="hidden" name="authenticity_token" value="[^"]+" autocomplete="off" \/>/)
    end
  end
end
