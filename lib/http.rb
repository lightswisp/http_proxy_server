require "socket"
require_relative "client"

class HttpProxy
	def initialize(port)
		@port = port
		@s = TCPServer.new(@port)
		puts "Server is listening on #{@port}"
	end	

	## Create new thread for each client and pass the stream to our request handler ## 
	def start()
		loop do
			Thread.new(@s.accept) do |c|
				client = Client.new(c)
				client.start()
			end
		end
	end
end
