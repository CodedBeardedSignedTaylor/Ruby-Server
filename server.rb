require 'socket'
require 'uri'

# Where the files will be served from:
WEB_ROOT = './public'

# Mapping extensions to their proper content type
CONTENT_TYPE_MAPPING = {
	'html' => 'text/html',
	'txt' => 'text/plain',
	'png' => 'image/png',
	'jpg' => 'image/jpeg'
}

#Treats the following as binary data if the content type cannot be found
DEFAULT_CONTENT_TYPE = 'application/octet-stream'

# This helper function parses the extension of the requested file and 
# then looks up its content type

def content_type(path)
	ext = File.extname(path).split(".").last
	CONTENT_TYPE_MAPPING.fetch(ext, DEFAULT_CONTENT_TYPE)
end

# Takes a request line and extracts the path from it,
# scrubbing out parameters and unescaping URI-encoding.

# This cleaned up path is then converted into a relative path
# to a file in the server's public folder by joining it with
# the web root.

# Example: GET /path?foo=bar HTTP/1.1 => /path

def requested_file(request_line)
	request_uri = request_line.split(" ")[1]
	path = URI.unescape(URI(request_uri).path)

	clean = []

	# Split the file into components
	parts = path.split("/")

	parts.each do |part|
		
		# Skip any empty or current directory (".") path components
		next if part.empty? || part == "."

		# If the path component goes up one directory level (".."),
		# removes the last clean component. 
		# Otherwise, add the component to the Array of clean components.

		part == '..' ? clean.pop : clean << part 
	end

	File.join(WEB_ROOT, path)
end

server = TCPServer.new('localhost', 1345)

loop do
	
	socket = server.accept
	request_line = socket.gets

	STDERR.puts request_line

	path = requested_file(request_line)
	path = File.join(path, 'index.html') if File.directory?(path)

	# Here, we make sure the file exists and is not a directory
	# before attempting to open it.

	if File.exist?(path) && !File.directory?(path)
		File.open(path, "rb") do |file|
			socket.print "HTTP/1.1 200 OK\r\n" +
						 "Content-Type: #{content_type(file)}\r\n" +
						 "Content-Length: #{file.size}\r\n" +
						 "Connection: close\r\n"

			socket.print "\r\n"

			#write the contents of the file to the socket
			IO.copy_stream(file, socket)
		end
	else
		message = "File not found\n"

		socket.print "HTTP/1.1 404 Not Found\r\n" +
						 "Content-Type: text/plain\r\n" +
						 "Content-Length: #{message.size}\r\n" +
						 "Connection: close\r\n"

		#respond with a 404 error code to indicate the file does not exist
	end

	socket.close
end
