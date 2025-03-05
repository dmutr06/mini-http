require "./mini_http"
require "json"

include MiniHttp

server = Server.new 6969

server.use do |req|
  return nil if req.body == nil
  begin
    req.body = JSON.parse req.body
    nil
  rescue
    Response[code: 400, body: Json['"Bad json"']]
  end
end

server.get("/") do |req|
  Html["<h1>Hello</h1>"]
end

server.get("/:id") do |req|
  id = req.params["id"]

  Html["<h1>User #{id}</h1>"]
end

server.get("/home") do |req|
  Html["<h1>Home</h1>"]
end

server.post("/task") do |req|
  puts req.body
  Json["{ \"id\": #{Random.rand(1000)} }"]
end

puts "Server has been started on port #{server.port}"
server.run
