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

    /*
     * escape_html, plain and component touch no shared mutable state, so they
     * may run in any Ractor (the tag methods are defined after Init, outside
     * this scope, and are callable from any Ractor already). define_tag
     * writes the shared tag table: main Ractor only.
     */
#ifdef HAVE_RB_EXT_RACTOR_SAFE
    rb_ext_ractor_safe(true);
#endif
    r2h_init_escape(native);
    r2h_init_content(native);
#ifdef HAVE_RB_EXT_RACTOR_SAFE
    rb_ext_ractor_safe(false);
#endif
    r2h_init_tags(native);
}
