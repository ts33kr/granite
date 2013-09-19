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
assert = require "assert"
events = require "eventemitter2"
colors = require "colors"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"
url = require "url"

{Duplex} = require "./duplex"
{Barebones} = require "./skeleton"
{RedisClient} = require "./redis"
tools = require "../nucleus/tools"

# This is an extension of the `Duple` abstract base service that
# implements a dialogue sort of protection for the duplex channel.
# It means that a client who made the initial GET request must be
# ensured to be the same client that tried to connect over duplex
# channel. Also, each request has a TTL for the duplex connection.
# The implementation depends on `RedisClient` and running Redis!
module.exports.RDuplex = class RDuplex extends Duplex

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    @abstract yes

    # These invocations establish the parameters which are going
    # to be used for matching HTTP requests against this service.
    # Typically an HTTP pathname pattern and a domain name pattern.
    # Try not to put constraints on the domain, unless necessary.
    # Also, the compounds for the composition system belong here.
    @compose RedisClient

    # A hook that will be called after invoking the API method
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    postprocess: (request, response, resource, domain, next) ->
        return next() unless response.headersSent
        return next() unless response.statusCode is 200
        md5 = -> require("crypto").createHash("md5")
        key = (x) -> "securing:rduplex:token:dynamic:#{x}"
        gen = (u) -> md5().update("#{@uuid}-#{u}").digest("hex")
        internal = (e) -> "internal Redis error: #{e}"
        noUuid = "the request has not UUID attached"
        assert _.isString u = request.uuid, noUuid
        @redis.setex key(u), 60, gen(u), (error) ->
            success = not _.isObject error
            assert success, internal error
            return next()

    # A usable hook that gets asynchronously invoked once a new
    # channel (socket) gets past the prescreening hook and is rated
    # to be good to go through the screening process. This is good
    # place to implementation various schemes for authorization. If
    # you wish to decline, just don't call `next` and close socket.
    screening: (context, socket, binder, next) ->
        md5 = -> require("crypto").createHash("md5")
        key = (x) -> "securing:rduplex:token:dynamic:#{x}"
        gen = (u) -> md5().update("#{@uuid}-#{u}").digest("hex")
        internal = (e) -> "internal Redis error: #{e}"
        noUuid = "the context has no UUID attached"
        assert uuid = binder.uuid.request, noUuid
        @redis.get key(uuid), (error, value) =>
            assert not _.isObject(error), internal error
            @redis.del key(uuid), (error, number) =>
                return next() if gen(uuid) is value
                return socket.disconnect()

# This is an abstract base class API stub service. Its purpose is
# providing the boilerplate for ensuring that the connection is
# going through the HTTPS channel. If a request is not going via
# SSL transport then redirect the current request to such one.
module.exports.OnlySsl = class OnlySsl extends Barebones

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    @abstract yes

    # A hook that will be called prior to invoking the API method
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    preprocess: (request, response, resource, domain, next) ->
        connection = request?.connection
        encrypted = connection?.encrypted
        return next() if _.isObject encrypted
        protectedUrl = tools.urlWithHost yes
        current = url.parse protectedUrl
        current.pathname = request.url
        current.query = request.params
        compiled = url.format current
        response.redirect compiled
