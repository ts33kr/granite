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
domain = require "domain"
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
{Preflight} = require "./preflight"
{Marshal} = require "./marshal"

# This abstract base class can be used as either a direct parent or
# a compount to the `Screenplay` abstract service. It provides the
# unique ability of half duplex data exchange between the external
# code that is executed on the call site via `Screenplay` facility
# and an instance of the service that resides on the server site.
module.exports.Duplex = class Duplex extends Preflight

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    @abstract yes

    # A usable hook that gets asynchronously invoked once a new
    # channel (socket) gets connected and acknowledges by the server.
    # The method gets a set of parameters that maybe be useful to
    # have by the actual implementation. Please remember thet the
    # method is asynchronously wired, so be sure to call `next`.
    connected: (context, socket, next) -> next()

    # A usable hook that gets asynchronously invoked once a new
    # channel (socket) gets connected to the Socket.IO hub in the
    # context of the current service. The channel will be considered
    # established only when prescreen calls the next procedure. If
    # you wish to decline, just don't call `next` and close socket.
    prescreen: (context, socket, next) -> next()

    # An internal, static method that is used to obtain gurading
    # domains for each of the declared server site providers. Please
    # refer to the Node.js documentation for more information on
    # the domains and error handling itself. This method is generally
    # used only once per the domain declaration. See `provider`.
    @guarded: (method, socket) ->
        guarded = domain.create()
        identify = @identify().underline
        assert _.isFunction o = Marshal.serialize
        assert _.isFunction i = Marshal.deserialize
        location = "Breakpoint at @#{method}#%s"
        message = "Error running provider:\r\n%s"
        guarded.on "error", (error) ->
            logger.error location.red, identify
            logger.error message.red, error.stack
            socket.emit "exception", o([error])...
            try socket.disconnect?()
        return guarded

    # A utility method to mark the certain function as the provider.
    # The method returns the original function back so it can be used
    # as the normal function, nothing disrupts that. When function is
    # marked as a provider, it will be exposed via Socket.IO channel
    # that this compound sets up: a half duplex web sockets channel.
    @provider: (method) ->
        noMethod = "a #{method} is not a function"
        invalidArgs = "has to have at least 1 parameter"
        assert _.isFunction(method), noMethod
        assert method.length >= 1, invalidArgs
        assert _.isFunction o = Marshal.serialize
        assert _.isFunction i = Marshal.deserialize
        method.provider = Object.create {}
        method.providing = (socket) -> (args..., callback) ->
            guarded = @constructor.guarded? method, socket
            assert _.isFunction g = guarded.run.bind guarded
            execute = (a...) => g => method.apply this, i(a)
            respond = (a...) => g => callback.apply this, o(a)
            respond.socket = socket; execute args..., respond
        method.origin = this; return method

    # This server side method is called on the context prior to the
    # context being compiled and flushed down to the client site. The
    # method is wired in an synchronous way for greater functionality.
    # This is the place where you would be importing the dependencies.
    prelude: (context, request, next) ->
        pure = /[a-zA-Z0-9/-_]+/.test @location()
        assert pure, "location is not pure enough"
        context.scripts.push "/socket.io/socket.io.js"
        context.duplex = tools.urlWithHost yes, @location()
        context.providers = new Array
        _.forIn this, (value, name, service) =>
            providing = value?.providing or null
            return unless _.isFunction providing
            context.providers.push name
        return next()

    # An internal provider that gets automatically invoked once client
    # establishes a protected Socket.IO channel back to the service
    # instance at the server site. This implementation that uses the
    # `upstreamAsync` mechanism to invoke the `connected` method at all
    # peers of the inheritance hierarchy. Refer to the method for info.
    channelOpened: @provider (context, callback) ->
        identify = @constructor.identify?()
        isocket = "Notified from socket %s"
        message = "Inbound duplex connection at %s"
        request = "Acknowledged from request at %s"
        logger.debug message.magenta, identify.underline
        logger.debug request.magenta, context.url.underline
        logger.debug isocket.magenta, callback.socket.id
        connected = @upstreamAsync "connected", callback
        connected context, callback.socket; this

    # This is an external method that will be automatically executed
    # on the client site by the duplex implementation. It sets up a
    # client end of the Socket.IO channel and creates wrapper around
    # all the providers residing in the current service implementation.
    # Refer to other `Duplex` methods for understanding what goes on.
    openChannel: @autocall ->
        try @socket = io.connect @duplex catch error
            message = "blew up Socket.IO: #{error.message}"
            error.message = message.toString(); throw error
        failed = "failed to created Socket.IO connection"
        throw new Error failed unless @socket.emit
        p = "an exception happend at the server provider"
        @socket.on "exception", (e) -> console.error p, e
        assert @consumeProviders; @consumeProviders @socket
        open = "notified the service of an opened channel"
        args = [_.omit(this, "socket"), -> console.log open]
        n.apply @, args if _.isFunction n = @channelOpened

    # An external routine that will be invoked once a both way duplex
    # channel is established at the client site. This will normally
    # unroll and set up all the providers that were deployed by the
    # server site in the transferred context. Refer to the server
    # method called `deployProviders` for more information on it.
    consumeProviders: external (socket) ->
        assert _.isFunction o = Marshal.serialize
        assert _.isFunction i = Marshal.deserialize
        for provider in @providers then do (provider) =>
            console.log "register context provider: #{provider}"
            this[provider] = (parameters..., callback) ->
                noCallback = "#{callback} is not a callback"
                assert _.isFunction(callback), noCallback
                deliver = => callback.apply this, i(arguments)
                socket.emit provider, o(parameters)..., deliver

    # After a both ways duplex channel has been established between
    # the client site and the server side, this method will be invoked
    # in order to attach all of the providers founds in this service
    # to the opened channel. Refer to the `register` implementation
    # for more information on when, where and how this is happening.
    publishProviders: (context, socket) ->
        _.forIn this, (value, name, service) =>
            internal = "the #{value} is not function"
            providing = value?.providing or null
            return unless _.isFunction providing
            assert _.isFunction(value), internal
            bound = (s) => providing(socket).bind @
            socket.on name, bound socket

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
        context.on "connection", (socket) =>
            pub = => @publishProviders context, socket
            prescreen = @upstreamAsync "prescreen", pub
            prescreen context, socket
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
        context.removeAllListeners "connection"
        return next()
