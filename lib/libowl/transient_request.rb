#Transient specification - one attribute name an a list of name expressions

class TransientRequest
  #Attribute name
  @name
  #Requested expressions
  @expressions
  
  def initialize(name, expressions)
    @name = name
    @expressions = expressions
  end
end

