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
uuid = require "node-uuid"
asciify = require "asciify"
connect = require "connect"
logger = require "winston"
events = require "events"
colors = require "colors"
nconf = require "nconf"
https = require "https"
paths = require "path"
http = require "http"
util = require "util"
fs = require "fs"

# This class is a wrapper for a context object that comes along with
# an arbitrary event sent or received at either transport or element.
# At this point this is just an abstraction for future usage that may
# or may not be later implemented. Specifically, serialization logic.
module.exports.Context = class Context extends Object

    # Defines the property that either fetches or sets the foreign
    # flag for any context instance. If the foreign flag is in place
    # that means that the context originated from outside of the scope
    # and the event that it is associated with originated on a client.
    Object.defineProperty Context::, "foreign",
        enumerable: no, value: (foreign) ->
            correct = _.isBoolean foreign
            return @$foreign unless foreign?
            invalid = "Foreign is not a boolean"
            throw new Error invalid unless correct
            @$foreign = foreign

    # Wrap the supplied source object with a new context object. At
    # this point the implementation is fairly simple and it simply
    # wraps the new instance of context around the supplied object.
    # If something other than object is supplied, it will complain.
    @wrap: (source) -> new this source

    # Unwrap the current instance of the context to return the pure
    # source object that can be transported via transport channel to
    # the interpreter without loosing the semantical information. The
    # current implementation return the sources object it was wrapped.
    unwrap: -> this
