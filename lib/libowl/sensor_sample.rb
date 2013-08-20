#Sensor sample format
class SensorSample
  attr_accessor :phy_layer, :device_id, :receiver_id, :timestamp, :rssi, :sense_data

  def initialize(phy, device_id, receiver_id, timestamp, rssi, sense_data)
    @phy_layer = phy
    @device_id = device_id
    @receiver_id = receiver_id
    @timestamp = timestamp
    @rssi = rssi
    @sense_data = sense_data
  end

  def to_s()
    return "#{@timestamp}: (phy #{@phy_layer}) #{@device_id} -> #{@receiver_id}, RSS:#{@rssi}, Datalength:#{@sense_data.length} Data:#{@sense_data.unpack('C*').join(', ')}"
  end
end
