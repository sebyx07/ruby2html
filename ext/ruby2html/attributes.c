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

// Fast attribute string builder using direct hash iteration
VALUE fast_attributes_to_s(VALUE self, VALUE hash) {
    if (NIL_P(hash) || RHASH_EMPTY_P(hash)) return rb_str_new2("");

    // Estimate size based on hash size
    size_t hash_size = (size_t)RHASH_SIZE(hash);
    VALUE result = rb_str_buf_new(hash_size * 32); // ~32 bytes per attribute average

    // Set up context for callback
    attr_context_t ctx = {
        .result = result,
        .self = self
    };

    // Direct hash iteration - no array allocation needed
    rb_hash_foreach(hash, build_attribute, (VALUE)&ctx);

    return result;
}
