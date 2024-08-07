# frozen_string_literal: true

require_relative 'lib/gem/ruby2html/version'

Gem::Specification.new do |spec|
  spec.name = 'ruby2html'
  spec.version = Ruby2html::VERSION
  spec.authors = ['sebi']
  spec.email = ['gore.sebyx@yahoo.com']

  spec.summary = 'Transform Ruby code into beautiful, structured HTML'
  spec.description = 'Ruby2HTML empowers developers to write view logic in pure Ruby, ' \
    'seamlessly converting it into clean, well-formatted HTML. ' \
    'Enhance your templating workflow, improve readability, and ' \
    'leverage the full power of Ruby in your views. ' \
    'Features include Rails integration, custom component support, ' \
    'and automatic HTML beautification.'
  spec.homepage = 'https://github.com/sebyx07/ruby2html'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.require_paths = ['lib/gem']
end
