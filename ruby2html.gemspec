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

  # Two builds. On CRuby/TruffleRuby the C extension is compiled on install and
  # ruby2html.so lands on the require path (lib/gem/ruby2html/), where
  # render.rb's `require 'ruby2html/ruby2html'` finds it (TruffleRuby's
  # extconf.rb then no-ops it: pure Ruby is faster there). On JRuby a `-java`
  # platform gem instead ships the prebuilt Java escaper jar
  # (lib/gem/ruby2html/ruby2html_jruby.jar), the only native code JRuby runs;
  # tag/attribute logic stays pure Ruby. `gem build` on JRuby (RUBY_PLATFORM
  # 'java') produces that gem; anywhere else, the C-extension gem.
  # The gemspec is loaded on every rake run (Bundler), including the `rake
  # compile` that builds the jar, so it must never raise when the jar is
  # absent. bin/gem-smoke enforces that a *built* -java gem actually ships it.
  jar = 'lib/gem/ruby2html/ruby2html_jruby.jar'
  if RUBY_PLATFORM == 'java'
    spec.platform = 'java'
  else
    spec.extensions = ['ext/ruby2html/extconf.rb']
  end

  # Ship only the gem library and the extension sources. The repository root is
  # also a Rails demo app, so never glob all of lib/ (lib/assets, lib/tasks,
  # and the locally compiled lib/ruby2html/ruby2html.so must stay out).
  root = __dir__
  spec.files = Dir.chdir(root) do
    files = Dir.glob(%w[lib/gem/**/*.rb ext/ruby2html/*.{c,h,rb} ext/java/*.java]) +
            %w[README.md LICENSE CHANGELOG.md].select { |f| File.file?(f) }
    files << jar if RUBY_PLATFORM == 'java' && File.file?(jar) # the prebuilt escaper, shipped in the -java gem
    files
  end.sort

  # lib/gem holds the Ruby code and receives the compiled extension on install.
  # (A checkout's `rake compile` output in lib/ruby2html is found by render.rb
  # via require_relative, so lib itself need not be a require path.)
  spec.require_paths = ['lib/gem']

  # No runtime dependencies. htmlbeautifier is optional: only
  # Ruby2html::HtmlBeautifierMiddleware needs it, and it requires it lazily.
end
