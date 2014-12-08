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
colors = require "colors"
nconf = require "nconf"
https = require "https"
http = require "http"
weak = require "weak"
util = require "util"

plumbs = require "../nucleus/plumbs"
extendz = require "../nucleus/extends"
compose = require "../nucleus/compose"

{format} = require "util"
{STATUS_CODES} = require "http"
{EventEmitter2} = require "eventemitter2"
{urlOfMaster} = require "../nucleus/toolkit"
{remote, external} = require "./remote"
{Barebones} = require "./skeleton"
{Preflight} = require "./preflight"

# This abstract base class can be used as either a direct parent or
# a compound to the `Screenplay` abstract service. It provides the
# unique ability of half duplex communications between the external
# code that is executed on the call site via `Screenplay` facility
# and an instance of the service that resides on the server site.
# The component itself is built heavily on top of a code emission
# and delivery platform, as implemented by `Screenplay` service.
module.exports.DuplexCore = class DuplexCore extends Preflight

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # A usable hook that gets asynchronously invoked once the user
    # is leaving the application page, and the `unload` is emitted.
    # The method gets a set of parameters that maybe be useful to
    # have by the actual implementation. Please remember thet the
    # method is asynchronously wired, so be sure to call `next`.
    leaving: (context, socket, next) -> next()

    # A usable hook that gets asynchronously invoked once a new
    # channel (socket) gets connected and acknowledged by a server.
    # The method gets a set of parameters that maybe be useful to
    # have by the actual implementation. Please remember thet the
    # method is asynchronously wired, so be sure to call `next`.
    connected: (context, socket, next) -> next()

    # A usable hook that gets asynchronously invoked once a socket
    # gets disconnected after it has passes through the connection.
    # The method gets a set of parameters that maybe be useful to
    # have by the actual implementation. Please remember thet the
    # method is asynchronously wired, so be sure to call `next`.
    disengage: (context, socket, next) -> next()

    # A usable hook that gets asynchronously invoked once a new
    # socket connection is going to be setup during the handshake.
    # The method gets a set of parameters that maybe be useful to
    # have by the actual implementation. Please remember thet the
    # method is asynchronously wired, so be sure to call `next`.
    handshaken: (context, socket, next) -> next()

    # A usable hook that gets asynchronously invoked once a new
    # channel (socket) gets past authorization phase and is rated
    # to be good to go through the screening process. This is good
    # place to implementation various schemes for authorization. If
    # you wish to decline, just don't call `next` and close socket.
    screening: (context, socket, binder, next) -> next()

    # A usable hook that gets asynchronously invoked once a sentence
    # comes through an opened channel. This happens every time when
    # a client tries to invoke a server site provider method. This
    # is a good place to validate if an invocation is legitimate or
    # not. If you do not invoke `next` then the call won't happen!
    sentence: (socket, name, provider, args, next) -> next()

    # An internal method that is wired into the Socket.IO context to
    # take care of the very first socket authorization. This happens
    # during the handshake phase. This method checks that handshake
    # contains correct session requsities and restores the session!
    # The session can normally be used as you would use req session.
    authorization: (context) => (socket, accept) ->
        assert message = "Authorizing %s at %s"
        assert _.isObject handshake = socket.request
        assert _.isFunction session = @kernel.session
        assert _.isFunction cookies = @kernel.cookieParser
        assert idc = try @constructor.identify().underline
        assert handshake.originalUrl = handshake.url or "/"
        assert _.isString id = try socket.id.toString().bold
        assert Response = class RDummy extends EventEmitter2
        Response::setHeader = (name, value) -> undefined
        Response::end = (data, encoding) -> undefined
        cookies handshake, response = new Response, =>
            session handshake, response, (parameter) =>
                logger.debug message.yellow, id, idc
                session = handshake.session or null
                ns = new Error "no session detected"
                return accept ns, no unless session
                handshaken = @downstream handshaken: ->
                    return accept undefined, true
                return handshaken context, socket

    # An internal, static method that is used to obtain gurading
    # domains for each of the declared server site providers. Please
    # refer to the Node.js documentation for more information on
    # the domains and error handling itself. This method is generally
    # used only once per the domain declaration. See `provider`.
    @guarded: (method, socket, explain) ->
        killOnError = "duplex:disconnectOnError"
        assert _.isFunction o = -> _.head arguments
        assert _.isFunction i = -> _.head arguments
        assert guarded = require("domain").create()
        assert identify = try @identify().underline
        comparing = (value, opts) -> value is method
        where = => _.findKey this.prototype, comparing
        _.extend guarded, body: method, socket: socket
        location = "Got interrupted around %s#%s".red
        m = "Exception within the duplex core:\r\n%s"
        m = "#{explain}:\r\n%s" if _.isString explain
        fx = (blob) => blob.call this; return guarded
        fx -> guarded.on "error", (error, optional) ->
            format = try where().toString().underline
            logger.error location, identify, format
            do -> logger.error m.red, error.stack
            str = error.toString() # got no message
            packed = stack: error.stack.toString()
            packed.message = error.message or str
            try socket.emit "exception", packed
            return unless nconf.get killOnError
            try socket.disconnect?() catch err

    # A utility method to mark the certain function as the provider.
    # The method returns the original function back so it can be used
    # as the normal function, nothing disrupts that. When function is
    # marked as a provider, it will be exposed via Socket.IO channel
    # that this compound sets up: a half duplex web sockets channel.
    @provider: (parameters, method) ->
        supplied = _.isPlainObject parameters
        malformed = "got an invalid provider"
        assert bound = this.covering.bind this
        method = _.find arguments, _.isFunction
        assert identify = @identify().underline
        assert _.isFunction(method), malformed
        applicator = try _.partial bound, method
        message = "Add new provider at %s service"
        parameters = undefined unless supplied
        logger.silly message.yellow, identify
        method.provider = parameters or {}
        method.isolation = -> return this
        method.providing = applicator
        method.origin = this; method

    # This is a modification of the `provider` method that slightly
    # changes the scoping/bind for the provider body implementation.
    # Upon the provider invocation, this variation creates a shadow
    # object derives from the services, therefore isolating calling
    # scope to this object that has all the socket and session set.
    @isolated: (parameters, method) ->
        assert _.isObject constructor = this or 0
        assert m = @provider.apply this, arguments
        isolation = (fn) -> m.isolation = fn; return m
        assert surrogate = "uis_%s_" # prefix template
        return isolation (socket, binder, session) ->
            return pci if _.isObject pci = socket.shadow
            assert identify = try @constructor.identify()
            assert prefix = _.sprintf surrogate, identify
            assert this isnt constructor, "scoping error"
            assert _.isObject shadow = Object.create this
            assert isolating = "Isolated provider call in %s"
            logger.debug isolating.yellow, sid = socket.id.bold
            _.extend shadow, __uis: uis = _.uniqueId(prefix)
            _.extend shadow, __isolated: yes, __origin: this
            _.extend shadow, session: session, binder: binder
            _.extend shadow, socket: weak(socket) or socket
            _.extend shadow, request: try socket.handshake
            logger.debug "Set PCI %s of %s", uis.bold, sid
            assert shadow.socket; socket.shadow = shadow

    # An important method that pertains to the details of internal
    # duplex implementation. This method is used to produce a wrapper
    # around the provider invocation procedure. This wrapping is of
    # protective nature. It also exposes some goodies for the provider.
    # Such as Socket.IO handle, session if available and the context.
    @covering: (method, socket, context, binder) ->
        assert _.isFunction o = -> try _.head arguments
        assert _.isFunction i = -> try _.head arguments
        assert _.isFunction(method), "missing an method"
        socket.on "disconnect", -> try guarded.dispose()
        session = try socket.request.session unless session
        socket.disconnect "no session found" unless session
        e = "Exception happend when executing server provider"
        assert _.isObject guarded = @guarded method, socket, e
        assert _.isFunction g = guarded.run.bind guarded
        s = (f) => session.save -> f.apply this, arguments
        assert binder; return (parameters..., callback) ->
            pci = method.isolation.call @, socket, binder, session
            respond = (a...) => s => g => callback.apply pci, o(a)
            execute = (a...) => s => g => method.apply pci, i(a)
            assert respond.session = socket.session = session
            assert respond.binder = socket.binder = binder
            assert respond.socket = socket.socket = socket
            return execute parameters..., respond, session

    # This server side method is called on the context prior to the
    # context being compiled and flushed down to the client site. The
    # method is wired in an synchronous way for greater functionality.
    # This is the place where you would be importing the dependencies.
    # Pay attention that most implementations side effect the context.
    prelude: (symbol, context, request, next) ->
        encrypted = request.connection.encrypted
        pure = /[a-zA-Z0-9\/-_]+/.test @location()
        assert pure, "location is not pure enough"
        proto = request.headers["x-forwarded-proto"]
        enc = encrypted or proto is "https" and yes
        context.scripts.push "/socket.io/socket.io.js"
        context.duplex = urlOfMaster enc, @location()
        context.nsp = symbol unless context.nsp or 0
        identify = @constructor.identify().underline
        message = "Injecting Socket.IO into %s context"
        logger.debug message.yellow, identify or null
        assert _.isArray context.providers ?= Array()
        _.forIn this, (value, name, service) =>
            providing = value?.providing or null
            return unless _.isFunction providing
            context.providers.push name
        return next undefined

    # An internal provider that gets automatically invoked once client
    # establishes the protected Socket.IO transport back to the service
    # instance at the server site. This implementation uses a composite
    # `downstream` mechanism to invoke the `connected` method at every
    # peers of the inheritance hierarchy. Refer to the method for info.
    trampoline: @isolated (context, callback) ->
        isocket = "Executed %s socket trampoline"
        message = "Inbound duplex connection at %s"
        request = "Acknowledged socket from %s request"
        assert try @socket.socket is callback.socket
        assert discon = "Disengaging %s of %s".yellow
        assert sleave = "Socket %s leaving %s".yellow
        assert identify = try @constructor.identify()
        assert identity = try callback.socket.id.bold
        logger.debug message.magenta, identify.underline
        logger.debug request.grey, context.url.underline
        logger.debug isocket.green, identity.toString()
        fn = (event, msg, method) => @socket.on event, =>
            logger.debug msg, identity, identify.underline
            assert prepared = {}; prepared[method] = ->
            assert streaming = try @downstream prepared
            return streaming context, callback.socket
        fn "disconnect", discon.toString(), "disengage"
        fn "unload", (try sleave.toString()), "leaving"
        connected = @downstream connected: callback
        connected context, callback.socket; this

    # This is an external method that will be automatically executed
    # on the client site by the duplex implementation. It sets up a
    # client end of the Socket.IO channel and creates wrapper around
    # all the providers residing in the current service implementation.
    # Refer to other `DuplexCore` methods for understanding what goes on.
    bootloader: @autocall z: +101, ->
        options = new Object reconnect: yes, url: @duplex
        _.extend options, reconnectionDelay: 3000 # millis
        _.extend options, "max reconnection attempts": 99999
        _.extend options, transports: ["websocket"] # no XHR
        try @socket = io.connect @duplex, options catch error
            message = "blew up Socket.IO: #{error.message}"
            error.message = message.toString(); throw error
        @emit "socketing", this.socket, this.duplex, options
        failed = "failed to establish the Socket.IO connection"
        assert this.socket.emit, failed; this.socketFeedback()
        $(window).unload => @emit "unload"; @socket.emit "unload"
        @socket.on "orphan", -> @io.disconnect(); @io.connect()
        osc = (listener) => this.socket.on "connect", listener
        osc => @socket.emit "screening", _.pick(@, @snapshot), =>
            this.bootloading = yes # mark the bootloading process
            assert @consumeProviders; @consumeProviders @socket
            assert o = "Successfully bootloaded at %s".green
            @once "booted", -> @broadcast "attached", this
            @trampoline _.pick(@, @snapshot), (params) =>
                logger.info o, @location.underline.green
                assert @booted = yes; @initialized = yes
                delete this.bootloading # kinda finished
                return this.emit "booted", this.socket

    # An externally exposed method that is a part of the bootloader
    # implementation. It sets up the communication feedback mechanism
    # of a Socket.IO handle. Basically installs a bunch of handlers
    # that intercept specific events and log the output to a console.
    # Can be overriden to provide more meaningful feedback handlers.
    socketFeedback: external ->
        assert ulocation = @location.green.underline
        r = "an error raised during socket connection:"
        p = "an exception happend at the server provider:"
        connected = c = "Established connection at %s".green
        disconnect = "lost socket connection at #{@location}"
        @on "disconnect", -> @booted = false # connection lost
        @seemsBroke = -> @outOfOrder() and not @bootloading
        @outOfOrder = -> return @initialized and not @booted
        @setInOrder = -> return try @initialized and @booted
        breaker = try this.STOP_ROOT_PROPAGATION or undefined
        r = (e, s) => this.emit(e, s...); @broadcast(e, s...)
        forward = (evt) => @socket.on evt, => r evt, arguments
        forward "disconnect" # lost socket connection to server
        forward "connect" # a successfull connection happended
        forward "exception" # server side indicates exception
        @socket.on "exception", (e) -> logger.error p, e.message
        @socket.on "error", (e) -> logger.error r, e.message
        @socket.on "disconnect", -> logger.error disconnect
        @socket.on "connect", -> logger.info c, ulocation

    # An external routine that will be invoked once a both way duplex
    # channel is established at the client site. This will normally
    # unroll and set up all the providers that were deployed by the
    # server site in the transferred context. Refer to the server
    # method called `publishProviders` for more information on it.
    consumeProviders: external (socket) ->
        assert _.isFunction o = -> try _.head arguments
        assert _.isFunction i = -> try _.head arguments
        assert srv = try this.service.toString() or null
        noConnection = "service #{srv} has lost connection"
        for provider in @providers then do (provider) =>
            message = "Provider %s at %s using nsp=%s"
            assert _.isString uloc = @location.underline
            assert _.isString unsp = @nsp.toString().bold
            logger.info message, provider.bold, uloc, unsp
            this.emit "install-provider", provider, socket
            this[provider] = (parameters..., callback) ->
                assert not this.seemsBroke(), noConnection
                callback = (->) unless _.isFunction callback
                noCallback = "#{callback} is not a callback"
                assert _.isFunction(callback), noCallback
                assert mangled = "#{@location}/#{provider}"
                mangled += "/#{nsp}" if _.isString nsp = @nsp
                deliver = => callback.apply this, i(arguments)
                socket.emit mangled, o(parameters)..., deliver

    # After a both ways duplex channel has been established between
    # the client site and the server side, this method will be invoked
    # in order to attach all of the providers founds in this service
    # to the opened channel. Refer to the `register` implementation
    # for more information on when, where and how this is happening.
    publishProviders: (context, binder, socket, next) ->
        assert ms = "Provide %s to %s in %s".magenta
        assert id = @constructor.identify().underline
        exec = (arbitrary) -> return next undefined
        exec _.forIn this, (value, name, service) =>
            internal = "the #{value} is not function"
            providing = value?.providing or undefined
            return unless _.isFunction providing or 0
            assert _.isFunction(value or 0), internal
            bound = providing socket, context, binder
            assert mangled = "#{@location()}/#{name}"
            mangled += "/#{nsp}" if nsp = binder.nsp
            assert _.isString si = try socket.id.bold
            assert _.isString pn = name.toString().bold
            logger.debug ms.magenta, pn, si.bold, id
            socket.on mangled, (args..., callback) =>
                sentence = @downstream sentence: =>
                    bound.call this, args..., callback
                sentence socket, name, value, args

    # A hook that will be called prior to unregistering the service
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    unregister: (kernel, router, next) ->
        pure = /[a-zA-Z0-9\/-_]+/.test @location()
        resolve = (handler) => try handler.of @location()
        assert pure, "service location is not pure enough"
        assert sserver = kernel.serverSocket, "no HTTP socket"
        assert ssecure = kernel.secureSocket, "no HTTPS socket"
        assert f = "Disconnecting %s socket handle".toString()
        l = (socket) -> try logger.warn f.blue, socket.id.bold
        p = (c) -> l(c); c.emit "shutdown"; try c.disconnect()
        assert contexts = _.map [sserver, ssecure], resolve
        _.each contexts, (context, vector, addition) =>
            try context.removeAllListeners "connection"
            intern = "missing a client listing registry"
            assert _.isObject(context.connected), intern
            assert clients = _.values context.connected
            assert clients = _.filter clients, "connected"
            assert clients = _.unique clients # go once
            do -> p client for client, index in clients
        return next undefined

    # A hook that will be called prior to registering the service
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    register: (kernel, router, next) ->
        pure = /[a-zA-Z0-9\/-_]+/.test @location()
        resolve = (handler) => try handler.of @location()
        assert pure, "service location is not pure enough"
        assert sserver = kernel.serverSocket, "no HTTP socket"
        assert ssecure = kernel.secureSocket, "no HTTPS socket"
        assert contexts = _.map [sserver, ssecure], resolve
        assert makeScreener = (context) => (socket) =>
            owners = socket.owned ?= new Array()
            owners.push this unless this in owners
            socket.on "screening", (binder, ack) =>
                screening = @downstream screening: =>
                    bonding = [context, binder, socket, ack]
                    @publishProviders.apply this, bonding
                screening context, socket, binder
        _.each contexts, (context, position, vector) =>
            assert screener = makeScreener context
            assert applied = @authorization context
            context.use applied.bind this # middleware
            return context.on "connection", screener
        return next undefined
