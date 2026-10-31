# frozen_string_literal: true

# Per-tag cost for the common call shapes, 100 tags per iteration.
#
#   bundle exec ruby bench/tag_bench.rb

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require_relative '../lib/gem/ruby2html'
require 'benchmark/ips'

TEXT = 'Some list item text'
DIRTY = 'Tom & Jerry'
HREF = '/products/42?ref=list'

# Each root renders one shape 100 times in a plain while loop.
SHAPES = {
  'li(text)' => 'li TEXT',
  'li(dirty text)' => 'li DIRTY',
  'br' => 'br',
  'span(text, class:)' => "span TEXT, class: 'price'",
  'a(text, href:, class:)' => "a TEXT, href: HREF, class: 'nav-link'",
  'div { block }' => 'div { nil }',
  'div(class:) { block }' => "div(class: 'card') { nil }"
}.transform_values { |call| eval("proc { i = 0; while i < 100; #{call}; i += 1; end }", binding, __FILE__, __LINE__) }

puts "ruby2html=#{Ruby2html::IMPLEMENTATION}"
Benchmark.ips do |x|
  x.config(time: Float(ENV.fetch('BENCH_TIME', 2)), warmup: 0.5)
  SHAPES.each do |label, root|
    x.report(label) { Ruby2html::Render.new(&root).render }
  end
end
