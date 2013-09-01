###
Copyright (c) 2013, Alexander Cherniuk <ts33kr@gmail.com>
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
###

_ = require "lodash"
asciify = require "asciify"
connect = require "connect"
logger = require "winston"
events = require "eventemitter2"
{assert} = require "chai"
colors = require "colors"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"

{remote, external} = require "./remote"

# This class is not meant to be instantianted, but rather to be used
# as static class, a container. It exposes the functionality for the
# data marshalling to be applied on the data that is being transfered
# between the server site and the client site. Used on both sites.
module.exports.Marshal = remote -> class Marshal extends Object

    # Recover the sequence of values transferred from the another
    # environment. Typically you would use this on the parameter
    # list from a remote function. It performs deep deserialization
    # of objects from the plain JavaScript objects to be recovered.
    @deserialize: (sequence) -> sequence

    # Prepare the sequence of values to be transferred to another
    # environment. Typically you would use this on the parameter
    # list for a remote function. It performs deep serialization
    # of objects into the plain JavaScript objects to be passed.
    @serialize: (sequence) -> sequence
