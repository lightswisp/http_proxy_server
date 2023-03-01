require_relative "parser"

PROXY_SERVER_NAME = "Rubinius/1.0.0"
PUBLIC_IP		  = `curl -s ifconfig.me`

class Client
	def initialize(client)
		@client = client
	end

	def start()
		self.handle_request(@client)
	end

	## Handles the request ##
	def handle_request(stream)
		stream_ip = stream.peeraddr[-1]
		buffer = stream.recvmsg()[0]
		return if buffer.length < 1	 			# if the buffer is empty for some reason
		parser = Parser.new(buffer) 			# create a parser
		return if !parser.valid?() 				# if it's not an HTTP 
		request = parser.parse()   				# parse HTTP
		host, port = request["host"], request["port"]
		
		if request["method"] == "CONNECT"
			puts "[+] #{stream_ip} => #{request["method"]} #{request["path"]} #{request["version"]}"
			self.do_Connect(stream, host, port)
		else
			port = 80 if port.nil?
			puts "[+] #{stream_ip} => #{request["method"]} #{request["path"]} #{request["version"]}"
			self.do_Http(stream, buffer, host, port)
		end
	end

	## Basic http proxy ##
	def do_Http(stream, buffer, host, port)
		begin
			if host == PUBLIC_IP
				  stream.print "HTTP/1.1 200\r\n" # 1
				  stream.print "Content-Type: text/html\r\n" # 2
				  stream.print "Server: #{PROXY_SERVER_NAME}\r\n"
				  stream.print "\r\n" # 3
				  stream.print "Hello world!" #4
				  stream.close
				  return
			end
			os = TCPSocket.new(host, port)	
			os.print(buffer)
			os_data = os.recvmsg()[0]
			stream.print(os_data)

			os.close
			stream.close()

		rescue
			stream.puts("HTTP/1.1 502 Bad Gateway\r\n")
			stream.close
		end
	end


	## SSL Tunnel ##
	def do_Connect(stream, host, port)
		begin
			os = TCPSocket.new(host,port) rescue stream.puts("HTTP/1.1 502 Bad Gateway\r\n")
		
			stream.puts("HTTP/1.0 200 OK\r\nDate: #{Time.now}\r\nServer: #{PROXY_SERVER_NAME}\r\n\r\n")
		rescue
			stream.puts("HTTP/1.1 502 Bad Gateway\r\n")
		end

		begin
			while fds = IO::select([stream, os]) # block until stream and os are readable
				if fds[0].member?(stream) # if its stream
					buf = stream.readpartial(1024);
					os.write(buf)
				elsif fds[0].member?(os) # if its remote server
					buf = os.readpartial(1024);
					stream.write(buf)
				end
			end
	    rescue
			os.close if os
		end

	end

end
