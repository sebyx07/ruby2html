#ifndef RUBY2HTML_BUFFER_H
#define RUBY2HTML_BUFFER_H

#include <string.h>
#include "ruby2html.h"

/*
 * Output buffer primitives. Everything is written straight into the
 * renderer's String: reserve room, memcpy, then commit the new length.
 */

/*
 * Returns a write pointer with room for `n` more bytes. Grows at least 2x
 * because rb_str_modify_expand alone grows to the exact size, which would
 * make a long render quadratic. Both branches also unshare the string and
 * clear its coderange, which keeps raw byte writes encoding-correct.
 */
static inline char *r2h_buf_reserve(VALUE buf, long n)
{
    long len = RSTRING_LEN(buf);

    if ((long)rb_str_capacity(buf) - len < n) {
        rb_str_modify_expand(buf, n > len ? n : len);
    } else {
        rb_str_modify(buf);
    }
    return RSTRING_PTR(buf) + len;
}

static inline void r2h_buf_commit(VALUE buf, const char *end)
{
    rb_str_set_len(buf, end - RSTRING_PTR(buf));
}

/* One libruby call; also grows geometrically and clears the coderange. */
static inline void r2h_buf_cat(VALUE buf, const char *ptr, long len)
{
    rb_str_cat(buf, ptr, len);
}

#define R2H_BUF_CAT_LIT(buf, lit) r2h_buf_cat((buf), (lit), (long)(sizeof(lit) - 1))

#endif
