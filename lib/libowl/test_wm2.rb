#Require rubygems for old (pre 1.9 versions of Ruby and Debian-based systems)
require 'rubygems'
require 'libowl/client_world_connection.rb'
require 'libowl/wm_data.rb'
require 'libowl/buffer_manip.rb'

if (ARGV.length != 2)
  puts "This program needs the ip address and client port of a world model to connect to!"
  exit
end

wmip = ARGV[0]
port = ARGV[1]

#Connect to the world model as a client
cwm = ClientWorldConnection.new(wmip, port)

#Search just for names
result = cwm.URISearch('.*')
puts "Found uris #{result.get()}"

#Search for all uris and get all of their attributes
puts "Searching for all URIs and attributes"
result = cwm.snapshotRequest('.*', ['.*']).get()
result.each_pair {|uri, attributes|
  puts "Found uri \"#{uri}\" with attributes:"
  attributes.each {|attr|
    puts "\t#{attr.name} is #{attr.data.unpack('G')}"
  }
}

#Get the locations of mugs with updates every second.
mug_request = cwm.streamRequest(".*\.mug\..*", ['location\..offset'], 1000)
while (cwm.connected and not mug_request.isComplete())
  result = mug_request.next()
  result.each_pair {|uri, attributes|
    puts "Found mug \"#{uri}\""
    puts "Location updates are:"
    attributes.each {|attr|
      puts "\t#{attr.name} is #{attr.data.unpack('G')}"
    }
  }
end


