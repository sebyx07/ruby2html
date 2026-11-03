#ifndef RUBY2HTML_H
#define RUBY2HTML_H

#include <ruby.h>
#include <ruby/encoding.h>

/* Interned at Init so hot paths never call rb_intern. */
extern ID r2h_id_current_output;
extern ID r2h_id_html_safe_p;

/* html_escape.c */
void r2h_init_escape(VALUE native);
VALUE r2h_utf8_compatible(VALUE str);
void r2h_append_escaped(VALUE buf, VALUE str);
void r2h_append_escaped_wrapped(VALUE buf, const char *before, long before_len, VALUE str,
                                const char *after, long after_len);
void r2h_append_raw(VALUE buf, VALUE str);

/* attributes.c */
void r2h_append_attributes(VALUE buf, VALUE attrs);

/* content.c */
void r2h_init_content(VALUE native);
VALUE r2h_current_buffer(VALUE self);
void r2h_append_long(VALUE buf, long value);
void r2h_append_text(VALUE buf, VALUE obj);
void r2h_append_block_result(VALUE buf, VALUE result);

/* tag_render.c */
void r2h_init_tags(VALUE native);

#endif
