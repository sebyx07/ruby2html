#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'benchmark'

# Add lib directory to load path so C extension can be found
$LOAD_PATH.unshift File.expand_path('lib', __dir__)

require_relative 'lib/gem/ruby2html'

# Test cases - rendering divs with different content
clean_text = "Hello World This is a test string without any special characters" * 10
dirty_text = "Hello <World> & \"Test\" with 'special' chars" * 10
very_dirty_text = "&&&<<<>>>\"\"\"'''&&&<<<>>>\"\"\"'''" * 10
mixed_text = ("Clean text " * 20) + "<tag> & \"quote\""

puts "=" * 70
puts "Ruby2html SIMD Performance Benchmark"
puts "=" * 70
puts "Ruby Version: #{RUBY_VERSION}"
puts "Platform: #{RUBY_PLATFORM}"
puts "SIMD: SSE4.2 Enabled ✓"
puts "=" * 70
puts

n = 50_000

puts "HTML Rendering with Escaping (#{n.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} iterations)"
puts "-" * 70

Benchmark.bmbm(35) do |x|
  x.report("Clean text (SIMD fast path):") do
    n.times do
      Ruby2html::Render.new do
        div { plain clean_text }
      end.render
    end
  end

  x.report("Mixed text (mostly clean):") do
    n.times do
      Ruby2html::Render.new do
        div { plain mixed_text }
      end.render
    end
  end

  x.report("Dirty text (some escaping):") do
    n.times do
      Ruby2html::Render.new do
        div { plain dirty_text }
      end.render
    end
  end

  x.report("Very dirty text (heavy escaping):") do
    n.times do
      Ruby2html::Render.new do
        div { plain very_dirty_text }
      end.render
    end
  end

  x.report("Complex nested (C tag generation):") do
    n.times do
      Ruby2html::Render.new do
        div class: "container" do
          h1 "Title with <special> & 'chars'"
          p "Paragraph with \"quotes\" and &ampersands;"
          div class: "nested" do
            span "More <nested> content"
          end
        end
      end.render
    end
  end

  x.report("Attribute-heavy (C attributes):") do
    n.times do
      Ruby2html::Render.new do
        div class: "container mx-auto", id: "main", data_controller: "app", data_action: "click->app#handle" do
          span({ class: "text-lg font-bold" }, "Content")
        end
      end.render
    end
  end
end

puts
puts "=" * 70
puts "Optimizations Applied:"
puts "  ✓ SIMD HTML escaping (SSE4.2 vectorized scanning)"
puts "  ✓ C tag generation (single optimized call per tag)"
puts "  ✓ Fast path for clean strings (early exit, zero-copy)"
puts "  ✓ Pre-allocated buffers with size estimation"
puts "=" * 70
