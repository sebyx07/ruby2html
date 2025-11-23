# frozen_string_literal: true

# ext/ruby2html/extconf.rb
require 'mkmf'

# Add optimization flags
$CFLAGS << ' -O3 -Wall -Wextra'

# Check for required headers
have_header('ruby.h')
have_header('ruby/encoding.h')

extension_name = 'ruby2html/ruby2html'
dir_config(extension_name)

# Add all source files
$srcs = ['ruby2html.c', 'html_escape.c', 'attributes.c', 'tag_render.c']
$objs = $srcs.map { |src| src.sub(/\.c$/, '.o') }

create_makefile(extension_name)
