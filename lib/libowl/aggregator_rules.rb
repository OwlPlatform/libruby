require 'libowl/buffer_manip'

class IDMask
  attr_accessor :id, :mask
  #Takes in id and mask numbers
  def initialize(id, mask = 2**64-1)
    @id = packuint128(id)
    @mask = packuint128(mask)
  end
end

class AggrRule
  attr_accessor :phy_layer, :txers, :update_interval

  #Physical layer (1 byte), an array of transmitter/mask values, and an 8-byte update interval in milliseconds
  def initialize(phy_layer, txers, update_interval)
    @phy_layer = phy_layer
    @txers = txers
    @update_interval = update_interval
  end
end



