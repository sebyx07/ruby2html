/*
 * HTML escaping of & < > " ' (safe for text and for quoted attribute values).
 *
 * Strategy: find the first escapable byte with a vector scan. Clean strings
 * (the common case) are then a single memcpy. Dirty strings get their exact
 * escaped size computed once, and are written in one pass that bulk-copies
 * the clean runs between escapable bytes.
 */
#include "buffer.h"

static const char *const ESCAPES[256] = {
    ['&'] = "&amp;", ['<'] = "&lt;", ['>'] = "&gt;", ['"'] = "&quot;", ['\''] = "&#39;",
};

/* Bytes added by escaping each character (0 = not escapable). */
static const unsigned char EXTRA[256] = {
    ['&'] = 4, ['<'] = 3, ['>'] = 3, ['"'] = 5, ['\''] = 4,
};

static int utf8_index, usascii_index, binary_index;

/*
 * 16-byte vector scan. The escapable bytes pair up so three compares cover
 * all five:  0x26 '&' | 1 == 0x27 '\''   0x3C '<' | 2 == 0x3E '>'   0x22 '"'.
 * The pairs also share their EXTRA value (4, 3, 5), which lets the counting
 * pass sum a per-byte weight vector instead of looking each byte up.
 */
#if defined(__SSE2__) && !defined(R2H_NO_SIMD)
#include <emmintrin.h>
#define R2H_SIMD 1

typedef __m128i r2h_vec;

static inline void classify(const char *p, r2h_vec *amp, r2h_vec *ang, r2h_vec *quot)
{
    const __m128i v = _mm_loadu_si128((const __m128i *)p);
    *amp = _mm_cmpeq_epi8(_mm_or_si128(v, _mm_set1_epi8(1)), _mm_set1_epi8(0x27));
    *ang = _mm_cmpeq_epi8(_mm_or_si128(v, _mm_set1_epi8(2)), _mm_set1_epi8(0x3E));
    *quot = _mm_cmpeq_epi8(v, _mm_set1_epi8(0x22));
}

/* Offset of the first escapable byte in the chunk, or 16. */
static inline int chunk_first(const char *p)
{
    r2h_vec amp, ang, quot;
    classify(p, &amp, &ang, &quot);
    const int mask = _mm_movemask_epi8(_mm_or_si128(_mm_or_si128(amp, ang), quot));
    return mask ? __builtin_ctz((unsigned)mask) : 16;
}

static inline long chunk_extra(const char *p)
{
    r2h_vec amp, ang, quot;
    classify(p, &amp, &ang, &quot);
    const __m128i weights = _mm_or_si128(
        _mm_or_si128(_mm_and_si128(amp, _mm_set1_epi8(4)), _mm_and_si128(ang, _mm_set1_epi8(3))),
        _mm_and_si128(quot, _mm_set1_epi8(5)));
    const __m128i sums = _mm_sad_epu8(weights, _mm_setzero_si128());
    return _mm_cvtsi128_si32(sums) + _mm_cvtsi128_si32(_mm_srli_si128(sums, 8));
}

#elif defined(__aarch64__) && defined(__ARM_NEON) && !defined(R2H_NO_SIMD)
#include <arm_neon.h>
#define R2H_SIMD 1

typedef uint8x16_t r2h_vec;

static inline void classify(const char *p, r2h_vec *amp, r2h_vec *ang, r2h_vec *quot)
{
    const uint8x16_t v = vld1q_u8((const uint8_t *)p);
    *amp = vceqq_u8(vorrq_u8(v, vdupq_n_u8(1)), vdupq_n_u8(0x27));
    *ang = vceqq_u8(vorrq_u8(v, vdupq_n_u8(2)), vdupq_n_u8(0x3E));
    *quot = vceqq_u8(v, vdupq_n_u8(0x22));
}

static inline int chunk_first(const char *p)
{
    r2h_vec amp, ang, quot;
    classify(p, &amp, &ang, &quot);
    const uint8x16_t any = vorrq_u8(vorrq_u8(amp, ang), quot);
    /* NEON has no movemask: narrow each byte to a nibble, giving 4 bits per lane. */
    const uint64_t bits = vget_lane_u64(vreinterpret_u64_u8(vshrn_n_u16(vreinterpretq_u16_u8(any), 4)), 0);
    return bits ? __builtin_ctzll(bits) >> 2 : 16;
}

static inline long chunk_extra(const char *p)
{
    r2h_vec amp, ang, quot;
    classify(p, &amp, &ang, &quot);
    const uint8x16_t weights = vorrq_u8(
        vorrq_u8(vandq_u8(amp, vdupq_n_u8(4)), vandq_u8(ang, vdupq_n_u8(3))),
        vandq_u8(quot, vdupq_n_u8(5)));
    return vaddvq_u8(weights); /* at most 16 * 5 = 80, no overflow */
}
#endif

/* Offset of the first escapable byte, or len. */
static inline long find_escapable(const char *p, long len)
{
    long i = 0;
#ifdef R2H_SIMD
    for (; i + 16 <= len; i += 16) {
        const int at = chunk_first(p + i);
        if (at < 16) return i + at;
    }
#endif
    for (; i < len; i++) {
        if (EXTRA[(unsigned char)p[i]]) return i;
    }
    return len;
}

/* Total bytes escaping adds to p[0, len). */
static inline long escaped_extra(const char *p, long len)
{
    long i = 0, extra = 0;
#ifdef R2H_SIMD
    for (; i + 16 <= len; i += 16) extra += chunk_extra(p + i);
#endif
    for (; i < len; i++) extra += EXTRA[(unsigned char)p[i]];
    return extra;
}

/*
 * Escaping grows a string at most 6x ('"' -> "&quot;"). Refuse sizes whose
 * worst case doesn't fit in a long (only reachable on 32-bit platforms).
 */
static inline void check_escaped_size(long len, long fixed)
{
    if (len > (LONG_MAX - fixed) / 6) rb_raise(rb_eArgError, "string too large to escape");
}

/* Writes the escaped form of p[0, len) to out; returns the new end. */
static char *escape_into(char *out, const char *p, long len)
{
    const char *const end = p + len;

    while (p < end) {
        const long run = find_escapable(p, end - p);
        memcpy(out, p, (size_t)run);
        out += run;
        p += run;
        if (p == end) break;

        const unsigned char c = (unsigned char)*p++;
        const long size = EXTRA[c] + 1;
        memcpy(out, ESCAPES[c], (size_t)size);
        out += size;
    }
    return out;
}

/*
 * The output buffer is UTF-8. UTF-8, US-ASCII and ASCII-only strings are
 * copied byte for byte. Binary strings are assumed to hold UTF-8 bytes
 * (what 1.x did). Anything else is transcoded, which raises if it can't be.
 */
VALUE r2h_utf8_compatible(VALUE str)
{
    const int index = ENCODING_GET_INLINED(str);

    if (index == utf8_index || index == usascii_index || index == binary_index) return str;
    if (rb_enc_str_asciionly_p(str)) return str;
    return rb_str_encode(str, rb_enc_from_encoding(rb_utf8_encoding()), 0, Qnil);
}

/*
 * Appends before + escaped(str) + after with a single buffer reservation:
 * a whole `<li>text</li>` costs one capacity check instead of three.
 */
void r2h_append_escaped_wrapped(VALUE buf, const char *before, long before_len, VALUE str,
                                const char *after, long after_len)
{
    str = r2h_utf8_compatible(str);
    /* Growing buf would free the bytes we are reading if they are the same string. */
    if (str == buf) str = rb_str_dup(str);

    const char *p = RSTRING_PTR(str);
    const long len = RSTRING_LEN(str);
    check_escaped_size(len, before_len + after_len + RSTRING_LEN(buf));
    const long first = find_escapable(p, len);
    const long extra = first == len ? 0 : escaped_extra(p + first, len - first);

    char *out = r2h_buf_reserve(buf, before_len + len + extra + after_len);
    p = RSTRING_PTR(str); /* reserve may run GC; str is guarded below */
    if (before_len) memcpy(out, before, (size_t)before_len);
    out += before_len;
    memcpy(out, p, (size_t)first);
    out = escape_into(out + first, p + first, len - first);
    if (after_len) memcpy(out, after, (size_t)after_len);
    r2h_buf_commit(buf, out + after_len);
    RB_GC_GUARD(str);
}

void r2h_append_escaped(VALUE buf, VALUE str)
{
    r2h_append_escaped_wrapped(buf, NULL, 0, str, NULL, 0);
}

void r2h_append_raw(VALUE buf, VALUE str)
{
    str = r2h_utf8_compatible(str);
    if (str == buf) str = rb_str_dup(str);
    r2h_buf_cat(buf, RSTRING_PTR(str), RSTRING_LEN(str));
    RB_GC_GUARD(str);
}

/*
 * Ruby2html::Native.escape_html(obj) -> String
 *
 * Never returns the caller's own mutable string: callers may mutate the
 * result. Frozen input with nothing to escape is returned as is.
 */
static VALUE native_escape_html(VALUE mod, VALUE obj)
{
    VALUE str = r2h_utf8_compatible(rb_obj_as_string(obj));
    const char *p = RSTRING_PTR(str);
    const long len = RSTRING_LEN(str);
    const long first = find_escapable(p, len);

    /* Binary input holds UTF-8 bytes (see r2h_utf8_compatible): label the result UTF-8. */
    const int binary = ENCODING_GET_INLINED(str) == binary_index;

    if (first == len) {
        if (!binary) return OBJ_FROZEN(str) ? str : rb_str_dup(str);
        VALUE copy = rb_str_dup(str);
        rb_enc_associate(copy, rb_utf8_encoding());
        return copy;
    }

    check_escaped_size(len, 0);
    VALUE result = rb_str_buf_new(len + escaped_extra(p + first, len - first));
    if (binary) {
        rb_enc_associate(result, rb_utf8_encoding());
    } else {
        rb_enc_copy(result, str);
    }
    char *out = RSTRING_PTR(result);
    memcpy(out, p, (size_t)first);
    r2h_buf_commit(result, escape_into(out + first, p + first, len - first));
    RB_GC_GUARD(str);
    return result;
}

void r2h_init_escape(VALUE native)
{
    utf8_index = rb_utf8_encindex();
    usascii_index = rb_usascii_encindex();
    binary_index = rb_ascii8bit_encindex();

    rb_define_singleton_method(native, "escape_html", native_escape_html, 1);
}
