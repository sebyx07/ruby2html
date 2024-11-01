# frozen_string_literal: true

module Ruby2html
  class HtmlBeautifierMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)

      if headers['Content-Type']&.include?('text/html')
        new_body = []
        body.each do |chunk|
          new_body << HtmlBeautifier.beautify(chunk)
        end
        headers['Content-Length'] = new_body.map(&:bytesize).sum.to_s
        body = new_body
      end

      [status, headers, body]
    end
  end
end
