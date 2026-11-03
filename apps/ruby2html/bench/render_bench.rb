# frozen_string_literal: true

# Standalone render benchmark (no Rails): ruby2html vs Phlex vs Erubi.
#
#   bundle exec ruby bench/render_bench.rb            # interpreter
#   bundle exec ruby --yjit bench/render_bench.rb     # YJIT
#   RUBY2HTML_DISABLE_EXT=1 bundle exec ruby bench/render_bench.rb   # pure-Ruby fallback
#   BENCH_TIME=5 ...                                  # seconds per ips run
#
# Every engine renders the same page from the same pre-built data, so the
# allocation counts below are the engine's own allocations per render.

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require_relative '../lib/gem/ruby2html'
require 'benchmark/ips'
require 'erubi'
require 'phlex'

module Bench
  ITEMS = Array.new(100) do |i|
    {
      id: "item-#{i}",
      href: "/products/#{i}?ref=list&page=#{i / 10}",
      title: "Product #{i} <limited> & \"special\"",
      body: "Description for product #{i}. It's great: 5 > 4 & 3 < 4.",
      price: "$#{i * 3}.99",
      image: "/images/#{i}.png"
    }
  end.freeze

  NAV = Array.new(5) { |i| { href: "/section/#{i}", label: "Section #{i}" } }.freeze

  def self.ruby2html_page
    Ruby2html::Render.new(nil) do
      div class: 'container' do
        header class: 'site-header' do
          h1 'Store & <Catalog>'
          nav do
            ul class: 'nav' do
              NAV.each { |link| li { a link[:label], href: link[:href], class: 'nav-link' } }
            end
          end
        end
        main id: 'content' do
          ul class: 'items' do
            ITEMS.each do |item|
              li class: 'item', id: item[:id] do
                a href: item[:href] do
                  img src: item[:image], alt: item[:title]
                  h2 item[:title]
                end
                p item[:body]
                span item[:price], class: 'price'
              end
            end
          end
        end
        footer { p 'Copyright 2026' }
      end
    end.render
  end

  class PhlexPage < Phlex::HTML
    def view_template
      div class: 'container' do
        header class: 'site-header' do
          h1 { 'Store & <Catalog>' }
          nav do
            ul class: 'nav' do
              NAV.each { |link| li { a(href: link[:href], class: 'nav-link') { link[:label] } } }
            end
          end
        end
        main id: 'content' do
          ul class: 'items' do
            ITEMS.each do |item|
              li class: 'item', id: item[:id] do
                a href: item[:href] do
                  img src: item[:image], alt: item[:title]
                  h2 { item[:title] }
                end
                p { item[:body] }
                span(class: 'price') { item[:price] }
              end
            end
          end
        end
        footer { p { 'Copyright 2026' } }
      end
    end
  end

  ERB_SOURCE = <<~'ERB'
    <div class="container"><header class="site-header"><h1><%= 'Store & <Catalog>' %></h1><nav><ul class="nav"><% NAV.each do |link| %><li><a href="<%= link[:href] %>" class="nav-link"><%= link[:label] %></a></li><% end %></ul></nav></header><main id="content"><ul class="items"><% ITEMS.each do |item| %><li class="item" id="<%= item[:id] %>"><a href="<%= item[:href] %>"><img src="<%= item[:image] %>" alt="<%= item[:title] %>" /><h2><%= item[:title] %></h2></a><p><%= item[:body] %></p><span class="price"><%= item[:price] %></span></li><% end %></ul></main><footer><p>Copyright 2026</p></footer></div>
  ERB

  require 'cgi/escape'
  class_eval <<~RUBY, __FILE__, __LINE__ + 1
    def self.erubi_page
      #{Erubi::Engine.new(ERB_SOURCE, escape: true, escapefunc: 'CGI.escapeHTML').src}
    end
  RUBY

  def self.allocations_per_call(iterations = 200, &block)
    block.call
    GC.start
    GC.disable
    before = GC.stat(:total_allocated_objects)
    iterations.times { block.call }
    (GC.stat(:total_allocated_objects) - before) / iterations.to_f
  ensure
    GC.enable
  end
end

impl = defined?(Ruby2html::IMPLEMENTATION) ? Ruby2html::IMPLEMENTATION : 'legacy (1.x)'
puts "Ruby #{RUBY_VERSION} yjit=#{defined?(RubyVM::YJIT) ? RubyVM::YJIT.enabled? : "unavailable"} ruby2html=#{impl}"
puts "page size: #{Bench.ruby2html_page.bytesize} bytes (phlex: #{Bench::PhlexPage.new.call.bytesize})"

engines = {
  'ruby2html' => -> { Bench.ruby2html_page },
  'phlex' => -> { Bench::PhlexPage.new.call },
  'erubi' => -> { Bench.erubi_page }
}

puts "\nallocated objects per render:"
engines.each { |name, fn| puts format('  %-10s %8.1f', name, Bench.allocations_per_call(&fn)) }

time = Float(ENV.fetch('BENCH_TIME', 3))
Benchmark.ips do |x|
  x.config(time: time, warmup: 1)
  engines.each { |name, fn| x.report(name, &fn) }
  x.compare!
end
