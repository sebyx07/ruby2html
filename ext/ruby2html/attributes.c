// ext/ruby2html/attributes.c
#include "attributes.h"
#include "html_escape.h"

// Context struct for rb_hash_foreach callback
typedef struct {
    VALUE result;
    VALUE self;
} attr_context_t;

// Callback for rb_hash_foreach - builds attribute string
static int build_attribute(VALUE key, VALUE value, VALUE arg) {
    if (NIL_P(value)) return ST_CONTINUE;

    attr_context_t *ctx = (attr_context_t *)arg;

    rb_str_cat2(ctx->result, " ");
    rb_str_append(ctx->result, rb_String(key));
    rb_str_cat2(ctx->result, "=\"");
    rb_str_append(ctx->result, fast_escape_html(ctx->self, rb_String(value)));
    rb_str_cat2(ctx->result, "\"");

    return ST_CONTINUE;
}

// Fast attribute string builder with caching
VALUE fast_attributes_to_s(VALUE self, VALUE hash) {
    if (NIL_P(hash) || RHASH_EMPTY_P(hash)) return rb_str_new2("");

    // Check Ruby-level cache (Ruby2html::ATTRIBUTE_CACHE)
    VALUE cache_class = rb_const_get(rb_const_get(rb_cObject, rb_intern("Ruby2html")), rb_intern("ATTRIBUTE_CACHE"));
    VALUE hash_key = rb_funcall(hash, rb_intern("hash"), 0);
    VALUE cached = rb_hash_aref(cache_class, hash_key);

    if (!NIL_P(cached)) {
        return cached; // Return frozen cached string
    }

    // Not in cache - generate attributes
    size_t hash_size = (size_t)RHASH_SIZE(hash);
    VALUE result = rb_str_buf_new(hash_size * 32);

    attr_context_t ctx = {
        .result = result,
        .self = self
    };

    rb_hash_foreach(hash, build_attribute, (VALUE)&ctx);

    // Cache the result (frozen) - ensure UTF-8 encoding
    rb_enc_associate(result, rb_utf8_encoding());
    VALUE frozen_result = rb_str_freeze(result);
    rb_hash_aset(cache_class, hash_key, frozen_result);

    return frozen_result;
}
