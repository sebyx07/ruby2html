# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ruby2html::HtmlBeautifierMiddleware do
  let(:html) { '<div><p>hi</p></div>' }
  let(:beautified) { HtmlBeautifier.beautify(html) }

  def call(status: 200, headers: { 'content-type' => 'text/html; charset=utf-8' }, body: [html])
    described_class.new(->(_env) { [status, headers, body] }).call({})
  end

  it 'beautifies text/html responses and updates content-length' do
    status, headers, body = call(headers: { 'content-type' => 'text/html', 'content-length' => html.bytesize.to_s })
    expect(status).to eq(200)
    expect(body).to eq([beautified])
    expect(headers['content-length']).to eq(beautified.bytesize.to_s)
  end

  it 'beautifies the whole document, not each chunk' do
    _, _, body = call(body: ['<div><p>h', 'i</p></div>'])
    expect(body).to eq([beautified])
  end

  it 'works with Rack::Headers and legacy mixed-case hashes without duplicating keys' do
    rack_headers = Rack::Headers.new.merge!('Content-Type' => 'text/html')
    expect(call(headers: rack_headers)[2]).to eq([beautified])

    _, headers, = call(headers: { 'Content-Type' => 'text/html', 'Content-Length' => '1' })
    expect(headers).to eq('Content-Type' => 'text/html', 'Content-Length' => beautified.bytesize.to_s)
  end

  it 'closes the original body' do
    body = [html]
    body.define_singleton_method(:close) { @closed = true }
    call(body:)
    expect(body.instance_variable_get(:@closed)).to be(true)
  end

  it 'leaves non-HTML, compressed, streamed, bodiless and non-buffered responses untouched' do
    streaming = Object.new.tap { |b| b.define_singleton_method(:each) { |&blk| blk.call(html) } }
    cases = [
      { headers: { 'content-type' => 'application/json' } },
      { headers: { 'content-type' => 'text/html', 'content-encoding' => 'gzip' } },
      { headers: { 'content-type' => 'text/html', 'transfer-encoding' => 'chunked' } },
      { status: 204 },
      { status: 304 },
      { body: streaming }
    ]
    cases.each do |options|
      body = options.fetch(:body) { [html] }
      expect(call(**options, body:)[2]).to be(body)
    end
  end

  it 'explains how to fix a missing htmlbeautifier gem' do
    allow(described_class).to receive(:require).with('htmlbeautifier').and_raise(LoadError, 'cannot load such file')
    expect { described_class.new(->(_env) { }) }.to raise_error(LoadError, /Add `gem 'htmlbeautifier'` to your Gemfile/)
  end
end
