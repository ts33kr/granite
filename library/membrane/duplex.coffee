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
assert = require "assert"
colors = require "colors"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"

tools = require "./../nucleus/tools"
extendz = require "./../nucleus/extends"
compose = require "./../nucleus/compose"

{format} = require "util"
{STATUS_CODES} = require "http"
{remote, external} = require "./remote"
{Barebones} = require "./skeleton"
{Screenplay} = require "./visual"

# This abstract base class can be used as either a direct parent or
# a compount to the `Screenplay` abstract service. It provides the
# unique ability of half duplex data exchange between the external
# code that is executed on the call site via `Screenplay` facility
# and an instance of the service that resides on the server site.
module.exports.Duplex = class Duplex extends Screenplay

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    @abstract yes

    # A utility method to mark the certain function as the provider.
    # The method returns the original function back so it can be used
    # as the normal function, nothing disrupts that. When function is
    # marked as a provider, it will be exposed via Socket.IO channel
    # that this compound/ABC sets up: a half duplex web sockets channel.
    @provider: (method) ->
        noMethod = "a #{method} is not a function"
        invalidArgs = "has to have at least 1 parameter"
        assert _.isFunction(method), noMethod
        assert method.length >= 1, invalidArgs
        method.provider = Object.create {}
        method.providing = (s) -> (args..., callback) ->
            respond = -> callback.apply this, arguments
            respond.socket = s; method args..., respond
        method.origin = this
        return method

    # This server side method is called on the context prior to the
    # context being compiled and flushed down to the client site. The
    # method is wired in an synchronous way for greater functionality.
    # This is the place where you would be importing the dependencies.
    prelude: (context, request, next) ->
        pure = /[a-zA-Z0-9/-_]+/.test @location()
        assert pure, "location is not pure enough"
        context.scripts.push "/socket.io/socket.io.js"
        context.sources.push "var __slice = [].slice"
        context.duplex = tools.urlWithHost yes, @location()
        context.providers = new Array
        _.forIn this, (value, name, service) =>
            providing = value?.providing or null
            return unless _.isFunction providing
            context.providers.push name
        return next()

    # This is an external method that will be automatically executed
    # on the client site by the duplex implementation. It sets up a
    # client end of the Socket.IO channel and creates wrapper around
    # all the providers residing in the current service implementation.
    # Refer to other `Duplex` methods for understanding what goes on.
    setupDuplexChannel: @autocall ->
        try @socket = io.connect @duplex catch error
            message = "blew up Socket.IO: #{error.message}"
            error.message = message.toString(); throw error
        failed = "failed to created Socket.IO connection"
        throw new Error failed unless @socket.emit
        for provider in @providers then do (provider) =>
            console.log "setting up provider: #{provider}"
            this[provider] = (archarguments...) ->
                tail = archarguments[archarguments.length - 1]
                noCallback = "#{provider} call has no callback"
                throw new Error noCallback unless tail?.apply
                console.log "emitting provider: #{provider}"
                @socket.emit provider, archarguments...

    # A hook that will be called prior to registering the service
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    register: (kernel, router, next) ->
        assert kernel?.secureSocket, "no HTTPS Socket.IO"
        context = kernel.secureSocket.of @location()
        pure = /[a-zA-Z0-9/-_]+/.test @location()
        assert pure, "location is not pure enough"
        _.forIn this, (value, name, service) =>
            internal = "the #{value} is not function"
            providing = value?.providing or null
            return unless _.isFunction providing
            assert _.isFunction(value), internal
            binder = (s) => s.on name, providing(s)
            context.on "connection", binder
        return next()

    # A hook that will be called prior to unregistering the service
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    unregister: (kernel, router, next) ->
        assert kernel?.secureSocket, "no HTTPS Socket.IO"
        context = kernel.secureSocket.of @location()
        pure = /[a-zA-Z0-9/-_]+/.test @location()
        assert pure, "location is not pure enough"
        _.forIn this, (value, name, service) =>
            internal = "the #{value} is not function"
            providing = value?.providing or null
            return unless _.isFunction providing
            assert _.isFunction(value), internal
            context.removeAllListeners "connection"
        return next()
        util.inspect next
