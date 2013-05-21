################################################################################
#This file contains functions to put data into and retrieve data from byte
#arrays when sending messages over a network.
#
# Copyright (c) 2013 Bernhard Firner
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA
# or visit http://www.gnu.org/licenses/gpl-2.0.html
#
################################################################################

#Pack a 64 bit unsigned integer into a buffer
def packuint64(val)
  return [val / 2**32].pack('N') + [val % 2**32].pack('N')
end

#Unpack a uint64_t big-endian integer from the buffer
def unpackuint64(buff)
  high, low = buff.unpack('NN')
  return high * 2**32 + low
end

#Pack a 128 bit unsigned integer into a buffer
def packuint128(val)
  #TODO FIXME
  #There is no 128 bit type in ruby so pad with zeros for now
  return [0].pack('N') + [0].pack('N') + [val / 2**32].pack('N') + [val % 2**32].pack('N')
end

#Unpack a uint128_t big-endian integer from the buffer
def unpackuint128(buff)
  #TODO FIXME
  #There is no 128 bit type in ruby so pad with zeros for now
  ignore1, ignore2, high, low = buff.unpack('NNNN')
  return high * 2**32 + low
end

#Put a string into a buffer as a UTF16 string.
def strToUnicode(str)
  unistr = ""
  str.each_char { |c|
    unistr << "\x00#{c}"
  }
  return unistr
end

#Put a string into a buffer as a UTF16 string and put the length of the string
#(in characters) at the beginning of the buffer as a 4-byte big-endian integer
def strToSizedUTF16(str)
  buff = strToUnicode(str)
  return "#{[buff.length].pack('N')}#{buff}"
end

#Read a sized UTF16 string (as encoded by the strToSizedUTF16 function) and
#return the string.
def readUTF16(buff)
  len = buff.unpack('N')[0] / 2
  rest = buff[4, buff.length - 1]
  #puts "len is #{len} and rest is #{rest.length} bytes long"
  str = ""
  for i in 1..len do
    if (rest.length >= 2)
      #For now act as if the first byte will always be 0
      c = rest.unpack('UU')[1]
      rest = rest[2, rest.length - 1]
      str << c
    end
  end
  return str
end

def readUnsizedUTF16(buff)
  len = buff.length / 2
  rest = buff
  #puts "len is #{len} and rest is #{rest.length} bytes long"
  str = ""
  for i in 1..len do
    if (rest.length >= 2)
      #For now act as if the first byte will always be 0
      c = rest.unpack('UU')[1]
      rest = rest[2, rest.length - 1]
      str << c
    end
  end
  return str
end


#Take in a buffer with a sized URI in UTF 16 format.
#Return the string that was at the beginning of the buffer and
#the rest of the buffer after the string
def splitURIFromRest(buff)
  #The first four bytes are for the length of the string
  strlen = buff.unpack('N')[0]
  str = buff[0,strlen+4]
  #Make another container for everything after the string
  rest = buff[strlen+4,buff.length - 1]
  if (rest == nil)
    rest = []
  end
  if (strlen != 0)
    return (readUTF16 str), rest
  else
    return '', rest
  end
end


