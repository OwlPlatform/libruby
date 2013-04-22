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

class StepResponse
  def initialize(cwm, key)
    @cwm = cwm
    @request_key = key
  end

 def next()
   while (not (hasNext() or isError()))
     sleep(1)
   end
   if (isError())
     raise getError()
   else
     return @cwm.getNext(@request_key)
   end
 end

 def hasNext()
   return @cwm.hasNext(@request_key)
 end

 def isError()
   return @cwm.hasError(@request_key)
 end

 def getError()
   return @cwm.getError(@request_key)
 end

 def isComplete()
   return @cwm.isComplete(@request_key)
 end

 def cancel()
   #TODO
 end
end

