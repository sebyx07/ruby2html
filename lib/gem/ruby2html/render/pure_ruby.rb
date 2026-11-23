# frozen_string_literal: true

begin
  # Only ERB's C escaper (erb >= 4), not the template engine. Absent on
  # JRuby/TruffleRuby: PureRuby.escape then uses its regex fallback.
  require 'erb/escape'
rescue LoadError
  nil
end

if RUBY_ENGINE == 'jruby' && ENV['RUBY2HTML_DISABLE_EXT'] != '1'
  begin
    # Defines Ruby2html::JavaNative (a byte-level HTML escaper, ext/java).
    # JRuby's only native code; PureRuby.escape uses it when present.
    require 'ruby2html/ruby2html_jruby'
  rescue LoadError
    nil
  end
end

module Ruby2html
  # Pure-Ruby twin of the C extension's Ruby2html::Native (ext/ruby2html),
  # used on JRuby, when the extension isn't built, or with
  # RUBY2HTML_DISABLE_EXT=1. The specs render everything with both and
  # compare. The rules are documented once, in the C sources.
  #
  # Written for JITs (YJIT, the JVM): generated tag methods without splats,
  # everything appended with String#<< to one buffer, and escaping that
  # returns the string itself when there is nothing to escape.
  module PureRuby
    INVALID_ATTRIBUTE_NAME = %r{[\x00-\x20\x7f"'<>/=]}
    STRING_BOOLEAN = /\A(?:data-|aria-|(?:draggable|spellcheck|contenteditable)\z)/
    MAX_NESTING = 32 # see R2H_MAX_NESTING in attributes.c
    ESCAPABLE = /[&<>"']/
    ESCAPABLE_BYTES = /[&<>"']/n
    ESCAPES = { '&' => '&amp;', '<' => '&lt;', '>' => '&gt;', '"' => '&quot;', "'" => '&#39;' }.freeze

    class << self
      # CRuby's ERB::Escape (erb >= 4, in C) is the fastest option and also
      # returns its argument untouched when it is clean.
      if RUBY_ENGINE == 'ruby' && defined?(ERB::Escape)
        # May return str itself: only for appending to the buffer.
        def escape(str)
          ERB::Escape.html_escape(utf8_compatible(str))
        end
      elsif defined?(Ruby2html::JavaNative)
        # JRuby: the Java escaper (ext/java). Byte-identical with the regex
        # branch below (and with the C extension); also returns str itself
        # when clean. utf8_compatible first, so it sees UTF-8/US-ASCII/BINARY.
        def escape(str)
          Ruby2html::JavaNative.escape(utf8_compatible(str))
        end
      else
        def escape(str)
          str = utf8_compatible(str)
          # A UTF-8 regex raises on invalid bytes; Native passes them through.
          return str.b.gsub(ESCAPABLE_BYTES, ESCAPES).force_encoding(Encoding::UTF_8) unless str.valid_encoding?

          str.match?(ESCAPABLE) ? str.gsub(ESCAPABLE, ESCAPES) : str
        end
      end

      # Like Native.escape_html: never hands back the caller's mutable string.
      def escape_html(obj)
        str = as_string(obj)
        escaped = escape(str)
        escaped.equal?(str) && !str.frozen? ? str.dup : escaped
      end

      # See r2h_utf8_compatible in html_escape.c.
      def utf8_compatible(str)
        case str.encoding
        when Encoding::UTF_8 then str
        when Encoding::US_ASCII then str.ascii_only? ? str : str.dup.force_encoding(Encoding::UTF_8)
        when Encoding::BINARY then str.dup.force_encoding(Encoding::UTF_8)
        else str.ascii_only? ? str : str.encode(Encoding::UTF_8)
        end
      end

      # rb_obj_as_string, as the C extension uses: a String as is, else #to_s
      # (even a private one), else Kernel#to_s when #to_s returns no String.
      def as_string(obj)
        return obj if String === obj

        str = obj.__send__(:to_s)
        String === str ? str : Kernel.instance_method(:to_s).bind_call(obj)
      end

      # See r2h_current_buffer in content.c.
      def output_buffer(buffer)
        raise TypeError, 'ruby2html: @current_output must be a String' unless String === buffer

        encoding = buffer.encoding
        return buffer if encoding == Encoding::UTF_8
        unless encoding == Encoding::BINARY || encoding == Encoding::US_ASCII
          raise Encoding::CompatibilityError, "ruby2html: output buffer must be UTF-8, not #{encoding}"
        end

        buffer.force_encoding(Encoding::UTF_8)
      end

      def define_tag(method_name, tag, void)
        source = void ? void_tag_source(method_name, tag) : tag_source(method_name, tag)
        # The magic comment is per eval: without it every tag literal allocates.
        module_eval("# frozen_string_literal: true\n#{source}", __FILE__, __LINE__)
      end

      private
        def tag_source(method_name, tag)
          <<~RUBY
            def #{method_name}(content = nil, **attributes)
              buffer = @current_output
              buffer = __r2h_output(buffer) unless buffer && buffer.equal?(@__r2h_output)
              if attributes.empty?
                # `li "text"` (Native's fast path): escaping may raise (an
                # untranscodable string), so do it before writing anything.
                if !block_given? && String === content && content.instance_of?(String)
                  text = PureRuby.escape(content)
                  buffer << '<#{tag}>' << text << '</#{tag}>'
                  return
                end
                buffer << '<#{tag}>'
              else
                __r2h_open_tag(buffer, '<#{tag}', attributes)
                buffer << '>'
              end
              if block_given?
                size = buffer.bytesize
                result = yield
                __r2h_block_result(buffer, result) if buffer.bytesize == size
              else
                __r2h_text(buffer, content)
              end
              buffer << '</#{tag}>'
              nil
            end
          RUBY
        end

        def void_tag_source(method_name, tag)
          <<~RUBY
            def #{method_name}(_content = nil, **attributes)
              buffer = @current_output
              buffer = __r2h_output(buffer) unless buffer && buffer.equal?(@__r2h_output)
              if attributes.empty?
                buffer << '<#{tag} />'
              else
                __r2h_open_tag(buffer, '<#{tag}', attributes)
                buffer << ' />'
              end
              nil
            end
          RUBY
        end
    end

    def plain(text)
      buffer = @current_output
      buffer = __r2h_output(buffer) unless buffer && buffer.equal?(@__r2h_output)
      __r2h_text(buffer, text)
      nil
    end

    def component(html)
      return if html.equal?(nil)

      buffer = @current_output
      buffer = __r2h_output(buffer) unless buffer && buffer.equal?(@__r2h_output)
      buffer << PureRuby.utf8_compatible(PureRuby.as_string(html))
      nil
    end

    private
      # Validates (and relabels) a newly swapped-in @current_output once, then
      # remembers it: checking its class and encoding on every call costs the
      # pure-Ruby renderer a few percent. (`buffer &&`: the memo starts as nil.)
      def __r2h_output(buffer)
        @__r2h_output = PureRuby.output_buffer(buffer)
      end

      def __r2h_text(buffer, obj)
        case obj
        when nil then nil
        when String
          safe = !obj.instance_of?(String) && __r2h_html_safe?(obj)
          buffer << (safe ? PureRuby.utf8_compatible(obj) : PureRuby.escape(obj))
        when Symbol, Integer then buffer << PureRuby.escape(obj.to_s)
        else
          safe = __r2h_html_safe?(obj)
          str = PureRuby.as_string(obj)
          buffer << (safe ? PureRuby.utf8_compatible(str) : PureRuby.escape(str))
        end
      end

      # Module#===, not is_a?: the result may be a BasicObject.
      def __r2h_block_result(buffer, result)
        case result
        when String, Symbol, Numeric then __r2h_text(buffer, result)
        end
      end

      # rb_respond_to also answers for a BasicObject, which has no respond_to?.
      def __r2h_html_safe?(obj)
        responds = Kernel === obj ? obj.respond_to?(:html_safe?) : Kernel.instance_method(:respond_to?).bind_call(obj, :html_safe?)
        responds && obj.html_safe?
      end

      # Writes `<tag attr="..."`. If an attribute raises and the caller rescues,
      # a half-written start tag would turn whatever is appended next into
      # markup, so the buffer is rolled back to before the tag.
      def __r2h_open_tag(buffer, open, attributes)
        mark = buffer.bytesize
        buffer << open
        __r2h_attributes(buffer, attributes, nil)
      rescue Exception # rubocop:disable Lint/RescueException -- re-raised; any exception leaves the tag open
        buffer.replace(buffer.byteslice(0, mark)) if !buffer.frozen? && buffer.bytesize >= mark
        raise
      end

      def __r2h_attributes(buffer, attributes, prefix, depth = 0)
        raise ArgumentError, "attributes nested more than #{MAX_NESTING} levels deep" if depth > MAX_NESTING

        attributes.each do |key, value|
          next if value.equal?(nil) # not nil?: the value may be a BasicObject

          name = Symbol === key ? key.name : PureRuby.as_string(key)
          raise ArgumentError, "attribute name can't be empty" if name.empty?

          name = PureRuby.utf8_compatible(name)
          name = "#{prefix}-#{__r2h_dasherize(name)}" if prefix
          # Match bytes when the name isn't valid UTF-8 (a UTF-8 regex would raise).
          checked = name.valid_encoding? ? name : name.b
          __r2h_invalid_name(name) if INVALID_ATTRIBUTE_NAME.match?(checked)

          case value
          when String then buffer << ' ' << name << '="' << PureRuby.escape(value) << '"'
          when true then buffer << ' ' << name << (STRING_BOOLEAN.match?(checked) ? '="true"' : '')
          when false then buffer << ' ' << name << '="false"' if STRING_BOOLEAN.match?(checked)
          when Hash then __r2h_attributes(buffer, value, name, depth + 1)
          when Array then buffer << ' ' << name << '="' << __r2h_tokens(value) << '"'
          else buffer << ' ' << name << '="' << PureRuby.escape(PureRuby.as_string(value)) << '"'
          end
        end
      end

      # Shows the name's bytes as UTF-8, whatever encoding interpolation gave it
      # (see raise_invalid_name in attributes.c).
      def __r2h_invalid_name(name)
        raise ArgumentError, "invalid attribute name: #{name.dup.force_encoding(Encoding::UTF_8).inspect}"
      end

      def __r2h_dasherize(name)
        return name.tr('_', '-') if name.valid_encoding?

        name.b.tr('_', '-').force_encoding(Encoding::UTF_8)
      end

      def __r2h_tokens(tokens)
        __r2h_collect_tokens(tokens, [], 1).join(' ')
      end

      def __r2h_collect_tokens(tokens, collected, depth)
        raise ArgumentError, "attributes nested more than #{MAX_NESTING} levels deep" if depth > MAX_NESTING

        tokens.each do |token|
          if Array === token
            __r2h_collect_tokens(token, collected, depth + 1)
          elsif token
            collected << PureRuby.escape(PureRuby.as_string(token))
          end
        end
        collected
      end
  end
end
