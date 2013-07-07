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
events = require "events"
colors = require "colors"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"

# This class is a content negotiation broker. It is instantiated by
# the kernel and then can be used either directly or via middleware
# to negotiate the procedure of responding to a client with the data
# using the correct protocol, meaning correct `Content-Type`, etc.
module.exports.Broker = class Broker extends events.EventEmitter

    # Content negotiate the request/response pair to use the correct
    # protocol. The protocol is implemented by the associated flusher
    # that might or might not have been previously associated with
    # the specified regular expression pattern that matches `Accept`.
    negotiate: (request, response, content) ->
        registry = @constructor.registry ?= {}
        for own pattern, flusher of registry
            matches = response.accepts pattern
            return flusher arguments... if matches
        response.write content.toString()

    # Register the specified content flusher with the broker. The
    # flusher is associated with the pattern that will be used to
    # match the request/response pair to be handled by the flusher.
    # Please refer to the `accepts` middleware for more information.
    @associate: (pattern, flusher) ->
        registry = @registry ?= {}
        stringified = _.isString pattern
        regexify = (s) -> new RegExp RegExp.escape s
        pattern = regexify pattern if stringified
        registry[pattern] = flusher; this
