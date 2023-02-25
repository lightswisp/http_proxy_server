require "./lib/http.rb"

trap "SIGINT" do
  puts "\nShutting down the server!"
  exit 130
end

proxy = HttpProxy.new(9999)
proxy.start


