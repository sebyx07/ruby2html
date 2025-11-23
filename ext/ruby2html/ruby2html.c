// ext/ruby2html/ruby2html.c
#include "ruby2html.h"
#include "html_escape.h"
#include "attributes.h"
#include "tag_render.h"

VALUE rb_mRuby2html;
VALUE rb_cRenderer;

void Init_ruby2html(void) {
    rb_mRuby2html = rb_define_module("Ruby2html");

    rb_cRenderer = rb_define_class_under(rb_mRuby2html, "Render", rb_cObject);

    rb_define_method(rb_cRenderer, "fast_escape_html", fast_escape_html, 1);
    rb_define_method(rb_cRenderer, "fast_attributes_to_s", fast_attributes_to_s, 1);
    rb_define_method(rb_cRenderer, "fast_buffer_append", fast_buffer_append, 2);
    rb_define_method(rb_cRenderer, "fast_render_tag", fast_render_tag, 5);
}
