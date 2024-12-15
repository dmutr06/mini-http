require "./mini_http"

include MiniHttp

server = Server.new 6969

puts "Server has been started on port #{server.port}"

# TODO: make something like this:
# server.get("/") do
# end

server.run do |req|
  case req.method
  when "GET"
    if /\/home$/.match(req.path)
      Response[code: 200, body: Html.new("<h1>Home</h1>")]
    elsif (match = /^\/user\/([^\/]+)$/.match(req.path))
      id = match[1]
      Response[body: Json.new("{ \"id\": #{id} }")]
    else
      Response[code: 404, body: Html.new("<h1>Not Found :(</h1>")]
    end
  else
    Response[code: 405, body: "Method Not Allowed"]
  end
end
