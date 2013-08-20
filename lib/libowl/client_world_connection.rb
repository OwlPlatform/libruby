################################################################################
#This file defines the ClientWorldConnection class, an object that represents
#a network connection to an Owl world model.
#
# Copyright (c) 2013 Bernhard Firner
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA
# or visit http://www.gnu.org/licenses/gpl-2.0.html
#
################################################################################
require 'socket'
require 'libowl/message_constants.rb'
require 'libowl/wm_data.rb'
require 'libowl/buffer_manip.rb'
require 'libowl/response.rb'
require 'libowl/step_response.rb'

require 'thread'

##
#A connection between a client and a world model.
#This class spawns a thread to handle incoming messages and returns
#instances of the Response and StepResponse classes to fulfill client
#requests. If a thread cannot be used then an instance of the class
#ClientWorldModel should be used instead.
class ClientWorldConnection
  #Indicates if this object is successfully connected to a world model.
  attr_reader :connected
  @alias_to_attr_name
  @alias_to_origin_name
  #Data for outstanding requests. This is a map of lists with a nil entry
  #inserted into the list when the request is complete. Other entries
  #are maps of URIs to their attributes
  @next_data
  @request_errors
  @connected
  @promise_mutex
  @cur_key
  #Remember the order of URI searches. They do not use tickets so we must
  #manage the order of URI search requests locally
  @uri_search_keys
  @single_response


  ##
  #Creates a new connection and spawns a thread to call handleMessage
  #automatically.
  def initialize(host, port)
    @promise_mutex = Mutex.new
    @cur_key = 0
    @uri_search_keys = []
    @single_response = {}
    @connected = false
    @host = host
    @port = port
    @socket = TCPSocket.open(host, port)
    handshake = ""
    ver_string = "GRAIL client protocol"
    #The handshake is the length of the message, the protocol string, and the version (0).
    handshake << [ver_string.length].pack('N') << ver_string << "\x00\x00"
    #Send a handshake and then receive one
    @socket.send(handshake, 0)
    inshake = @socket.recvfrom(handshake.length)[0]
    while (inshake.length < handshake.length)
      #puts "Waiting for #{handshake.length - inshake.length} byte more of handshake."
      inshake += @socket.recvfrom(handshake.length - inshake.length)[0]
    end

    @connected = true
    for i in 1..handshake.length
      if handshake[i] != inshake[i]
        puts "Handshake failure!"
        puts "For byte i we sent #{handshake[i]} but got #{inshake[i]}"
        @connected = false
      end
    end

    @alias_to_attr_name = {}
    @alias_to_origin_name = {}
    @next_data = {}
    @request_errors = {}

    #Start the listening thread
    @listen_thread = Thread.new do
      while (@connected)
        handleMessage()
      end
    end
  end

  ##
  #Close this connection
  def close()
    @socket.close()
    @connected = false
  end

  ##
  #Handle a message of currently unknown type. This is automatically
  #handled by a thread spawned at object creation.
  def handleMessage()
    #puts "Handling message..."
    #Get the message length as n unsigned integer
    inlen = (@socket.recvfrom(4)[0]).unpack('N')[0]
    inbuff = @socket.recvfrom(inlen)[0]
    #Keep reading until the entire packet is read
    #TODO This can block forever if a communication error occurs.
    while (inbuff.length < inlen) 
      inbuff += @socket.recvfrom(inlen-inbuff.length)[0]
    end
    #Byte that indicates message type
    control = inbuff.unpack('C')[0]
    if control == ATTRIBUTE_ALIAS
      decodeAttributeAlias(inbuff[1, inbuff.length - 1])
    elsif control == ORIGIN_ALIAS
      decodeOriginAlias(inbuff[1, inbuff.length - 1])
    elsif control == REQUEST_COMPLETE
      ticket = decodeTicketMessage(inbuff[1, inbuff.length-1])
      #Mark the corresponding request as complete by appending a nil value
      @promise_mutex.synchronize do
        if (@next_data.has_key? ticket)
          #Need an empty has in case a step response is waiting for a value
          @next_data[ticket].push(nil)
        end
      end
    elsif control == DATA_RESPONSE
      data = decodeDataResponse(inbuff[1, inbuff.length - 1])
      #If the request was cancelled then don't try to push any more data
      @promise_mutex.synchronize do
        if (@next_data.has_key? data.ticket)
          @next_data[data.ticket][-1].store(data.uri, data.attributes)
          #Add a new entry for the next value
          if (not @single_response[data.ticket])
            @next_data[data.ticket].push({})
          end
        end
      end
    elsif control == URI_RESPONSE
      uris = decodeURIResponse(inbuff[1, inbuff.length - 1])
      @promise_mutex.synchronize do
        uri_ticket = @uri_search_keys.shift
        puts "Finishing uri response for ticket #{uri_ticket}"
        #Make world model entries with no attributes for each URI
        uris.each{|uri| @next_data[uri_ticket][-1].store(uri, [])}
        #This request is complete now so push a nil value to finish it
        @next_data[uri_ticket].push(nil)
      end
    end
    #puts "processed message with id #{control}"
    return control
  end


  ##
  #See if a request is still being serviced (only for StepResponse - regular
  #requests can't be cancelled since they only have a single response).
  def isComplete(key)
    @promise_mutex.synchronize do
      if ((not @next_data.has_key?(key)))
        return true
      elsif (@next_data[key].empty?)
        return false
      else
        return (nil == @next_data[key][-1])
      end
    end
  end

  ##
  #getNext should only be called if hasNext is true, otherwise
  #the future will be given an exception since there is no data.
  #The response and stepResponse classes can call this directly
  #so there usually won't be a need for a developer to call this
  #function directly.
  def hasNext(key)
    @promise_mutex.synchronize do
      return ((@next_data.has_key? key) and (@next_data[key].length > 1))
    end
  end

  ##
  #Get the data from the response object corresponding to this key.
  #The response and stepResponse classes can call this directly
  #so there usually won't be a need for a developer to call this
  #function directly.
  def getNext(key)
    if (not hasNext(key))
      raise "No next value in request"
    else
      data = {}
      @promise_mutex.synchronize do
        data = @next_data[key].shift
      end
      #If there is no more data in this request delete its associatd data
      if (isComplete(key))
        @request_errors.delete key
        @next_data.delete key
      end
      return data
    end
  end

  ##
  #Check if a request has an error.
  #The response and stepResponse classes can call this directly
  #so there usually won't be a need for a developer to call this
  #function directly.
  def hasError(key)
    @promise_mutex.synchronize do
      return (@request_errors.has_key? key)
    end
  end

  ##
  #Get error (will return std::exception("No error") is there is none
  def getError(key)
    if (not hasError(key))
      raise "no error but getError called"
    else
      @promise_mutex.synchronize do
        return @request_errors[key]
      end
    end
  end

  #Decode attribute alias message
  def decodeAttributeAlias(inbuff)
    num_aliases = inbuff.unpack('N')[0]
    rest = inbuff[4, inbuff.length - 1]
    for i in 1..num_aliases do
      attr_alias = rest.unpack('N')[0]
      name, rest = splitURIFromRest(rest[4, rest.length - 1])
      #Assign this name to the given alias
      @alias_to_attr_name[attr_alias] = name
    end
  end

  #Decode origin alias message
  def decodeOriginAlias(inbuff)
    num_aliases = inbuff.unpack('N')[0]
    rest = inbuff[4, inbuff.length - 1]
    for i in 1..num_aliases do
      origin_alias = rest.unpack('N')[0]
      name, rest = splitURIFromRest(rest[4, rest.length - 1])
      #Assign this name to the given alias
      @alias_to_origin_name[origin_alias] = name
    end
  end

  ##
  #Decode a ticket message or a request complete message.
  def decodeTicketMessage(inbuff)
    return inbuff.unpack('N')[0]
  end

  ##
  #Decode a URI response message, returning an array of WMData
  def decodeURIResponse(inbuff)
    uris = []
    if (inbuff != nil)
      rest = inbuff
      while (rest.length > 4)
        name, rest = splitURIFromRest(rest)
        uris.push(name)
      end
    end
    return uris
  end

  ##
  #Decode a data response message, returning an array of WMData
  def decodeDataResponse(inbuff)
    attributes = []
    object_uri, rest = splitURIFromRest(inbuff)
    ticket = rest.unpack('N')[0]
    total_attributes = rest[4, rest.length - 1].unpack('N')[0]
    rest = rest[8, rest.length]
    #puts "Decoding #{total_attributes} attributes"
    for i in 1..total_attributes do
      name_alias = rest.unpack('N')[0]
      creation_date = unpackuint64(rest[4, rest.length - 1])
      expiration_date = unpackuint64(rest[12, rest.length - 1])
      origin_alias = rest[20, rest.length - 1].unpack('N')[0]
      data_len = rest[24, rest.length - 1].unpack('N')[0]
      data = rest[28, data_len]
      rest = rest[28+data_len, rest.length - 1]
      attributes.push(WMAttribute.new(@alias_to_attr_name[name_alias], data, creation_date, expiration_date, @alias_to_origin_name[origin_alias]))
    end
    return WMData.new(object_uri, attributes, ticket)
  end

  ##
  #Issue a snapshot request, returning a Response object for the request.
  def snapshotRequest(name_pattern, attribute_patterns, start_time = 0, stop_time = 0)
    #Set up a ticket and mark this request as active by adding it to next_data
    ticket = 0
    @promise_mutex.synchronize do
      ticket = @cur_key
      @cur_key += 1
      @single_response.store(ticket, true)
      @next_data[ticket] = [{}]
    end
    buff = [SNAPSHOT_REQUEST].pack('C')

    buff += [ticket].pack('N')
    buff += strToSizedUTF16(name_pattern)
    buff += [attribute_patterns.length].pack('N')

    attribute_patterns.each{|pattern|
      buff += strToSizedUTF16(pattern)
    }

    buff += packuint64(start_time)
    buff += packuint64(stop_time)
    #Send the message with its length prepended to the front
    @socket.send("#{[buff.length].pack('N')}#{buff}", 0)
    return Response.new(self, ticket)
  end

  ##
  #Issue a range request, returning a Response object for the request.
  def rangeRequest(name_pattern, attribute_patterns, start_time, stop_time)
    #Set up a ticket and mark this request as active by adding it to next_data
    ticket = 0
    @promise_mutex.synchronize do
      ticket = @cur_key
      @cur_key += 1
      @single_response.store(ticket, false)
      @next_data[ticket] = [{}]
    end
    buff = [RANGE_REQUEST].pack('C')

    buff += [ticket].pack('N')
    buff += strToSizedUTF16(name_pattern)
    buff += [attribute_patterns.length].pack('N')

    attribute_patterns.each{|pattern|
      buff += strToSizedUTF16(pattern)
    }

    buff += packuint64(start_time)
    buff += packuint64(stop_time)

    #Send the message with its length prepended to the front
    @socket.send("#{[buff.length].pack('N')}#{buff}", 0)
    return StepResponse.new(self, ticket)
  end

  ##
  #Issue a stream request, returning a StepResponse object for the request.
  def streamRequest(name_pattern, attribute_patterns, update_interval)
    #Set up a ticket and mark this request as active by adding it to next_data
    ticket = 0
    @promise_mutex.synchronize do
      ticket = @cur_key
      @cur_key += 1
      @single_response.store(ticket, false)
      @next_data[ticket] = [{}]
    end
    buff = [STREAM_REQUEST].pack('C')

    buff += [ticket].pack('N')
    buff += strToSizedUTF16(name_pattern)
    buff += [attribute_patterns.length].pack('N')

    attribute_patterns.each{|pattern|
      buff += strToSizedUTF16(pattern)
    }

    buff += packuint64(0)
    buff += packuint64(update_interval)

    #Send the message with its length prepended to the front
    @socket.send("#{[buff.length].pack('N')}#{buff}", 0)
    return StepResponse.new(self, ticket)
  end

  ##
  #Search for any objects in the world model matching the given
  #POSIX REGEX pattern.
  def URISearch(name_pattern)
    #Set up a ticket and mark this request as active by adding it to next_data
    ticket = 0
    @promise_mutex.synchronize do
      ticket = @cur_key
      @cur_key += 1
      @single_response.store(ticket, true)
      @next_data[ticket] = [{}]
      @uri_search_keys.push(ticket)
    end
    buff = [URI_SEARCH].pack('C')
    buff += strToUnicode(name_pattern)
    #Send the message with its length prepended to the front
    @socket.send("#{[buff.length].pack('N')}#{buff}", 0)
    return Response.new(self, ticket)
  end

  ##
  #Set a preference in the world model for certain origins.
  def setOriginPreference(origin_weights)
    buff = [ORIGIN_PREFERENCE].pack('C')
    #Each origin weight should be a pair of a name and a value
    origin_weights.each{|ow|
      #It's okay to pack using N since this operates the same
      #for signed and unsigned values.
      buff += strToSizedUTF16(ow[0]) + [ow[1]].pack('N')
    }
    #Send the message with its length prepended to the front
    @socket.send("#{[buff.length].pack('N')}#{buff}", 0)
  end

  ##Cancel a request with the given ticket number
  def cancelRequest(ticket_number)
    buff = [CANCEL_REQUEST].pack('C')
    #Now append the ticket number as a 4 byte value
    buff += [ticket_number].pack('N')
    #Send the message with its length prepended to the front
    @socket.send("#{[buff.length].pack('N')}#{buff}", 0)
  end
end

