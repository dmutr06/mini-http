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
  
  class Content
    def self.new(type)
      Class.new do
        include Content::Marker

        @content_type = type
        def self.content_type
          @content_type
        end

        def content_type
          self.class.content_type
        end

        def initialize(content)
          @content = content
        end

        def self.[](content)
          self.new(content)
        end

        def content
          @content
        end

        def to_res
          Response[body: self]
        end

        def to_s
          content
        end
      end
    end

    private
    
    module Marker; end
  end

  Request = Struct.new(:method, :path, :params, :headers, :body)
  Response = Struct.new(:code, :headers, :body) do
    def to_s 
      "HTTP/1.1 #{code} #{reason_phrase(code)}\r\n" \
      "#{headers.map do |key, val| "#{key}: #{val}" end.join("\r\n")}" \
      "\r\n\r\n" \
      "#{body || ""}"
    end

    def initialize(code: 200, headers: {}, body: nil)
      super(code, headers, body)
    end
    
    def to_res
      self
    end

    def send(socket)
      if body
        headers["Content-Type"] = body.content_type
        self.body = body.to_s
        headers["Content-Length"] = body.length
      end

      socket.print(self.to_s)
    end

    private

    def reason_phrase(code)
      CODES[code] || "Unknown Reason Phrase"
    end
  end
  
  Html = Content.new("text/html")
  Json = Content.new("application/json")
  Css = Content.new("text/css")
  Plain = Content.new("text/plain")

  class Server 
    def initialize(port, max_threads: 10)
      @server = TCPServer.new(port)
      @port = port
      @routes = Hash.new
      @middlewares = []

      @queue = Queue.new
      @workers = Array.new(max_threads) do
        Thread.new do
          loop do
            socket = @queue.pop
            handle(socket)
          end
        end
      end
    end

    def port
      @port
    end
    
    def run
      while socket = @server.accept
        @queue << socket
      end
    end

    def use(&block)
      @middlewares.push(block)
    end

    def route(method, path, &block)
      segments = path.split("/").reject(&:empty?)
      @routes[method] ||= {}

      cur = @routes[method]
      
      if (segments.empty?)
        cur[:handler] = block 
        return 
      end

      segments.each do |seg|
        cur[seg] ||= Hash.new
        cur = cur[seg]
      end

      cur[:handler] = block
    end

    def get(path, &block)
      route("GET", path, &block) 
    end

    def post(path, &block)
      route("POST", path, &block) 
    end

    def delete(path, &block)
      route("DELETE", path, &block) 
    end

    def put(path, &block)
      route("PUT", path, &block) 
    end

    def patch(path, &block)
      route("PATCH", path, &block) 
    end

    def option(path, &block)
      route("OPTION", path, &block) 
    end

    private
    
    def get_handler(method, path)
      cur = @routes[method]
      return nil if cur.nil?

      segments = path.split("/").reject(&:empty?)
      params = Hash.new

      return [cur[:handler], params] if segments.empty?

      segments.each do |seg|
        if cur[seg]
          cur = cur[seg]
        elsif (param_key = cur.keys.find { |key| key.start_with?(":") })
          params[param_key[1..]] = seg
          cur = cur[param_key]
        else
          return nil
        end
      end

      [cur[:handler], params]
    end
    

    # TODO: change everything, this func is overcomplicated
    def handle(socket)
      Thread.new do
        begin
          reqLine = socket.gets
          if reqLine.nil?
            socket.close
            Thread.exit
          end

          method, path, _ver = reqLine.split(' ', 3)

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

          handler = get_handler(method, path)
          res = 
            if handler.nil?
              Response[code: 404, body: Html["<h1>Not Found</h1>"]]
            else
              req = Request[method, path, handler[1], headers, body]

              mw_res = nil
              begin
                @middlewares.each do |mw|
                  mw_res = mw.call(req)

                  break if mw_res.respond_to?(:to_res)
                end
              rescue => e
              # TODO: handle exception
              end

              if mw_res.nil?
                handler[0].call(req)
              else
                mw_res
              end
            end

          if !res.respond_to?(:to_res)
            raise "Something went wrong..."
          end

          res = res.to_res
          res.send(socket)

        rescue => e
          puts "Err: #{e.message}"
          Response[code: 500].send(socket)

        ensure 
          socket.close
        end
      end
    end
  end
end
