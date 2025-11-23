// ext/ruby2html/html_escape.c
#include "html_escape.h"

// Fast HTML escaping
VALUE fast_escape_html(VALUE self, VALUE str) {
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
