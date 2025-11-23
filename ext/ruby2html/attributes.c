// ext/ruby2html/attributes.c
#include "attributes.h"
#include "html_escape.h"

// Fast attribute string builder
VALUE fast_attributes_to_s(VALUE self, VALUE hash) {
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
