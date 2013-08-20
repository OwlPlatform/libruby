#Solution types used when communicating with the world model

##
#Function to fetch the current time in milliseconds. This is the time format
#used in the Owl system and is included in every attribute pushed into the
#world model and every attribute retrieved from the world model.
def getMsecTime()
  t = Time.now
  return t.tv_sec * 1000 + t.usec/10**3
end

class WMAttribute
  attr_accessor :name, :data, :creation, :expiration, :origin
  #Name of this attribute
  @name
  #Binary buffer of attribute data
  @data
  #The creation and expiration dates of this attribute
  #in milliseconds since midnight Jan 1, 1970
  @creation
  @expiration
  #The origin of this data
  @origin

  def initialize(name, data, creation, expiration = 0, origin = "empty")
    @name = name
    @data = data
    @creation = creation
    @expiration = expiration
    @origin = origin
  end

  def to_s()
    return "\t#{@name}, #{@creation}, #{@expiration}, #{@origin}: #{@data.unpack('H*')}\n"
  end
end

class WMData
  attr_accessor :uri, :attributes, :ticket
  #The object that this data modifies
  @uri
  #The attributes of the object
  @attributes
  #The request ticket that this data is associated with
  @ticket

  def initialize(uri, attributes, ticket = 0)
    @uri = uri
    @attributes = attributes
    @ticket = ticket
  end

  def to_s()
    str = "#{@uri}:\n"
    for attr in @attributes do
      str += "\t#{attr.name}, #{attr.creation}, #{attr.expiration}, #{attr.origin}: #{attr.data.unpack('H*')}\n"
    end
    return str
  end
end

