// ext/ruby2html/ruby2html.c
#include <ruby.h>
#include <ruby/encoding.h>
#include <ctype.h>

static VALUE rb_mRuby2html;
static VALUE rb_cRenderer;

// Fast HTML escaping
static VALUE fast_escape_html(VALUE self, VALUE str) {
    if (NIL_P(str)) return Qnil;

    str = rb_String(str);
    long len = RSTRING_LEN(str);
    const char *ptr = RSTRING_PTR(str);

    // First pass: calculate required buffer size
    long new_len = len;
    for (long i = 0; i < len; i++) {
        switch (ptr[i]) {
            case '&': new_len += 4; break; // &amp;
            case '<': new_len += 3; break; // &lt;
            case '>': new_len += 3; break; // &gt;
            case '"': new_len += 5; break; // &quot;
            case '\'': new_len += 5; break; // &#39;
        }
    }

    if (new_len == len) return str;

    VALUE result = rb_str_new(NULL, new_len);
    char *out = RSTRING_PTR(result);
    long pos = 0;

    // Second pass: actual escaping
    for (long i = 0; i < len; i++) {
        switch (ptr[i]) {
            case '&':
                memcpy(out + pos, "&amp;", 5);
                pos += 5;
                break;
            case '<':
                memcpy(out + pos, "&lt;", 4);
                pos += 4;
                break;
            case '>':
                memcpy(out + pos, "&gt;", 4);
                pos += 4;
                break;
            case '"':
                memcpy(out + pos, "&quot;", 6);
                pos += 6;
                break;
            case '\'':
                memcpy(out + pos, "&#39;", 5);
                pos += 5;
                break;
            default:
                out[pos++] = ptr[i];
        }
    }

    rb_str_set_len(result, pos);
    rb_enc_associate(result, rb_enc_get(str));
    return result;
}

// Fast attribute string builder
static VALUE fast_attributes_to_s(VALUE self, VALUE hash) {
    if (NIL_P(hash) || RHASH_EMPTY_P(hash)) return rb_str_new2("");

    VALUE result = rb_str_buf_new(64); // Pre-allocate with reasonable size
    VALUE keys = rb_funcall(hash, rb_intern("keys"), 0);
    long len = RARRAY_LEN(keys);

    for (long i = 0; i < len; i++) {
        VALUE key = rb_ary_entry(keys, i);
        VALUE value = rb_hash_aref(hash, key);

        if (!NIL_P(value)) {
            rb_str_cat2(result, " ");
            rb_str_append(result, rb_String(key));
            rb_str_cat2(result, "=\"");
            rb_str_append(result, fast_escape_html(self, rb_String(value)));
            rb_str_cat2(result, "\"");
        }
    }

    return result;
}

// Fast string buffer concatenation
static VALUE fast_buffer_append(VALUE self, VALUE buffer, VALUE str) {
    if (!NIL_P(str)) {
        rb_funcall(buffer, rb_intern("<<"), 1, rb_String(str));
    }
    return Qnil;
}

void Init_ruby2html(void) {
    rb_mRuby2html = rb_define_module("Ruby2html");

    rb_cRenderer = rb_define_class_under(rb_mRuby2html, "Render", rb_cObject);

    rb_define_method(rb_cRenderer, "fast_escape_html", fast_escape_html, 1);
    rb_define_method(rb_cRenderer, "fast_attributes_to_s", fast_attributes_to_s, 1);
    rb_define_method(rb_cRenderer, "fast_buffer_append", fast_buffer_append, 2);
}