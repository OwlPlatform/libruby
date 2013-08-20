################################################################################
#This file defines the Response class, an object that represents data from
#an owl world model that is sent for a non-streaming request.
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

#Response of a client request to the world model
class Response
  ##
  #Initialize with the ClientWorldConnection that spawed this Response and
  #the key of the request.
  def initialize(cwc, key)
    @cwc = cwc
    @request_key = key
  end

  ##
  #Get the data of this Response, blocking until that data is ready or
  #an error occurs.
  def get()
    while (not (ready() or isError()))
      sleep(1)
    end
    if (isError())
      raise getError()
    else
      return @cwc.getNext(@request_key)
    end
  end

  ##
  #Returns true if data is available for a call to get().
  def ready()
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
  #Cancel this request.
  def cancel()
    return @cwc.cancelRequest(@request_key)
  end
end
