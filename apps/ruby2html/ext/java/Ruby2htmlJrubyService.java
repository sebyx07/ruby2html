// JRuby's only native code: a byte-level HTML escaper, the renderer's hottest
// primitive. Everything else (tag methods, attributes, content rules) stays in
// the pure-Ruby twin (lib/gem/ruby2html/render/pure_ruby.rb), which JRuby's JIT
// optimizes well; on TruffleRuby even the C extension loses to pure Ruby, so
// only JRuby gets this. The C extension (ext/ruby2html/html_escape.c) is the
// reference; this must stay byte-identical with it and with PureRuby.escape.
//
// require 'ruby2html/ruby2html_jruby' loads this: JRuby maps the base name
// ruby2html_jruby to the class Ruby2htmlJrubyService (CamelCase + "Service") in
// the default package, so the name and package here are load-bearing.
//
// Built by rake-compiler's Rake::JavaExtensionTask (see Rakefile) into
// lib/gem/ruby2html/ruby2html_jruby.jar and shipped in the -java platform gem.

import org.jruby.Ruby;
import org.jruby.RubyModule;
import org.jruby.RubyString;
import org.jruby.anno.JRubyMethod;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.runtime.load.BasicLibraryService;
import org.jruby.util.ByteList;

public class Ruby2htmlJrubyService implements BasicLibraryService {
    // getOrCreateModule/defineModuleUnder/defineAnnotatedMethods are marked
    // deprecated on JRuby 10 but remain the load-service API and still work; the
    // context-taking replacements are not available on the JRuby versions in CI.
    @SuppressWarnings("deprecation")
    public boolean basicLoad(final Ruby runtime) {
        final RubyModule javaNative =
            runtime.getOrCreateModule("Ruby2html").defineModuleUnder("JavaNative");
        javaNative.defineAnnotatedMethods(Escaper.class);
        return true;
    }

    public static final class Escaper {
        private static final byte AMP = '&', LT = '<', GT = '>', QUOT = '"', APOS = '\'';
        private static final byte[] E_AMP = bytes("&amp;");
        private static final byte[] E_LT = bytes("&lt;");
        private static final byte[] E_GT = bytes("&gt;");
        private static final byte[] E_QUOT = bytes("&quot;");
        private static final byte[] E_APOS = bytes("&#39;");

        private static byte[] bytes(final String s) {
            final byte[] b = new byte[s.length()];
            for (int i = 0; i < s.length(); i++) b[i] = (byte) s.charAt(i);
            return b;
        }

        private static boolean escapable(final byte b) {
            return b == AMP || b == LT || b == GT || b == QUOT || b == APOS;
        }

        // Ruby2html::JavaNative.escape(str) -> String
        //
        // str has already been run through PureRuby.utf8_compatible, so its
        // encoding is UTF-8, US-ASCII or BINARY. All five escapable characters
        // are ASCII, so escaping byte by byte is identical across those
        // encodings and for bytes that are invalid UTF-8 (the C extension and
        // PureRuby both pass such bytes through). The result keeps the input's
        // encoding. A clean string is returned unchanged (same object), which
        // PureRuby.escape_html relies on to avoid a copy.
        @JRubyMethod(name = "escape", module = true)
        public static IRubyObject escape(final ThreadContext ctx, final IRubyObject self,
                                         final IRubyObject arg) {
            final RubyString str = (RubyString) arg;
            final ByteList in = str.getByteList();
            final byte[] src = in.getUnsafeBytes();
            final int begin = in.getBegin();
            final int len = in.getRealSize();

            int first = -1;
            for (int i = 0; i < len; i++) {
                if (escapable(src[begin + i])) { first = i; break; }
            }
            if (first < 0) return str; // nothing to escape: hand back the same string

            final ByteList out = new ByteList(len + 16);
            out.setEncoding(in.getEncoding());
            out.append(src, begin, first);
            for (int i = first; i < len; i++) {
                final byte b = src[begin + i];
                switch (b) {
                    case AMP:  out.append(E_AMP);  break;
                    case LT:   out.append(E_LT);   break;
                    case GT:   out.append(E_GT);   break;
                    case QUOT: out.append(E_QUOT); break;
                    case APOS: out.append(E_APOS); break;
                    default:   out.append(b);
                }
            }
            return RubyString.newString(ctx.runtime, out);
        }
    }
}
