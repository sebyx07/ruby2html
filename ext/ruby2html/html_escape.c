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

// Lookup table for escape sequence strings (initialized at module load)
// NULL means no escaping needed, otherwise points to escape sequence
static const char* escape_table[256] = {0};

// Lookup table for additional bytes needed when escaping (initialized at module load)
// 0 means no escaping needed
static unsigned char escape_length[256] = {0};

// Initialize lookup tables (called once at module initialization)
static void init_escape_tables(void) {
    static int initialized = 0;
    if (initialized) return;
    initialized = 1;

    // Initialize escape sequences
    escape_table['&'] = "&amp;";
    escape_table['<'] = "&lt;";
    escape_table['>'] = "&gt;";
    escape_table['"'] = "&quot;";
    escape_table['\''] = "&#39;";

    // Initialize escape lengths (additional bytes needed)
    escape_length['&'] = 4;  // &amp; adds 4 bytes (5 total - 1 original)
    escape_length['<'] = 3;  // &lt; adds 3 bytes
    escape_length['>'] = 3;  // &gt; adds 3 bytes
    escape_length['"'] = 5;  // &quot; adds 5 bytes
    escape_length['\''] = 4; // &#39; adds 4 bytes
}

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

// Scalar version for systems without SSE4.2 - uses lookup table
static inline long scalar_find_special_char(const char *str, long len) {
    for (long i = 0; i < len; i++) {
        if (escape_table[(unsigned char)str[i]]) {
            return i;
        }
    }
    return -1;
}

// Fast HTML escaping with SIMD optimization
VALUE fast_escape_html(VALUE self, VALUE str) {
    if (NIL_P(str)) return Qnil;

    // Initialize lookup tables on first use
    init_escape_tables();

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

    // First pass: calculate required buffer size using lookup table
    long new_len = len;
    for (long i = 0; i < len; i++) {
        new_len += escape_length[(unsigned char)ptr[i]];
    }

    VALUE result = rb_str_new(NULL, new_len);
    char *out = RSTRING_PTR(result);
    long pos = 0;

    // Second pass: actual escaping using lookup table
    for (long i = 0; i < len; i++) {
        unsigned char c = (unsigned char)ptr[i];
        const char *escaped = escape_table[c];

        if (escaped) {
            // Character needs escaping - copy escape sequence
            size_t escape_len = escape_length[c] + 1; // +1 for the original char's replacement
            memcpy(out + pos, escaped, escape_len);
            pos += escape_len;
        } else {
            // Character doesn't need escaping - copy as-is
            out[pos++] = c;
        }
    }

    rb_str_set_len(result, pos);
    rb_enc_associate(result, rb_enc_get(str));
    return result;
}
