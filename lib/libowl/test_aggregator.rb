require 'libowl/solver_aggregator'

sq = SolverAggregator.new('localhost', 7008)

#Request packets from physical layer 1, don't specify a transmitter ID or
#mask, and request packets every 4000 milliseconds
sq.sendSubscription([AggrRule.new(1, [], 4000)])

while (sq.handleMessage) do
  if (sq.available_packets.length != 0) then
    puts "Processing some packets!"
    for packet in sq.available_packets do
      puts packet
    end
  end
end

puts "connection closed"
