################################################################################
#This file defines the StepResponse class, an object that represents data from
#an owl world model that is sent for a streaming request. An instance of this
#class will continually yield new data until the streaming request is cancelled.
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

#Incrementeal response of a client streaming request to the world model
class StepResponse
  ##
  #Initialize with the ClientWorldConnection that spawed this Response and
  #the key of the request.
  def initialize(cwc, key)
    @cwc = cwc
    @request_key = key
  end

  ##
  #Get the data of this StepResponse, blocking until that data is ready or
  #an error occurs.
 def next()
   while (not (hasNext() or isError()))
     sleep(1)
   end
   if (isError())
     raise getError()
   else
     return @cwc.getNext(@request_key)
   end
 end

  ##
  #Returns true if data is available for a call to next().
 def hasNext()
   return @cwc.hasNext(@request_key)
 end

  ##
  #Returns true if an error has occured.
 def isError()
   return @cwc.hasError(@request_key)
 end

  ##
  #Get the error that occured.
 def getError()
   return @cwc.getError(@request_key)
 end

 ##
 #True if this streaming request will have no more data.
 def isComplete()
   return @cwc.isComplete(@request_key)
 end

 ##
 #Cancel the streaming request.
 def cancel()
   return @cwc.cancelRequest(@request_key)
 end
end

