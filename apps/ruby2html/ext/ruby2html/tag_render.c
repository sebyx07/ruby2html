/*
 * Tag methods (div, p, img, ...) implemented in C.
 *
 * Each tag is a C method, so a call costs no Ruby frame, no *args or **kwargs
 * allocation when called without keywords, and block content is rendered
 * straight into the shared buffer (open tag, yield, close tag) instead of
 * into a nested buffer that is copied afterwards.
 *
 * The tag list itself lives in Ruby (Render::HTML5_TAGS). A C method can't
 * carry data, so define_tag binds each tag to a slot of a fixed pool of
 * one-line trampolines, each of which passes its slot to render_tag.
 */
#include "buffer.h"

#define R2H_MAX_TAGS 200
#define R2H_MAX_TAG_NAME 32

typedef struct {
    char open[R2H_MAX_TAG_NAME + 5];  /* "<div>", or "<br />" for void tags, + NUL */
    char close[R2H_MAX_TAG_NAME + 4]; /* "</div>" + NUL */
    long open_len;
    long name_len; /* "<div" is open[0, name_len + 1) */
    long close_len;
    int is_void;
    ID method;
} r2h_tag;

static r2h_tag tags[R2H_MAX_TAGS];
static int tag_count;

typedef struct {
    VALUE buf;
    VALUE attrs;
} attrs_args;

static VALUE append_attributes_protected(VALUE data)
{
    const attrs_args *args = (const attrs_args *)data;
    r2h_append_attributes(args->buf, args->attrs);
    return Qnil;
}

static void open_tag(VALUE buf, const r2h_tag *tag, VALUE attrs)
{
    if (NIL_P(attrs)) {
        r2h_buf_cat(buf, tag->open, tag->open_len);
        return;
    }
    /*
     * If an attribute raises (invalid name, a value's to_s raising) and the
     * caller rescues, a half-written `<div class="x` would turn whatever is
     * appended next into markup. Roll the buffer back to before the tag.
     */
    const long mark = RSTRING_LEN(buf);
    r2h_buf_cat(buf, tag->open, tag->name_len + 1);
    attrs_args args = { buf, attrs };
    int state = 0;
    rb_protect(append_attributes_protected, (VALUE)&args, &state);
    if (state) {
        /*
         * rb_str_resize (not set_len): the failing to_s may have replaced,
         * shared or shrunk the buffer. Leave a frozen buffer alone so the
         * original exception propagates.
         */
        if (!OBJ_FROZEN(buf) && RSTRING_LEN(buf) >= mark) rb_str_resize(buf, mark);
        rb_jump_tag(state);
    }
    if (tag->is_void) {
        R2H_BUF_CAT_LIT(buf, " />");
    } else {
        R2H_BUF_CAT_LIT(buf, ">");
    }
}

/*
 * tag(content = nil, **attributes) { ... }
 *
 * With a block, the block's output is the content (content is ignored);
 * void tags ignore content and block.
 */
static VALUE render_tag(int argc, VALUE *argv, VALUE self, const r2h_tag *tag)
{
    VALUE attrs = Qnil, content = Qnil;

    if (argc > 0 && rb_keyword_given_p()) {
        attrs = argv[--argc];
        if (RHASH_EMPTY_P(attrs)) attrs = Qnil;
    }
    if (argc > 1) rb_error_arity(argc, 0, 1);
    if (argc == 1) content = argv[0];

    VALUE buf = r2h_current_buffer(self);
    const int block_given = rb_block_given_p();

    /* Fast path for the most common shape, `li "text"`: one buffer write. */
    if (NIL_P(attrs) && !block_given && !tag->is_void && RB_TYPE_P(content, T_STRING) &&
        RBASIC_CLASS(content) == rb_cString) {
        r2h_append_escaped_wrapped(buf, tag->open, tag->open_len, content, tag->close, tag->close_len);
        return Qnil;
    }

    open_tag(buf, tag, attrs);
    if (tag->is_void) return Qnil;

    if (block_given) {
        const long before = RSTRING_LEN(buf);
        VALUE result = rb_yield_values2(0, NULL);
        if (RSTRING_LEN(buf) == before) r2h_append_block_result(buf, result);
    } else {
        r2h_append_text(buf, content);
    }
    r2h_buf_cat(buf, tag->close, tag->close_len);
    RB_GC_GUARD(buf);
    return Qnil;
}

#define R2H_TRAMPOLINE(n) \
    static VALUE tag_##n(int argc, VALUE *argv, VALUE self) { return render_tag(argc, argv, self, &tags[n]); }
#define R2H_TRAMPOLINE_REF(n) tag_##n,
#define R2H_TEN(M, d) M(d##0) M(d##1) M(d##2) M(d##3) M(d##4) M(d##5) M(d##6) M(d##7) M(d##8) M(d##9)
#define R2H_TWO_HUNDRED(M) \
    R2H_TEN(M, ) R2H_TEN(M, 1) R2H_TEN(M, 2) R2H_TEN(M, 3) R2H_TEN(M, 4) R2H_TEN(M, 5) R2H_TEN(M, 6) \
    R2H_TEN(M, 7) R2H_TEN(M, 8) R2H_TEN(M, 9) R2H_TEN(M, 10) R2H_TEN(M, 11) R2H_TEN(M, 12) R2H_TEN(M, 13) \
    R2H_TEN(M, 14) R2H_TEN(M, 15) R2H_TEN(M, 16) R2H_TEN(M, 17) R2H_TEN(M, 18) R2H_TEN(M, 19)

R2H_TWO_HUNDRED(R2H_TRAMPOLINE)

typedef VALUE (*r2h_tag_fn)(int, VALUE *, VALUE);
static const r2h_tag_fn trampolines[R2H_MAX_TAGS] = { R2H_TWO_HUNDRED(R2H_TRAMPOLINE_REF) };

/* Tag names are written unescaped, so only allow [a-z0-9-]. */
static void validate_tag_name(VALUE name)
{
    const char *p = RSTRING_PTR(name);
    const long len = RSTRING_LEN(name);

    if (len == 0 || len > R2H_MAX_TAG_NAME) rb_raise(rb_eArgError, "invalid tag name: %+" PRIsVALUE, name);
    for (long i = 0; i < len; i++) {
        const char c = p[i];
        if (!((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-')) {
            rb_raise(rb_eArgError, "invalid tag name: %+" PRIsVALUE, name);
        }
    }
}

static r2h_tag *slot_for(ID method)
{
    for (int i = 0; i < tag_count; i++) {
        if (tags[i].method == method) return &tags[i];
    }
    if (tag_count == R2H_MAX_TAGS) rb_raise(rb_eRuntimeError, "ruby2html: more than %d tags", R2H_MAX_TAGS);
    return &tags[tag_count++];
}

/* Ruby2html::Native.define_tag(method_name, tag_name, void) */
static VALUE native_define_tag(VALUE native, VALUE method_name, VALUE tag_name, VALUE is_void)
{
    const ID method = rb_to_id(method_name);
    StringValue(tag_name);
    validate_tag_name(tag_name);

    r2h_tag *tag = slot_for(method);
    const long len = RSTRING_LEN(tag_name);
    tag->method = method;
    tag->is_void = RTEST(is_void);
    tag->name_len = len;
    tag->open_len = snprintf(tag->open, sizeof(tag->open), tag->is_void ? "<%.*s />" : "<%.*s>", (int)len,
                             RSTRING_PTR(tag_name));
    tag->close_len = snprintf(tag->close, sizeof(tag->close), "</%.*s>", (int)len, RSTRING_PTR(tag_name));

    /* rb_define_method (not _id): TruffleRuby doesn't implement rb_define_method_id. */
    rb_define_method(native, rb_id2name(method), trampolines[tag - tags], -1);
    return Qnil;
}

void r2h_init_tags(VALUE native)
{
    rb_define_singleton_method(native, "define_tag", native_define_tag, 3);
}
