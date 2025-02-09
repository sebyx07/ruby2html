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

create_makefile(extension_name)
