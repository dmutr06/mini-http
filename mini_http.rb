require "socket"

module MiniHttp
  CODES = {
    200 => "OK",
    201 => "Created",
    202 => "Accepted",
    204 => "No Content",
    400 => "Bad Request",
    401 => "Unauthorized",
    403 => "Forbidden",
    404 => "Not Found",
    405 => "Method Not Allowed",
    500 => "Internal Server Error",
    501 => "Not Implemented",
    503 => "Service Unavailable"
  }

  module ContentType
    def initialize(content)
      @content = content
    end
  
    def content
      @content
    end

    def to_s
      @content
    end
    
    def content_type
      self.class::CONTENT_TYPE 
    end
  end
  Request = Struct.new(:method, :path, :headers, :body)
  Response = Struct.new(:code, :headers, :body) do
    def to_s 
      "HTTP/1.1 #{code} #{reason_phrase(code)}\r\n" \
      "#{headers.map do |key, val| "#{key}: #{val}" end.join("\r\n")}" \
      "\r\n\r\n" \
      "#{body&.to_s || ""}"
    end

    def initialize(code: 200, headers: {}, body: nil)
      super(code, headers, body)
    end
    
    private

    def reason_phrase(code)
      CODES[code] || "Unknown Reason Phrase"
    end
  end
  
  class Html
    CONTENT_TYPE = "text/html"
    include ContentType
  end

  class Json
    CONTENT_TYPE = "application/json"
    include ContentType
  end
  
  class Plain
    CONTENT_TYPE = "text/plain"
    include ContentType
  end
  
  class Server 
    def initialize(port)
      @server = TCPServer.new(port)
      @port = port
    end

    def port
      @port
    end
    
    def run(&block)
      while socket = @server.accept
      handle(socket, block)
      end
    end

    private
    def handle(socket, handler)
      Thread.new do
        reqLine = socket.gets
        if reqLine.nil?
          socket.close
          Thread.exit
        end

        method, path, _ver = reqLine.split ' ', 3

        headers = {}
        while (line = socket.gets.chomp) && !line.empty?
          key, val = line.split(": ", 2)
          headers[key] = val
        end

        body = 
          if headers["Content-Length"]
            len = headers["Content-Length"].to_i
            socket.read(len)
          else nil end

        res = handler.call(Request[method, path, headers, body])

        if res.body&.is_a?(ContentType)
          res.headers["Content-Type"] = res.body.content_type
          res.headers["Content-Length"] = res.body.content.length
        elsif res.body&.is_a?(String)
          res.headers["Content-Length"] = res.body.length
          res.headers["Content-Type"] ||= "text/plain"
        end
        socket.print(res.to_s)
        socket.close
      end
    end
  end
end
