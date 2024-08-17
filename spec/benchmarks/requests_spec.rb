# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'HTML vs Ruby2html Benchmark', type: :request do
  it 'compares requests per second for normal HTML and Ruby2html', skip: ENV['CI'].present? do
    Benchmark.ips do |x|
      # Configure the benchmark
      x.config(time: 60, warmup: 10)

      x.report('GET /benchmark/html (ERB)') do
        get '/benchmark/html'
        expect(response).to have_http_status(:success)
      end

      x.report('GET /benchmark/ruby (Ruby2html)') do
        get '/benchmark/ruby'
        expect(response).to have_http_status(:success)
      end

      x.report('GET /benchmark/slim (Slim)') do
        get '/benchmark/slim'
        expect(response).to have_http_status(:success)
      end

      # Compare the results
      x.compare!
    end
  end
end
