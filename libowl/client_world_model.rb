#This class abstracts the details of connecting to a
#GRAIL3 world model as a client.

require 'socket'
require 'buffer_manip.rb'
require 'wm_data.rb'
require 'transient_request.rb'

class ClientWorldModel
  #Message constants
  KEEP_ALIVE       = 0;
  SNAPSHOT_REQUEST = 1;
  RANGE_REQUEST    = 2;
  STREAM_REQUEST   = 3;
  ATTRIBUTE_ALIAS  = 4;
  ORIGIN_ALIAS     = 5;
  REQUEST_COMPLETE = 6;
  CANCEL_REQUEST   = 7;
  DATA_RESPONSE    = 8;
  URI_SEARCH       = 9;
  URI_RESPONSE     = 10;

  attr_accessor :alias_to_attr_name, :alias_to_origin_name
  attr_reader :connected
  @alias_to_attr_name
  @alias_to_origin_name
  @connected

  @data_callback
  @uri_response_callback

  def initialize(host, port, data_callback = nil, uri_response_callback = nil)
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

    @data_callback = data_callback
    @uri_response_callback = uri_response_callback
  end

  def close()
    @socket.close()
    @connected = false
  end

  #Handle a message of currently unknown type
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
      #puts "World Model completed request for ticket #{ticket}"
    elsif control == DATA_RESPONSE
      if (@data_callback != nil)
        @data_callback.call(decodeDataResponse(inbuff[1, inbuff.length - 1]))
      end
    elsif control == URI_RESPONSE
      if (@uri_response_callback != nil)
        @uri_response_callback.call(decodeURIResponse(inbuff[1, inbuff.length - 1]))
      end
    end
    #puts "processed message with id #{control}"
    return control
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

  #Decode a ticket message or a request complete message.
  def decodeTicketMessage(inbuff)
    return inbuff.unpack('N')[0]
  end

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

  def sendSnapshotRequest(name_pattern, attribute_patterns, ticket, start_time = 0, stop_time = 0)
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
  end

  def sendRangeRequest(name_pattern, attribute_patterns, ticket, start_time, stop_time)
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
  end

  def sendStreamRequest(name_pattern, attribute_patterns, update_interval, ticket)
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
  end

  def sendURISearch(name_pattern)
    buff = [URI_SEARCH].pack('C')
    buff += strToUnicode(name_pattern)
    #Send the message with its length prepended to the front
    @socket.send("#{[buff.length].pack('N')}#{buff}", 0)
  end

end

