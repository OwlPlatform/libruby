#Solution types used when communicating with the distributor

class SolutionType
  #Used for auto-incremented alias numbers
  @@num_aliases = 0
  attr_accessor :type_alias, :data_uri
  #Number to refer to this type
  @type_alias
  #The uri of this type
  @data_uri
  
  def initialize(uri, type_alias = -1)
    @data_uri = uri
    #Auto-increment to the next alias number if one wasn't explicitly provided
    if (type_alias >= 0)
      @type_alias = type_alias
    else
      @type_alias = @@num_aliases
      @@num_aliases += 1
    end
  end
end

class SolutionData
  attr_accessor :region, :time, :target, :sol_name, :data
  #Region of the solution
  @region
  #Time of the solution (milliseconds since midnight Jan 1, 1970)
  @time
  #Target of the solution
  @target
  #Name of this solution
  @sol_name
  #Binary buffer with solution data
  @data

  def initialize(region, time, target, sol_name, data)
    @region = region
    @time = time
    @target = target
    @sol_name = sol_name
    @data = data
  end

  def to_s()
    return "#{@region}:#{@target}:#{@sol_name} @ time #{@time} -> #{@data.unpack('H*')}"
  end
end

