# frozen_string_literal: true

# This Rakefile serves both the ruby2html gem and the Rails demo app around it.
#
# Gem tasks (compile, spec*, bench, build, install, release, smoke) do not boot
# Rails, so packaging works without a database or the demo app's gems loading.
# Any other task (db:*, assets:*, test, ...) loads the Rails tasks as usual.
# Set RUBY2HTML_RAILS_TASKS=1 to force loading the Rails tasks. With
# BUNDLE_GEMFILE=gemfiles/standalone.gemfile (no Rails) they are never loaded.
#
#   rake                  # quick check: compile + spec:gem
#   rake spec:standalone  # gem specs without Rails (runs on JRuby/TruffleRuby too)

require 'rake/clean'

GEM_TASK = /\A(default|compile(:.*)?|clean|clobber|spec(:gem|:standalone)?|bench|smoke|build(:.*)?|install(:.*)?|release(:.*)?)\z/

requested = Rake.application.top_level_tasks.map { |t| t.split('[').first }
listing = Rake.application.options.show_tasks || Rake.application.options.show_prereqs # rake -T / -D / -W / -P
rails_tasks = ENV['RUBY2HTML_RAILS_TASKS'] == '1' || listing || !requested.all? { |t| t.match?(GEM_TASK) }
rails_tasks = false if File.basename(ENV['BUNDLE_GEMFILE'].to_s) == 'standalone.gemfile'

if rails_tasks
  require_relative 'config/application'
  Rails.application.load_tasks
end

# --- C extension -------------------------------------------------------------
# Compiles ext/ruby2html into lib/ruby2html/ruby2html.so (render.rb falls back
# to that path in a checkout); an installed gem gets it in lib/gem/ruby2html/.
# Strict/clang/sanitizer variants: bin/build-ext --help
if RUBY_ENGINE == 'jruby'
  # JRuby can't load the C extension, but it builds a tiny Java one: the HTML
  # escaper (ext/java), the renderer's hot path. Everything else stays pure
  # Ruby. Output: lib/gem/ruby2html/ruby2html_jruby.jar (on the require path in
  # a checkout and in the -java gem). render.rb requires 'ruby2html/ruby2html_jruby'.
  begin
    require 'rake/javaextensiontask'
    Rake::JavaExtensionTask.new('ruby2html_jruby') do |ext|
      ext.lib_dir = 'lib/gem/ruby2html'
      ext.ext_dir = 'ext/java'
      ext.tmp_dir = 'tmp/ext'
      ext.source_version = '8'
      ext.target_version = '8'
    end
  rescue LoadError
    desc 'Compile the Java extension (requires rake-compiler)'
    task(:compile) { abort 'rake-compiler is not installed: bundle install' }
  end
else
  begin
    require 'rake/extensiontask'
    Rake::ExtensionTask.new('ruby2html') do |ext|
      ext.lib_dir = 'lib/ruby2html'
      ext.ext_dir = 'ext/ruby2html'
      # Build in tmp/ext, not tmp/: `rake clobber` removes the tmp dir, and tmp/ holds the demo
      # app's tracked .keep files.
      ext.tmp_dir = 'tmp/ext'
    end
  rescue LoadError
    desc 'Compile the C extension (requires rake-compiler)'
    task(:compile) { abort 'rake-compiler is not installed: bundle install' }
  end
end

# --- Packaging (build / install / release into pkg/) ----------------------------
# Building a source gem does not need a compiled extension or a Rails boot.
require 'bundler/gem_helper'
Bundler::GemHelper.install_tasks(name: 'ruby2html')
CLOBBER.include('pkg')

desc 'Build the gem, install it into a temporary GEM_HOME and render HTML without Rails'
task smoke: :build do
  ruby File.expand_path('bin/gem-smoke', __dir__), Dir['pkg/ruby2html-*.gem'].max_by { |f| File.mtime(f) }
end

# --- Specs -------------------------------------------------------------------
# With the Rails tasks loaded, rspec-rails already defines `spec`.
begin
  require 'rspec/core/rake_task'
rescue LoadError
  nil
end
unless Rake::Task.task_defined?(:spec)
  if defined?(RSpec::Core::RakeTask)
    RSpec::Core::RakeTask.new(:spec)
  else
    task(:spec) { abort 'rspec is not installed: bundle install' }
  end
end
Rake::Task[:spec].enhance([:compile]) unless ENV['SKIP_COMPILE'] == '1'

if defined?(RSpec::Core::RakeTask)
  namespace :spec do
    desc 'Run the gem unit specs (spec/gem)'
    RSpec::Core::RakeTask.new(:gem) { |t| t.pattern = 'spec/gem/**/*_spec.rb' }

    desc 'Run the gem specs that need no Rails (spec/gem minus spec/gem/rails); RUBY2HTML_DISABLE_EXT=1 for pure Ruby'
    RSpec::Core::RakeTask.new(:standalone) do |t|
      t.pattern = 'spec/gem/**/*_spec.rb'
      t.exclude_pattern = 'spec/gem/rails/**/*_spec.rb'
      t.rspec_opts = '-I lib/gem -I lib --require ruby2html'
    end
  end
  %w[spec:gem spec:standalone].each { |t| Rake::Task[t].enhance([:compile]) } unless ENV['SKIP_COMPILE'] == '1'
end

# --- Benchmarks ----------------------------------------------------------------
desc 'Run every bench/*.rb script (compiles the extension first)'
task bench: :compile do
  scripts = Dir['bench/*.rb'].sort
  if scripts.empty?
    puts 'No bench/*.rb scripts found. Request benchmarks: bundle exec rspec spec/benchmarks/'
  else
    scripts.each do |script|
      puts "== #{script}"
      ruby '-Ilib/gem', '-Ilib', script
    end
  end
end

# Quick and useful: compile + the gem specs (no request benchmarks).
task default: 'spec:gem' unless rails_tasks
