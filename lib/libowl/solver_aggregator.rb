#This class abstracts the details of connecting to a
#GRAIL3 aggregator as a solver.
#Solvers subscribe to the aggregator and then receive packets.

require 'socket'
require 'libowl/buffer_manip.rb'
require 'libowl/aggregator_rules.rb'
require 'libowl/sensor_sample.rb'

class SolverAggregator
  #Message constants
  KEEP_ALIVE            = 0
  CERTIFICATE           = 1
  ACK_CERTIFICATE       = 2 #There is no message for certificate denial
  SUBSCRIPTION_REQUEST  = 3
  SUBSCRIPTION_RESPONSE = 4
  DEVICE_POSITION       = 5
  SERVER_SAMPLE         = 6
  BUFFER_OVERRUN        = 7

  attr_accessor :available_packets, :cur_rules, :connected
  @available_packets
  @cur_rules

  def initialize(host, port)
    @connected = false
    @host = host
    @port = port
    @socket = TCPSocket.open(host, port)
    handshake = ""
    ver_string = "GRAIL solver protocol"
    #The handshake is the length of the message, the protocol string, and the version (0).
    handshake << [ver_string.length].pack('N') << ver_string << "\x00\x00"
    #Receive a handshake and then send one
    @socket.recvfrom(handshake.length)
    @socket.send(handshake, 0)

    @available_packets = []
    @cur_rules = []
  end

  def close()
    @socket.close()
    @connected = false
  end

  #Handle a message of currently unknown type
  def handleMessage()
    #Get the message length as n unsigned integer
    inlen = (@socket.recvfrom(4)[0]).unpack('N')[0]
    if (nil == inlen) then
      return nil
    end
    inbuff = @socket.recvfrom(inlen)[0]
    #Byte that indicates message type
    control = inbuff.unpack('C')[0]
    case control
    when SUBSCRIPTION_RESPONSE
      decodeSubResponse(inbuff[1, inbuff.length - 1])
      return SUBSCRIPTION_RESPONSE
    when SERVER_SAMPLE
      decodeServerSample(inbuff[1, inbuff.length - 1])
      return SERVER_SAMPLE
    else
      KEEP_ALIVE
    end
  end

  #Decode a subscription response and store the current rules in @cur_rules
  def decodeSubResponse(inbuff)
    puts "Got subscription response!"
    num_rules = inbuff.unpack('N')[0]
    rest = inbuff[4, inbuff.length - 1]
    rules = []
    for i in 1..num_rules do
      phy_layer, num_txers = rest.unpack('CN')
      txlist = []
      rest = rest[5, rest.length - 1]
      for j in 1..num_txers do
        txlist.push([rest[0, 16], rest[16, 16]])
        rest = rest[32, rest.length - 1]
      end
      update_interval = unpackuint64(rest)
      rest = rest[8, rest.length - 1]
      rule = AggrRule.new(phy_layer, txlist, update_interval)
      rules.push(rule)
    end
    @cur_rules = rules
  end

  #Decode a server sample message
  def decodeServerSample(inbuff)
    if (inbuff != nil)
      phy_layer = inbuff.unpack('C')
      rest = inbuff[1, inbuff.length - 1]
      txid = unpackuint128(rest)
      rxid = unpackuint128(rest[16, rest.length - 1])
      rest = rest[32, rest.length - 1]
      timestamp, rssi = rest.unpack('Gg')
      sense_data = rest[12, rest.length - 1]
      @available_packets.push(SensorSample.new(phy_layer, txid, rxid, timestamp, rssi, sense_data))
    end
  end

  def sendSubscription(rules)
    #Start assembling a request message
    buff = [SUBSCRIPTION_REQUEST].pack('C')
    #Number of rules
    buff += [rules.length].pack('N')
    for rule in rules do
      buff += [rule.phy_layer].pack('C')
      buff += [rule.txers.length].pack('N')
      #Push each transmitter/mask pair
      for txer in rule.txers do
        buff += txer.id + txer.mask
      end
      buff += packuint64(rule.update_interval)
    end
    #Send the message prepended with the length
    @socket.send("#{[buff.length].pack('N')}#{buff}", 0)

    #Get the subscription response
    handleMessage()
  end

end
