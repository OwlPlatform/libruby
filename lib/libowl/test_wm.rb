#Require rubygems for old (pre 1.9 versions of Ruby and Debian-based systems)
require 'rubygems'
require 'libowl/client_world_model.rb'
require 'libowl/solver_world_model.rb'
require 'libowl/wm_data.rb'
require 'libowl/buffer_manip.rb'

#The third argument is the origin name, which should be your solver or
#client's name
wm = SolverWorldModel.new('localhost', 7009, 'Your name here')
t = Time.now
#Make an attribute for gps location with an example value and the current time
attribs = WMAttribute.new('location.gps', ['3.14'].pack('G'), t.tv_sec * 1000 + t.usec/10**3)
#Making a solution with a single attribute
new_data = WMData.new('bus.route.example', [attribs])
#Set the second argument to true to create the object with the given
#URI if it does not already exist

arr = [new_data]
puts "Sending data"
wm.pushData([new_data], true)
#Sleep to make sure the push data message arrives before we search
sleep 1

#Make a function to print out URIs that match a search pattern
def printURIs(uris)
  puts "URI response:"
  uris.each{|uri|
    puts "\t #{uri}"
  }
end

#Now connect as a client
cwm = ClientWorldModel.new('localhost', 7010, nil, method(:printURIs))

#Search for the bus name that we just added and anything else named bus.*
puts "Searching for URIs"
cwm.sendURISearch('bus\\..*')

#Handle the next message (will be a URI search response)
cwm.handleMessage()

#Now delete the URI we added
wm.deleteURI('bus.route.example')
puts "Deleting URI and waiting for the world model to update..."
#Sleep to make sure the delete message arrives before we search
sleep 3

puts "Searching to verify that the URI has been deleted."
#Verify that it is now gone
cwm.sendURISearch('bus\\..*')

#Handle the next message (will be a URI search response)
cwm.handleMessage()

