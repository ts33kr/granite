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
    # protocol. The protocol is implemented by the content negotiator
    # that might or might not have been previously add to the broker.
    # The negotiator returns a function if it can handle the pair.
    negotiate: (request, response, content) ->
        registry = @constructor.registry ?= []
        for own index, negotiator of registry
            bounded = negotiator.bind this
            flusher = bounded arguments...
            handles = _.isFunction flusher
            return flusher arguments... if handles
        @output response, content.toString()

    # Output the encoded content to the response write stream. This is
    # an utility method whose implementation is tweaked to the way it
    # is being used by this class. It has to do with the way this method
    # writes out the `Content-Length` header deduced from encoded size.
    output: (response, encoded) ->
        valid = _.isString encoded
        areSent = response.headersSent
        invalid = "Invalid encoded content"
        throw new Error invalid unless valid
        args = ["Content-Length", encoded.length]
        response.setHeader args... unless areSent
        response.write encoded

    # Register the specified content negotiator with the broker. The
    # The negotiator returns a function if it can handle the request
    # and response pair. If specific negotiator cannot handle the
    # pair, it should return anything other than a function object.
    @associate: (negotiator) ->
        isValid = _.isFunction negotiator
        invalid = "Checker is not a valid method"
        throw new Error invalid unless isValid
        (@registry ?= []).unshift negotiator

    # Associate the JSON negotiator with the broker. This method
    # checks if the content is either `Object` or `Array`, and if
    # it is then it sets the appropriate `Content-Type` header and
    # writes out the properly encoded JSON response to the client.
    @associate (request, response, content) ->
        isArray = _.isArray content
        isObject = _.isObject content
        return unless isArray or isObject
        (request, response, content) =>
            jsonType = "application/json"
            doesHtml = response.accepts /html/
            spaces = if doesHtml then 4 else null
            response.setHeader "Content-Type", jsonType
            jsoned = (x) -> JSON.stringify x, null, spaces
            @output response, jsoned content
