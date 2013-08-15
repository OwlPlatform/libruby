#Message constants that indicate the purpose of a message

#Keep alive message
KEEP_ALIVE       = 0;
#Request a snapshot of the current world model state
SNAPSHOT_REQUEST = 1;
#Request a snapshot of the wm state in a time range
RANGE_REQUEST    = 2;
#Request a stream of data from the world model
STREAM_REQUEST   = 3;
#Alias an attribute from the world model
ATTRIBUTE_ALIAS  = 4;
#Alias an origin from the world model
ORIGIN_ALIAS     = 5;
#Finish a request
REQUEST_COMPLETE = 6;
#Cancel a request
CANCEL_REQUEST   = 7;
#Message contains a data response from the world model
DATA_RESPONSE    = 8;
#Search names in the world model
URI_SEARCH       = 9;
#Response to a uri search message.
URI_RESPONSE     = 10;
#Set a preference for some data origins
ORIGIN_PREFERENCE = 11;

