#This class abstracts the details of connecting to a
#GRAIL3 world model as a solver.

require 'socket'
require 'libowl/buffer_manip.rb'
require 'libowl/wm_data.rb'
require 'libowl/transient_request.rb'

class SolverWorldModel
  #TODO Move constants to their own file

  #Message constants
  KEEP_ALIVE       = 0;
  TYPE_ANNOUNCE    = 1;
  START_TRANSIENT  = 2;
  STOP_TRANSIENT   = 3;
  SOLVER_DATA      = 4;
  CREATE_URI       = 5;
  EXPIRE_URI       = 6;
  DELETE_URI       = 7;
  EXPIRE_ATTRIBUTE = 8;
  DELETE_ATTRIBUTE = 9;

  attr_accessor :name_to_alias, :alias_to_name, :connected
  @name_to_alias
  @alias_to_name

  #The origin string of this solver
  @origin

  #Callback for when the world model requests transient data
  @start_transient_callback
  #Callback for when the world model no longer wants a transient type
  @stop_transient_callback

  #Handle a message of currently unknown type
  def handleMessage()
    #Get the message length as n unsigned integer
    inlen = (@socket.recvfrom(4)[0]).unpack('N')[0]
    inbuff = @socket.recvfrom(inlen)[0]
    #Byte that indicates message type
    control = inbuff.unpack('C')[0]
    if control == START_TRANSIENT
      if (@start_transient_callback != nil)
        @start_transient_callback.call(decodeStartTransient(inbuff[1, inbuff.length - 1]))
      end
    elsif control == STOP_TRANSIENT
      if (@stop_transient_callback != nil)
        @stop_transient_callback.call(decodeStopTransient(inbuff[1, inbuff.length - 1]))
      end
    end
    return control
  end

  #Decode a start transient message
  def decodeStartTransient(inbuff)
    num_aliases = inbuff.unpack('N')[0]
    rest = inbuff[4, inbuff.length - 1]
    new_trans_requests = []
    for i in 1..num_aliases do
      type_alias = rest.unpack('N')[0]
      total_expressions = rest.unpack('N')[0]
      t_request = TransientRequest.new(type_alias, [])
      for j in 1..total_expressions do
        exp, rest = splitURIFromRest(rest[4, rest.length - 1])
        t_request.expressions.push(exp)
      end
      new_trans_requests.push(t_request)
    end
    return new_trans_requests
  end

  #Decode a stop transient message
  def decodeStopTransient(inbuff)
    num_aliases = inbuff.unpack('N')[0]
    rest = inbuff[4, inbuff.length - 1]
    new_trans_requests = []
    for i in 1..num_aliases do
      type_alias = rest.unpack('N')[0]
      total_expressions = rest.unpack('N')[0]
      t_request = TransientRequest.new(type_alias, [])
      for j in 1..total_expressions do
        exp, rest = splitURIFromRest(rest[4, rest.length - 1])
        t_request.expressions.push(exp)
      end
      new_trans_requests.push(t_request)
    end
    return new_trans_requests
  end

  def initialize(host, port, origin, start_transient_callback = nil, stop_transient_callback = nil)
    @origin = origin
    @connected = false
    @host = host
    @port = port
    @socket = TCPSocket.open(host, port)
    handshake = ""
    ver_string = "GRAIL world model protocol"
    #The handshake is the length of the message, the protocol string, and the version (0).
    handshake << [ver_string.length].pack('N') << ver_string << "\x00\x00"
    #Receive a handshake and then send one
    @socket.send(handshake, 0)
    inshake = @socket.recvfrom(handshake.length)[0]
    while (inshake.length < handshake.length)
      puts "Waiting for #{handshake.length - inshake.length} byte more of handshake."
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

    @name_to_alias = {}
    @alias_to_name = {}

    @start_transient_callback = start_transient_callback
    @stop_transient_callback = stop_transient_callback
  end

  ##
  #Close this connection
  def close()
    @socket.close()
    @connected = false
  end

  #Add some SolutionType objects to the known list
  def addSolutionTypes(attributes)
    new_aliases = []
    attributes.each { |attr|
      if (@name_to_alias[attr.name] == nil)
        new_alias = @name_to_alias.length
        @name_to_alias[attr.name] = new_alias
        @alias_to_name[new_alias] = attr.name
        new_aliases.push([attr.name, new_alias])
      end
    }
    if (new_aliases.length > 0)
      makeTypeAnnounce(new_aliases)
    end
  end

  def makeTypeAnnounce(type_pairs)
    buff = [TYPE_ANNOUNCE].pack('C') + [type_pairs.length].pack('N')
    for pair in type_pairs do
      #TODO Not supporting transient types for now so always write a zero
      #for the transient on/off byte
      buff += [pair[1]].pack('N') + strToSizedUTF16(pair[0]) + [0].pack('C')
    end
    #Add the origin string to the end of the message
    buff += strToUnicode(@origin)
    @socket.send("#{[buff.length].pack('N')}#{buff}", 0)
  end

  ##
  #Push URI attributes, automatically declaring new solution types
  #as non-stremaing types if they were not previously declared.
  def pushData(wmdata_vector, create_uris = false)
    buff = [SOLVER_DATA].pack('C')
    if (create_uris)
      buff += [1].pack('C')
    else
      buff += [0].pack('C')
    end

    #Push back the total number of solutions
    total_solns = wmdata_vector.inject(0){|sum, wmdata|
      sum + wmdata.attributes.length
    }
    buff += [total_solns].pack('N')

    #Now create each solution and push it back into the buffer
    wmdata_vector.each{|wmdata|
      #First make sure all of the solutions types have been declared
      addSolutionTypes(wmdata.attributes)
      #Now push back this attribute's data using an alias for the name
      wmdata.attributes.each{|attr|
        buff += [@name_to_alias[attr.name]].pack('N') +
          packuint64(attr.creation) +
          strToSizedUTF16(wmdata.uri) + [attr.data.length].pack('N') + attr.data
      }
    }
    #Send the message with its length prepended to the front
    @socket.send("#{[buff.length].pack('N')}#{buff}", 0)
  end

  ##
  #Create an object with the given name in the world model.
  def createURI(uri, creation_time)
    buff = [CREATE_URI].pack('C')
    buff += strToSizedUTF16(uri)
    buff += packuint64(creation_time)
    buff += strToUnicode(@origin)
    #Send the message with its length prepended to the front
    @socket.send("#{[buff.length].pack('N')}#{buff}", 0)
  end

  ##
  #Expire the object with the given name in the world model, indicating that it
  #is no longer valid after the given time.
  def expireURI(uri, expiration_time)
    buff = [EXPIRE_URI].pack('C')
    buff += strToSizedUTF16(uri)
    buff += packuint64(expiration_time)
    buff += strToUnicode(@origin)
    #Send the message with its length prepended to the front
    @socket.send("#{[buff.length].pack('N')}#{buff}", 0)
  end

  ##
  #Delete an object in the world model.
  def deleteURI(uri)
    buff = [DELETE_URI].pack('C')
    buff += strToSizedUTF16(uri)
    buff += strToUnicode(@origin)
    #Send the message with its length prepended to the front
    @socket.send("#{[buff.length].pack('N')}#{buff}", 0)
  end

  #TODO Expire a URI's attribute
  #TODO Delete a URI's attribute
end
