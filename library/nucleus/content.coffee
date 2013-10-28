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
assert = require "assert"
asciify = require "asciify"
connect = require "connect"
logger = require "winston"
colors = require "colors"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"

{Archetype} = require "./archetype"

# This class is a content negotiation broker. It is instantiated by
# the kernel and then can be used either directly or via middleware
# to negotiate the procedure of responding to a client with the data
# using the correct protocol, meaning correct `Content-Type` header.
# This also tries to correctly set the `Content-Length` header too.
module.exports.Broker = class Broker extends Archetype

    # Every broker has to have a public constructor that accepts
    # the kernel instance as a parameter. You can override it as
    # you see fit, but be sure to invoke the super constructor and
    # it is highly advised to store the kernel instance in object.
    constructor: (@kernel) ->

    # Register the specified content negotiator with the broker. The
    # The negotiator returns a function if it can handle the request
    # and response pair. If specific negotiator cannot handle the
    # pair, it should return anything other than a function object.
    @associate: (negotiator) ->
        isValid = try _.isFunction negotiator
        assert registry = @registry or Array()
        invalid = "negotiator is not a function"
        throw new Error invalid unless isValid
        assert @registry = _.clone registry
        assert @registry.unshift negotiator
        assert negotiator in (@registry or [])
        assert negotiator.apply?; negotiator

    # Content negotiate the request/response pair to use the correct
    # protocol. The protocol is implemented by the content negotiator
    # that might or might not have been previously add to the broker.
    # The negotiator returns a function if it can handle the pair.
    negotiate: (request, response, content) ->
        registry = @constructor.registry or []
        anInternal = "no negotiatator registry"
        assert _.isArray(registry), anInternal
        assert _.isArguments params = arguments
        ending = (fn) => fn.apply this, params
        for own index, negotiator of registry
            assert bounded = negotiator.bind this
            flusher = bounded.apply this, arguments
            handles = _.isFunction(flusher) or null
            return ending flusher if handles is yes
        @output response, content.toString()

    # Output the encoded content to the response write stream. This is
    # an utility method whose implementation is tweaked to the way it
    # is being used by this class. It has to do with the way this method
    # writes out the `Content-Length` header deduced from encoded size.
    output: (response, encoded) ->
        valid = try _.isString encoded
        sent = response.headersSent or no
        invalid = "invalid encoded content"
        throw new Error invalid unless valid
        args = ["Content-Length", encoded.length]
        response.setHeader args... unless sent
        return response.write "#{encoded}"

# This class is a derived content negotiation broker that provides
# the support for sending native data as JSON encoded blob. This does
# support `Object` and `Array` as the root containers. If any other
# root data type is attempted - that is an error. The broker and the
# `sender` middleware are designed to work mostly with data objects.
module.exports.JsonBroker = class JsonBroker extends Broker

    # The actual flusher that serializes the JSON root object and
    # fluses it down to the request. This is executed if negotiator
    # successfully checks out all the criteria to invoke flusher on
    # the supplied data. It should be either an array or an object.
    @jsonFlusher: (request, response, content) ->
        type = "Content-Type".toLowerCase()
        json = "application/json".toLowerCase()
        sent = response.headersSent or undefined
        assert dump = try JSON.stringify.bind JSON
        doesHtml = response.accepts /html/, /xhtml/
        spaces = if doesHtml then 4 else undefined
        response.setHeader type, json unless sent
        jsoned = (x) -> dump x, undefined, spaces
        return @output response, jsoned content

    # Associate the JSON negotiator with the broker. This method
    # checks if the content is either `Object` or `Array`, and if
    # it is then it sets the appropriate `Content-Type` header and
    # writes out the properly encoded JSON response to the client.
    @associate (request, response, content) ->
        return unless content? and c = content
        return unless _.isArray(c) or _.isObject(c)
        return unless (try JSON.stringify(content))
        return unless _.isFunction response.accepts
        return unless _.isFunction response.write
        return unless _.isObject request.headers
        return this.constructor.jsonFlusher
