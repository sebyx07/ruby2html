# frozen_string_literal: true

require 'cgi'
require 'stringio'
require 'htmlbeautifier'

Dir.glob(File.join(File.dirname(__FILE__), 'ruby2html', '**', '*.rb')).each do |file|
  require file
end

module Ruby2html
  class Error < StandardError; end
end
