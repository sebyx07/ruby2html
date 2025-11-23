// ext/ruby2html/tag_render.c
#include "tag_render.h"
#include "attributes.h"
#include "html_escape.h"

// Fast string buffer concatenation
VALUE fast_buffer_append(VALUE self, VALUE buffer, VALUE str) {
    if (!NIL_P(str)) {
        rb_funcall(buffer, rb_intern("<<"), 1, rb_String(str));
    }
    return Qnil;
}

// Fast complete tag rendering
VALUE fast_render_tag(VALUE self, VALUE tag_name, VALUE attrs, VALUE content, VALUE is_void, VALUE escape_content) {
    const char *tag = StringValueCStr(tag_name);
    long tag_len = strlen(tag);
    int void_element = RTEST(is_void);
    int should_escape = RTEST(escape_content);

    // Estimate buffer size
    long estimated_size = tag_len * 2 + 5; // <tag></tag>

    // Get attributes string
    VALUE attrs_str = fast_attributes_to_s(self, attrs);
    long attrs_len = RSTRING_LEN(attrs_str);
    estimated_size += attrs_len;

    // Handle content
    VALUE content_str = Qnil;
    long content_len = 0;
    if (!NIL_P(content)) {
        if (should_escape) {
            content_str = fast_escape_html(self, rb_String(content));
        } else {
            content_str = rb_String(content);
        }
        content_len = RSTRING_LEN(content_str);
        estimated_size += content_len;
    }

    // Allocate result buffer
    VALUE result = rb_str_buf_new(estimated_size);

    // Build opening tag
    rb_str_cat2(result, "<");
    rb_str_cat(result, tag, tag_len);

    // Add attributes
    if (attrs_len > 0) {
        rb_str_append(result, attrs_str);
    }

    if (void_element) {
        // Self-closing tag
        rb_str_cat2(result, " />");
    } else {
        // Regular tag with content
        rb_str_cat2(result, ">");

        // Add content if present
        if (!NIL_P(content_str)) {
            rb_str_append(result, content_str);
        }

        // Closing tag
        rb_str_cat2(result, "</");
        rb_str_cat(result, tag, tag_len);
        rb_str_cat2(result, ">");
    }

    return result;
}
