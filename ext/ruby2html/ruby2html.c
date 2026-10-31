/*
 * Native renderer core. Defines Ruby2html::Native, a module of instance
 * methods (tag methods, plain, component) that Ruby2html::Render includes.
 * Ruby2html::PureRuby (lib/gem/ruby2html/render/pure_ruby.rb) mirrors it.
 */
#include "ruby2html.h"

RUBY_FUNC_EXPORTED void Init_ruby2html(void)
{
    VALUE ruby2html = rb_define_module("Ruby2html");
    VALUE native = rb_define_module_under(ruby2html, "Native");

    r2h_init_escape(native);
    r2h_init_content(native);
    r2h_init_tags(native);
}
