# frozen_string_literal: true

# Escaping throughput for short/medium/long, clean/dirty strings.
#
#   bundle exec ruby bench/escape_bench.rb
#   RUBY2HTML_NO_SIMD=1 bundle exec rake compile   # then rerun for the scalar path
#
# Two measurements per input, 100 calls per iteration:
# * append: `plain` into a renderer buffer (what tag content does). The
#   buffer is cleared per iteration, so long rows include its regrowth.
# * escape_html: Ruby2html.escape_html, which returns a frozen input untouched
#   when it is clean, so the clean rows isolate the scan.

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require_relative '../lib/gem/ruby2html'
require 'benchmark/ips'

base = 'The quick brown fox jumps over the lazy dog. '
dirty = 'Tom & Jerry say "<hi>" it\'s fine. '
inputs = {
  'short clean (10B)' => 'hello worl',
  'short dirty (10B)' => 'a < b & c.',
  'medium clean (200B)' => (base * 5)[0, 200],
  'medium dirty (200B)' => ((base * 2) + dirty + (base * 2))[0, 200],
  'long clean (10KB)' => base * 228,
  'long dirty (10KB)' => (base + dirty) * 128
}

inputs.transform_values!(&:freeze)

renderer = Ruby2html::Render.new
buffer = renderer.current_output
puts "ruby2html=#{Ruby2html::IMPLEMENTATION}"

Benchmark.ips do |x|
  x.config(time: Float(ENV.fetch('BENCH_TIME', 2)), warmup: 0.5)
  inputs.each do |label, str|
    x.report("append #{label}") do
      buffer.clear
      i = 0
      while i < 100
        renderer.plain(str)
        i += 1
      end
    end
    x.report("escape_html #{label}") do
      i = 0
      while i < 100
        Ruby2html.escape_html(str)
        i += 1
      end
    end
  end
end
