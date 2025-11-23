#ifndef TAG_RENDER_H
#define TAG_RENDER_H

#include "ruby2html.h"

VALUE fast_buffer_append(VALUE self, VALUE buffer, VALUE str);
VALUE fast_render_tag(VALUE self, VALUE tag_name, VALUE attrs, VALUE content, VALUE is_void, VALUE escape_content);
VALUE fast_render_tag_cached_attrs(VALUE self, VALUE tag_name, VALUE cached_attrs_str, VALUE content, VALUE is_void, VALUE escape_content);

#endif
