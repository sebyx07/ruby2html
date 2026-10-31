/*
 * Attribute rendering, written straight into the output buffer.
 *
 *   nil                 -> omitted
 *   true / false        -> bare attribute / omitted; data-*, aria-* and the
 *                          enumerated draggable/spellcheck/contenteditable
 *                          get "true" / "false" because there the value matters
 *   Hash                -> expanded: data: { user_id: 1 } -> data-user-id="1"
 *   Array               -> space-separated tokens, nil/false skipped
 *   anything else       -> to_s, escaped
 *
 * Names are validated rather than escaped: a name containing quotes,
 * whitespace, = < > or / could inject markup, so it raises ArgumentError.
 * Nothing is cached: generating is cheaper than hashing the Hash for a cache
 * lookup, and a cache keyed by #hash can return another hash's attributes.
 */
#include "buffer.h"

/* Deeper nesting is a bug (or a self-referencing Hash/Array); refuse it
 * instead of recursing until the C stack overflows. */
#define R2H_MAX_NESTING 32

typedef struct {
    VALUE buf;
    VALUE prefix; /* name of the enclosing Hash attribute, or Qnil */
    int depth;
} attr_ctx;

static void check_nesting(int depth)
{
    if (depth > R2H_MAX_NESTING) rb_raise(rb_eArgError, "attributes nested more than %d levels deep", R2H_MAX_NESTING);
}

static int append_attribute(VALUE key, VALUE value, VALUE data);

static int is_invalid_name_byte(unsigned char c)
{
    return c <= ' ' || c == 0x7F || c == '"' || c == '\'' || c == '<' || c == '>' || c == '/' || c == '=';
}

static VALUE key_to_str(VALUE key)
{
    if (SYMBOL_P(key)) return rb_sym2str(key);
    if (RB_TYPE_P(key, T_STRING)) return key;
    return rb_obj_as_string(key);
}

/*
 * Writes ` name` (or ` prefix-name` with _ turned into -) and returns the
 * offset of the name within buf so callers can inspect or roll it back.
 */
/* Error path only: report the full name as written (`data-x onclick`), like PureRuby. */
NORETURN(static void raise_invalid_name(const attr_ctx *ctx, VALUE name));
static void raise_invalid_name(const attr_ctx *ctx, VALUE name)
{
    VALUE full = name;
    if (!NIL_P(ctx->prefix)) {
        VALUE dashed = rb_funcall(name, rb_intern("tr"), 2, rb_str_new_cstr("_"), rb_str_new_cstr("-"));
        full = rb_sprintf("%" PRIsVALUE "-%" PRIsVALUE, ctx->prefix, dashed);
    }
    rb_raise(rb_eArgError, "invalid attribute name: %+" PRIsVALUE, full);
}

static long append_name(const attr_ctx *ctx, VALUE key)
{
    VALUE name = r2h_utf8_compatible(key_to_str(key));
    if (name == ctx->buf) name = rb_str_dup(name); /* reserve below may move buf's bytes */
    const char *src = RSTRING_PTR(name);
    const long len = RSTRING_LEN(name);
    const int nested = !NIL_P(ctx->prefix);
    const long prefix_len = nested ? RSTRING_LEN(ctx->prefix) + 1 : 0;

    if (len == 0) rb_raise(rb_eArgError, "attribute name can't be empty");

    const long start = RSTRING_LEN(ctx->buf) + 1;
    char *out = r2h_buf_reserve(ctx->buf, 1 + prefix_len + len);
    *out++ = ' ';
    if (nested) {
        memcpy(out, RSTRING_PTR(ctx->prefix), (size_t)(prefix_len - 1));
        out += prefix_len - 1;
        *out++ = '-';
    }
    for (long i = 0; i < len; i++) {
        const unsigned char c = (unsigned char)src[i];
        if (is_invalid_name_byte(c)) {
            rb_str_set_len(ctx->buf, start - 1);
            raise_invalid_name(ctx, name);
        }
        *out++ = (nested && c == '_') ? '-' : (char)c;
    }
    r2h_buf_commit(ctx->buf, out);
    RB_GC_GUARD(name);
    return start;
}

static int has_prefix(const char *name, long len, const char *prefix, long prefix_len)
{
    return len >= prefix_len && memcmp(name, prefix, (size_t)prefix_len) == 0;
}

static int is_named(const char *name, long len, const char *word, long word_len)
{
    return len == word_len && memcmp(name, word, (size_t)word_len) == 0;
}

#define R2H_PREFIX(name, len, lit) has_prefix((name), (len), (lit), (long)(sizeof(lit) - 1))
#define R2H_NAMED(name, len, lit) is_named((name), (len), (lit), (long)(sizeof(lit) - 1))

/* Attributes whose true/false is a string value rather than presence. */
static int has_string_boolean(VALUE buf, long start)
{
    const char *name = RSTRING_PTR(buf) + start;
    const long len = RSTRING_LEN(buf) - start;

    return R2H_PREFIX(name, len, "data-") || R2H_PREFIX(name, len, "aria-") ||
        R2H_NAMED(name, len, "draggable") || R2H_NAMED(name, len, "spellcheck") ||
        R2H_NAMED(name, len, "contenteditable");
}

static void append_token_list(VALUE buf, VALUE tokens, int *first, int depth)
{
    check_nesting(depth);
    for (long i = 0; i < RARRAY_LEN(tokens); i++) {
        VALUE token = RARRAY_AREF(tokens, i);

        if (!RTEST(token)) continue;
        if (RB_TYPE_P(token, T_ARRAY)) {
            append_token_list(buf, token, first, depth + 1);
            continue;
        }
        if (!*first) R2H_BUF_CAT_LIT(buf, " ");
        *first = 0;
        r2h_append_escaped(buf, SYMBOL_P(token) ? rb_sym2str(token) : rb_obj_as_string(token));
    }
}

static void append_value(VALUE buf, VALUE value)
{
    R2H_BUF_CAT_LIT(buf, "=\"");
    switch (rb_type(value)) {
    case T_STRING:
        r2h_append_escaped(buf, value);
        break;
    case T_SYMBOL:
        r2h_append_escaped(buf, rb_sym2str(value));
        break;
    case T_FIXNUM:
        r2h_append_long(buf, FIX2LONG(value));
        break;
    case T_ARRAY: {
        int first = 1;
        append_token_list(buf, value, &first, 1);
        break;
    }
    default:
        r2h_append_escaped(buf, rb_obj_as_string(value));
    }
    R2H_BUF_CAT_LIT(buf, "\"");
}

static int append_attribute(VALUE key, VALUE value, VALUE data)
{
    const attr_ctx *ctx = (const attr_ctx *)data;
    VALUE buf = ctx->buf;

    if (NIL_P(value)) return ST_CONTINUE;

    const long start = append_name(ctx, key);

    switch (rb_type(value)) {
    case T_TRUE:
        if (has_string_boolean(buf, start)) R2H_BUF_CAT_LIT(buf, "=\"true\"");
        break;
    case T_FALSE:
        if (has_string_boolean(buf, start)) {
            R2H_BUF_CAT_LIT(buf, "=\"false\"");
        } else {
            rb_str_set_len(buf, start - 1);
        }
        break;
    case T_HASH: {
        /* The name just written becomes the prefix of the nested keys. */
        attr_ctx nested = { buf, rb_str_new(RSTRING_PTR(buf) + start, RSTRING_LEN(buf) - start), ctx->depth + 1 };
        rb_str_set_len(buf, start - 1);
        check_nesting(nested.depth);
        rb_hash_foreach(value, append_attribute, (VALUE)&nested);
        RB_GC_GUARD(nested.prefix);
        break;
    }
    default:
        append_value(buf, value);
    }
    return ST_CONTINUE;
}

void r2h_append_attributes(VALUE buf, VALUE attrs)
{
    attr_ctx ctx = { buf, Qnil, 0 };
    rb_hash_foreach(attrs, append_attribute, (VALUE)&ctx);
}
