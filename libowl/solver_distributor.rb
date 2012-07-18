#This class abstracts the details of connecting to a
#GRAIL3 distributor as a solver.

require 'socket'
require 'buffer_manip.rb'

class SolverDistributor
  #Message constants
  KEEP_ALIVE         = 0
  TYPE_SPECIFICATION = 1
  SOLVER_DATA        = 2
  TYPE_REQUEST       = 3

  def initialize(host, port, solution_types)
    @connected = false
    @host = host
    @port = port
    @solution_types = solution_types

    connect()
  end

  def connect()
    @socket = TCPSocket.open(@host, @port)
    handshake = ""
    ver_string = "GRAIL distributor protocol"
    #The handshake is the length of the message, the protocol string, and the version (0).
    handshake << [ver_string.length].pack('N') << ver_string << "\x00\x00"
    #Receive a handshake and then send one
    @socket.recvfrom(handshake.length)
    @socket.send(handshake, 0)

    #Map from solution names to their aliases
    @name_to_alias = {}

    #Set up known solution types and send them to the distributor
    if (@solution_types.length > 0)
      addSolutionTypes(@solution_types)
    end
  end

  #Send a solution type message to the distributor
  def addSolutionTypes(sol_types)
    #Pack the number of solution types
    buff = [TYPE_SPECIFICATION].pack('C') + [sol_types.length].pack('N')
    for soln in sol_types do
      #Remember the alias for the user
      @name_to_alias[soln.data_uri] = soln.type_alias
      buff += [soln.type_alias].pack('N')
      buff += strToSizedUTF16(soln.data_uri)
    end
    #Send the message prepended with the length
    @socket.send("#{[buff.length].pack('N')}#{buff}", 0)
  end

  #Send solutions to the distributor
  #Accepts the region uri, the time that this solution occurs, and an array of
  #triples containing the target URI, the solution URI, and the solution data
  def sendSolutions(region_uri, solution_time, target_soln_data_triples)
    #Start assembling a solution message.
    buff = [SOLVER_DATA].pack('C')
    #Region URI and solution time
    buff += strToSizedUTF16(region_uri) + packuint64(solution_time)
    #Reject any solutions that don't have an alias
    bad_solutions = target_soln_data_triples.select {|triple| nil == @name_to_alias[triple[1]]}
    for bad in bad_solutions do puts "Rejecting unknown solution \"#{bad[0]}:#{bad[1]}\"" end
      
    good_solutions = target_soln_data_triples.select {|triple| nil != @name_to_alias[triple[1]]}
    #The number of solutions
    buff += [good_solutions.length].pack('N')
    for triple in good_solutions do
      #Push the alias, target URI, and data into the buffer
      buff += [@name_to_alias[triple[1]]].pack('N')
      buff += strToSizedUTF16(triple[0])
      buff += [triple[2].length].pack('N') + triple[2]
    end
    #Send the message prepended with the length
    #Try twice (in case we timed out)
    if (not @socket.send("#{[buff.length].pack('N')}#{buff}", 0)) then
      connect()
      @socket.send("#{[buff.length].pack('N')}#{buff}", 0)
    end
  end
end

