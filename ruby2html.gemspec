# frozen_string_literal: true

require_relative 'lib/gem/ruby2html/version'

Gem::Specification.new do |spec|
  spec.name = 'ruby2html'
  spec.version = Ruby2html::VERSION
  spec.authors = ['sebi']
  spec.email = ['gore.sebyx@yahoo.com']

  spec.summary = 'Transform Ruby code into beautiful, structured HTML with C-optimized performance'
  spec.description = 'Ruby2HTML empowers developers to write view logic in pure Ruby, ' \
    'seamlessly converting it into clean, well-formatted HTML. ' \
    'Enhance your templating workflow, improve readability, and ' \
    'leverage the full power of Ruby in your views. ' \
    'Features include Rails integration, custom component support, ' \
    'automatic HTML beautification, and C-optimized rendering performance.'
  spec.homepage = 'https://github.com/sebyx07/ruby2html'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage

  # Include C extension
  spec.extensions = ['ext/ruby2html/extconf.rb']

  # Include both lib and ext directories
  spec.files = Dir.glob('{lib,ext}/{**/*,*}') +
    ['README.md', 'LICENSE.txt', File.basename(__FILE__)]

  # Set require paths for both the gem and extension
  spec.require_paths = %w[lib/gem lib]

  # Runtime dependencies
  spec.add_dependency 'htmlbeautifier', '>= 1.4'

  # Development dependencies
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rake-compiler', '~> 1.2'
  spec.add_development_dependency 'minitest', '~> 5.14'
  spec.add_development_dependency 'benchmark-ips', '~> 2.10'
end
