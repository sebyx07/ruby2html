/*
 * Text content: tag arguments, block return values, #plain and #component.
 */
#include "buffer.h"

ID r2h_id_current_output;
ID r2h_id_html_safe_p;
static int utf8_index;

/*
 * The buffer tag methods write UTF-8 bytes into. A binary or US-ASCII
 * buffer (e.g. a bare String.new swapped in to capture output) is relabelled
 * UTF-8, as String#<< would do on the first non-ASCII append.
 */
VALUE r2h_current_buffer(VALUE self)
{
    VALUE buf = rb_ivar_get(self, r2h_id_current_output);

    if (!RB_TYPE_P(buf, T_STRING)) rb_raise(rb_eTypeError, "ruby2html: @current_output must be a String");
    if (RB_UNLIKELY(ENCODING_GET_INLINED(buf) != utf8_index)) {
        rb_encoding *enc = rb_enc_get(buf);
        if (enc != rb_ascii8bit_encoding() && enc != rb_usascii_encoding()) {
            rb_raise(rb_eEncCompatError, "ruby2html: output buffer must be UTF-8, not %s", rb_enc_name(enc));
        }
        rb_enc_associate_index(buf, utf8_index);
    }
    return buf;
}

/* Formats without allocating a String (Integer#to_s would). */
void r2h_append_long(VALUE buf, long value)
{
    char digits[24];
    char *end = digits + sizeof(digits), *p = end;
    unsigned long n = value < 0 ? 0UL - (unsigned long)value : (unsigned long)value;

    do {
        *--p = (char)('0' + n % 10);
        n /= 10;
    } while (n);
    if (value < 0) *--p = '-';
    r2h_buf_cat(buf, p, end - p);
}

/* ActiveSupport's html_safe?, false when ActiveSupport isn't loaded. */
static int is_html_safe(VALUE obj)
{
    return rb_respond_to(obj, r2h_id_html_safe_p) && RTEST(rb_funcall(obj, r2h_id_html_safe_p, 0));
}

/* Escapes obj.to_s unless it is html_safe? (e.g. an ActiveSupport::SafeBuffer). */
void r2h_append_text(VALUE buf, VALUE obj)
{
    switch (rb_type(obj)) {
    case T_NIL:
        return;
    case T_STRING:
        /*
         * A plain String is never html_safe?; only subclasses need the call.
         * rb_obj_class (not RBASIC_CLASS) so a String with a singleton
         * html_safe? can't spoof safety (matches PureRuby's instance_of?).
         */
        if (rb_obj_class(obj) != rb_cString && is_html_safe(obj)) {
            r2h_append_raw(buf, obj);
        } else {
            r2h_append_escaped(buf, obj);
        }
        return;
    case T_SYMBOL:
        r2h_append_escaped(buf, rb_sym2str(obj));
        return;
    case T_FIXNUM:
        r2h_append_long(buf, FIX2LONG(obj));
        return;
    default:
        if (is_html_safe(obj)) {
            r2h_append_raw(buf, rb_obj_as_string(obj));
        } else {
            r2h_append_escaped(buf, rb_obj_as_string(obj));
        }
    }
}

/*
 * A block that wrote nothing contributes its return value when that is a
 * String, Symbol or Numeric (Integer, Float, BigDecimal, Rational, ...):
 * `td { user.name }`. Anything else, such as the Array returned by
 * `items.each`, nil or true, is ignored.
 */
void r2h_append_block_result(VALUE buf, VALUE result)
{
    if (RB_TYPE_P(result, T_STRING) || SYMBOL_P(result) || RB_INTEGER_TYPE_P(result) || RB_FLOAT_TYPE_P(result) ||
        RTEST(rb_obj_is_kind_of(result, rb_cNumeric))) {
        r2h_append_text(buf, result);
    }
}

/* plain(text): escaped text, or raw when html_safe?. */
static VALUE native_plain(VALUE self, VALUE text)
{
    r2h_append_text(r2h_current_buffer(self), text);
    return Qnil;
}

/* component(html): already-rendered markup, appended as is. */
static VALUE native_component(VALUE self, VALUE html)
{
    if (!NIL_P(html)) r2h_append_raw(r2h_current_buffer(self), rb_obj_as_string(html));
    return Qnil;
}

void r2h_init_content(VALUE native)
{
    r2h_id_current_output = rb_intern("@current_output");
    r2h_id_html_safe_p = rb_intern("html_safe?");
    utf8_index = rb_utf8_encindex();

    rb_define_method(native, "plain", native_plain, 1);
    rb_define_method(native, "component", native_component, 1);
}
