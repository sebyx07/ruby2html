# frozen_string_literal: true

require_relative 'config/application'
require 'rake/extensiontask'
require 'rake/testtask'

# Load Rails tasks
Rails.application.load_tasks

# Add C extension compilation task
Rake::ExtensionTask.new('ruby2html') do |ext|
  ext.lib_dir = 'lib/ruby2html'
  ext.ext_dir = 'ext/ruby2html'
end

task build: :compile
