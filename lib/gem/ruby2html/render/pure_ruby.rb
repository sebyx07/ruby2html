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
        str = obj.to_s
        escaped = escape(str)
        escaped.equal?(str) && !str.frozen? ? str.dup : escaped
      end

      # See r2h_utf8_compatible in html_escape.c.
      def utf8_compatible(str)
        case str.encoding
        when Encoding::UTF_8, Encoding::US_ASCII then str
        when Encoding::BINARY then str.dup.force_encoding(Encoding::UTF_8)
        else str.ascii_only? ? str : str.encode(Encoding::UTF_8)
        end
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
              if attributes.empty?
                buffer << '<#{tag}>'
              else
                __r2h_open_tag(buffer, '<#{tag}', attributes)
                buffer << '>'
              end
              if block_given?
                size = buffer.bytesize
                result = yield
                __r2h_block_result(buffer, result) if buffer.bytesize == size
              elsif content.instance_of?(String)
                buffer << PureRuby.escape(content)
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
              if attributes.empty?
                @current_output << '<#{tag} />'
              else
                buffer = @current_output
                __r2h_open_tag(buffer, '<#{tag}', attributes)
                buffer << ' />'
              end
              nil
            end
          RUBY
        end
    end

    def plain(text)
      __r2h_text(@current_output, text)
      nil
    end

    def component(html)
      @current_output << PureRuby.utf8_compatible(html.to_s) unless html.nil?
      nil
    end

    private
      def __r2h_text(buffer, obj)
        case obj
        when nil then nil
        when String
          safe = !obj.instance_of?(String) && __r2h_html_safe?(obj)
          buffer << (safe ? PureRuby.utf8_compatible(obj) : PureRuby.escape(obj))
        when Symbol, Integer then buffer << PureRuby.escape(obj.to_s)
        else
          buffer << (__r2h_html_safe?(obj) ? PureRuby.utf8_compatible(obj.to_s) : PureRuby.escape(obj.to_s))
        end
      end

      def __r2h_block_result(buffer, result)
        __r2h_text(buffer, result) if result.is_a?(String) || result.is_a?(Symbol) || result.is_a?(Numeric)
      end

      def __r2h_html_safe?(obj)
        obj.respond_to?(:html_safe?) && obj.html_safe?
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
          next if value.nil?

          name = key.is_a?(Symbol) ? key.name : key.to_s
          raise ArgumentError, "attribute name can't be empty" if name.empty?

          name = PureRuby.utf8_compatible(name)
          name = "#{prefix}-#{__r2h_dasherize(name)}" if prefix
          # Match bytes when the name isn't valid UTF-8 (a UTF-8 regex would raise).
          checked = name.valid_encoding? ? name : name.b
          raise ArgumentError, "invalid attribute name: #{name.inspect}" if INVALID_ATTRIBUTE_NAME.match?(checked)

          case value
          when String then buffer << ' ' << name << '="' << PureRuby.escape(value) << '"'
          when true then buffer << ' ' << name << (STRING_BOOLEAN.match?(name) ? '="true"' : '')
          when false then buffer << ' ' << name << '="false"' if STRING_BOOLEAN.match?(name)
          when Hash then __r2h_attributes(buffer, value, name, depth + 1)
          when Array then buffer << ' ' << name << '="' << __r2h_tokens(value) << '"'
          else buffer << ' ' << name << '="' << PureRuby.escape(value.to_s) << '"'
          end
        end
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
          if token.is_a?(Array)
            __r2h_collect_tokens(token, collected, depth + 1)
          elsif token
            collected << PureRuby.escape(token.to_s)
          end
        end
        collected
      end
  end
end
