// ext/ruby2html/html_escape.c
#include "html_escape.h"
#include <string.h>

// SSE4.2 support detection and intrinsics
#ifdef __SSE4_2__
#include <nmmintrin.h>
#define HAS_SSE42 1
#else
#define HAS_SSE42 0
#endif

// SIMD-accelerated scan for HTML special characters
#if HAS_SSE42
static inline long simd_find_special_char(const char *str, long len) {
    // Characters to search for: & < > " '
    const char special_chars[16] = {'&', '<', '>', '"', '\'', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    __m128i special = _mm_loadu_si128((__m128i*)special_chars);

    long pos = 0;

    // Process 16 bytes at a time
    while (pos + 16 <= len) {
        __m128i chunk = _mm_loadu_si128((__m128i*)(str + pos));

        // Search for any of the special characters
        // _mm_cmpestri returns index of first match, or 16 if no match
        int idx = _mm_cmpestri(special, 5, chunk, 16,
                                _SIDD_UBYTE_OPS | _SIDD_CMP_EQUAL_ANY | _SIDD_LEAST_SIGNIFICANT);

        if (idx < 16) {
            return pos + idx;
        }
        pos += 16;
    }

    // Handle remaining bytes with scalar code
    for (; pos < len; pos++) {
        char c = str[pos];
        if (c == '&' || c == '<' || c == '>' || c == '"' || c == '\'') {
            return pos;
        }
    }

    return -1; // No special characters found
}
#endif

// Scalar version for systems without SSE4.2
static inline long scalar_find_special_char(const char *str, long len) {
    for (long i = 0; i < len; i++) {
        char c = str[i];
        if (c == '&' || c == '<' || c == '>' || c == '"' || c == '\'') {
            return i;
        }
    }
    return -1;
}

// Fast HTML escaping with SIMD optimization
VALUE fast_escape_html(VALUE self, VALUE str) {
    if (NIL_P(str)) return Qnil;

    str = rb_String(str);
    long len = RSTRING_LEN(str);
    const char *ptr = RSTRING_PTR(str);

#if HAS_SSE42
    // Fast path: use SIMD to check if string needs escaping at all
    long first_special = simd_find_special_char(ptr, len);
#else
    long first_special = scalar_find_special_char(ptr, len);
#endif

    // If no special characters, return original string
    if (first_special == -1) {
        return str;
    }

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
