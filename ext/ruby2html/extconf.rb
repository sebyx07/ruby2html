# frozen_string_literal: true

# Builds Ruby2html::Native. When it can't or shouldn't be built, writes a
# Makefile that does nothing so `gem install` still succeeds; the gem then
# runs on its pure-Ruby renderer (see Ruby2html.native?).

def skip_native_extension(reason)
  warn "ruby2html: #{reason}; the pure-Ruby renderer will be used"
  File.write('Makefile', "all:\n\ninstall:\n\nclean:\n\ndistclean:\n")
  exit
end

skip_native_extension('RUBY2HTML_DISABLE_EXT=1') if ENV['RUBY2HTML_DISABLE_EXT'] == '1'
skip_native_extension('JRuby does not load C extensions') if RUBY_ENGINE == 'jruby'

require 'mkmf'

skip_native_extension('no working C compiler') unless try_compile('int main(void) { return 0; }')

# append_cflags keeps only flags the compiler accepts, so this works on gcc
# and clang, Linux and macOS. No -march=native: the built gem may be copied
# to another machine (Docker images). SIMD needs no flags: SSE2 is baseline
# on x86_64 and NEON on arm64.
append_cflags(%w[-O3 -std=gnu99 -fvisibility=hidden -Wall -Wextra -Wno-unused-parameter])
# Direct calls into libruby instead of PLT stubs (ELF only).
append_cflags('-fno-plt') if RbConfig::CONFIG['host_os'].include?('linux')
# Scalar escape path, for benchmarking: RUBY2HTML_NO_SIMD=1 rake compile
append_cflags('-DR2H_NO_SIMD') if ENV['RUBY2HTML_NO_SIMD'] == '1'

skip_native_extension('ruby/encoding.h not found') unless have_header('ruby/encoding.h')

# CRuby is the reference platform, so a broken build there should fail
# loudly. Elsewhere (TruffleRuby, ...) compile every source first and fall
# back if any of them doesn't build.
unless RUBY_ENGINE == 'ruby'
  Dir.glob(File.join(__dir__, '*.c')).each do |source|
    next if try_compile(File.read(source), "-I#{__dir__}")

    skip_native_extension("#{File.basename(source)} does not compile on #{RUBY_ENGINE}")
  end
end

create_makefile('ruby2html/ruby2html')
