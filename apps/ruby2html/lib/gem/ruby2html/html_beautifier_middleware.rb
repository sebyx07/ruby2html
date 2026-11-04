# frozen_string_literal: true

module Ruby2html
  # Development/test middleware that re-indents HTML responses with
  # HtmlBeautifier. Responses are left untouched unless they are buffered,
  # uncompressed text/html with a body.
  class HtmlBeautifierMiddleware
    CONTENT_TYPE = 'content-type'
    CONTENT_LENGTH = 'content-length'
    CONTENT_ENCODING = 'content-encoding'
    TRANSFER_ENCODING = 'transfer-encoding'

    def initialize(app)
      self.class.load_beautifier
      @app = app
    end

    # htmlbeautifier is an optional dependency, only needed by this middleware.
    def self.load_beautifier
      require 'htmlbeautifier'
    rescue LoadError => e
      raise LoadError, "Ruby2html::HtmlBeautifierMiddleware needs the htmlbeautifier gem. Add `gem 'htmlbeautifier'` " \
                       "to your Gemfile (e.g. in the :development group) or remove the middleware. (#{e.message})"
    end

    def call(env)
      status, headers, body = @app.call(env)
      return [status, headers, body] unless beautify?(status, headers, body)

      html = HtmlBeautifier.beautify(read_body(body))
      set_header(headers, CONTENT_LENGTH, html.bytesize.to_s)
      [status, headers, [html]]
    end

    private
      def beautify?(status, headers, body)
        status >= 200 && status != 204 && status != 304 &&
          header(headers, CONTENT_TYPE)&.include?('text/html') &&
          header(headers, CONTENT_ENCODING).nil? && # gzip etc.: bytes aren't HTML
          header(headers, TRANSFER_ENCODING).nil? && # streamed by the app
          body.respond_to?(:to_ary) # Rack 3: only buffered bodies; never drain a stream
      end

      # Beautify the document as a whole: chunk boundaries can fall inside tags.
      # Per Rack spec the original body must be closed once consumed.
      def read_body(body)
        chunks = body.to_ary
        chunks.size == 1 ? chunks.first.to_s : chunks.join
      ensure
        body.close if body.respond_to?(:close)
      end

      # Rack 3 headers are lowercase (and Rails uses case-insensitive
      # Rack::Headers); fall back to a scan for plain hashes from older apps.
      def header(headers, name)
        key = header_key(headers, name)
        key && headers[key]
      end

      def set_header(headers, name, value)
        headers[header_key(headers, name) || name] = value
      end

      def header_key(headers, name)
        return name if headers.key?(name)

        headers.each_key.find { |key| key.casecmp?(name) }
      end
  end
end
