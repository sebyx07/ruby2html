# frozen_string_literal: true

# ext/ruby2html/extconf.rb
require 'mkmf'

# Add optimization flags
$CFLAGS << ' -O3 -Wall -Wextra'

# Enable SSE4.2 if supported (for SIMD HTML escaping)
# Check if we're on x86_64 and can use SSE4.2
if RUBY_PLATFORM.match?(/x86_64|amd64/i)
  # Try to compile a test program with SSE4.2
  if try_compile('#include <nmmintrin.h>
                  int main() { __m128i a; return 0; }',
                 '-msse4.2')
    $CFLAGS << ' -msse4.2'
    puts 'SSE4.2 support enabled for faster HTML escaping'
  else
    puts 'SSE4.2 not available, using scalar implementation'
  end
end

# Check for required headers
have_header('ruby.h')
have_header('ruby/encoding.h')

extension_name = 'ruby2html/ruby2html'
dir_config(extension_name)

# Add all source files
$srcs = ['ruby2html.c', 'html_escape.c', 'attributes.c', 'tag_render.c']
$objs = $srcs.map { |src| src.sub(/\.c$/, '.o') }

create_makefile(extension_name)
