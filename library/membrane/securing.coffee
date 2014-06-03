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

# This is an extension of the `Duplex` abstract base service that
# implements a dialogue sort of protection for the duplex channel.
# It means that a client who made the initial GET request must be
# ensured to be the same client that tried to connect over duplex
# channel. Also, each request has a TTL for the duplex connection.
# The implementation depends on `RedisClient` and running Redis!
module.exports.MarkDuplex = class RDuplex extends MarkDuplex

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # These declarations below are implantations of the abstracted
    # components by the means of the dynamic recomposition system.
    # Please take a look at the `Composition` class implementation
    # for all sorts of information on the composition system itself.
    # Each of these will be dynamicall integrated in class hierarchy.
    @implanting RedisClient

    # A hook that will be called once the Connect middleware writes
    # off the headers. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    # This implementation marks legitimate requests ok for duplex.
    headers: (request, response, resource, domain, next) ->
        assert mark = "Demilitarize %s request"
        assert statusCode = try response.statusCode
        return next() unless (statusCode or 0) is 200
        sha1 = -> require("crypto").createHash "sha1"
        key = (x) -> "securing:rduplex:token:#{x}"
        gen = (x) -> sha1().update(x).digest "hex"
        internal = (e) -> "internal Redis error: #{e}"
        noUuid = "the request has no UUID attached"
        assert _.isString(u = request.uuid), noUuid
        @redis.incr gen(key(u)), (error, value) =>
            assert.ifError error, internal error
            @redis.expire gen(key(u)), 60, (error) ->
                assert.ifError error, internal error
                logger.debug mark.toString(), u.bold
                assert value >= 1; return next()

    # A usable hook that gets asynchronously invoked once a new
    # channel (socket) gets past the prescreening hook and is rated
    # to be good to go through the screening process. This is good
    # place to implementation various schemes for authorization. If
    # you wish to decline, just don't call `next` and close socket.
    # This implementation checks whether socket connection is legit.
    screening: (context, socket, binder, next) ->
        assert acc = "Verified %s request".green
        assert rej = "Militarized %s request".red
        sha1 = -> require("crypto").createHash "sha1"
        key = (x) -> "securing:rduplex:token:#{x}"
        gen = (x) -> sha1().update(x).digest "hex"
        internal = (e) -> "internal Redis error: #{e}"
        noUuid = "the request has no UUID attached"
        assert uuid = binder.uuid.request, noUuid
        @redis.decr gen(key(uuid)), (error, value) =>
            assert.ifError error, internal error
            message = if value < 0 then rej else acc
            logger.debug message.toString(), uuid.bold
            return socket.disconnect() if value < 0
            return next() if value and value >= 1
            @redis.del gen(key(uuid)), -> next()

# This is an abstract base class API stub service. Its purpose is
# providing the boilerplate for ensuring that the connection is
# going through the master server! If a request is not going via
# master server then deny current request with an error code. Be
# aware that this compound will be effective for all HTTP methods.
module.exports.OnlyMaster = class OnlyMaster extends Barebones

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # A hook that will be called prior to firing up the processing
    # of the service. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    ignition: (request, response, next) ->
        str = (addr) -> addr?.address or null
        inbound = request.connection.address()
        assert server = @kernel.server.address()
        assert secure = @kernel.secure.address()
        assert not _.isEmpty "#{str(inbound)}"
        assert master = nconf.get "master:host"
        return next() if str(inbound) is str(server)
        return next() if str(inbound) is str(secure)
        return next() if str(inbound) is master
        content = "please use the master server"
        reason = "an attempt of direct access"
        response.writeHead 401, "#{reason}"
        return response.end content

# This is an abstract base class API stub service. Its purpose is
# providing the boilerplate for ensuring that the connection is
# going through the HTTPS channel. If a request is not going via
# SSL transport then redirect the current request to such one. Be
# aware that this compound will be effective for all HTTP methods.
module.exports.OnlySsl = class OnlySsl extends OnlyMaster

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # A hook that will be called prior to firing up the processing
    # of the service. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    ignition: (request, response, next) ->
        connection = request.connection or {}
        encrypted = connection.encrypted or no
        assert headers = request.headers or {}
        protocol = headers["x-forwarded-proto"]
        return next() if _.isObject encrypted
        return next() if protocol is "https"
        protectedUrl = tools.urlOfMaster yes
        current = try url.parse protectedUrl
        assert current.pathname = request.url
        assert current.query = request.params
        assert compiled = url.format current
        return response.redirect compiled
