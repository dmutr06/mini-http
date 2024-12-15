require "./mini_http"

include MiniHttp

server = Server.new 6969

puts "Server has been started on port #{server.port}"


server.get("/") do |req|

  Html["<h1>Route</h1>"]
end

server.get("/:id") do |req|
  id = req.params["id"]

  Html["<h1>#{id}</h1>"]
end

server.get("/home") do |req|
  Html["<h1>Home</h1>"]
end

server.run
