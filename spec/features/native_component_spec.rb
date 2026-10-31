# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Ruby2html::Component (demo app)', type: :request do
  it 'renders the native benchmark component with nested components' do
    get '/benchmark/native'
    expect(response).to have_http_status(:success)
    expect(response.media_type).to eq('text/html')
    body = response.body
    expect(body).to include('<h1>Benchmark: Ruby2html</h1><h2>User Statistics</h2><ul><li>Total Users: 50</li>')
    expect(body.scan('<div class="user-card">').size).to eq(50)
  end

  it 'produces the same markup as the ViewComponent and .html.rb versions' do
    get '/benchmark/native'
    native = response.body
    get '/benchmark/ruby'
    template = response.body[%r{<h1>Benchmark: Ruby2html</h1>.*</div>}m]
    expect(native).to include(template)
  end
end
