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
  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['bug_tracker_uri'] = "#{spec.homepage}/issues"
  spec.metadata['rubygems_mfa_required'] = 'true'

  # C extension. RubyGems compiles it on install and places ruby2html.so into
  # the require path (lib/gem/ruby2html/), where render.rb's
  # `require 'ruby2html/ruby2html'` finds it. On JRuby extconf.rb writes a no-op
  # Makefile and the pure-Ruby implementation is used.
  spec.extensions = ['ext/ruby2html/extconf.rb']

  # Ship only the gem library and the extension sources. The repository root is
  # also a Rails demo app, so never glob all of lib/ (lib/assets, lib/tasks,
  # and the locally compiled lib/ruby2html/ruby2html.so must stay out).
  root = __dir__
  spec.files = Dir.chdir(root) do
    Dir.glob(%w[lib/gem/**/*.rb ext/ruby2html/*.{c,h,rb}]) +
      %w[README.md LICENSE CHANGELOG.md].select { |f| File.file?(f) }
  end.sort

  # lib/gem holds the Ruby code and receives the compiled extension on install.
  # (A checkout's `rake compile` output in lib/ruby2html is found by render.rb
  # via require_relative, so lib itself need not be a require path.)
  spec.require_paths = ['lib/gem']

  # No runtime dependencies. htmlbeautifier is optional: only
  # Ruby2html::HtmlBeautifierMiddleware needs it, and it requires it lazily.
end
