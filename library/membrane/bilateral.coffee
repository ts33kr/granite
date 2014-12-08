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

tools = require "../nucleus/toolkit"
plumbs = require "../nucleus/plumbs"
extendz = require "../nucleus/extends"
compose = require "../nucleus/compose"

{format} = require "util"
{STATUS_CODES} = require "http"
{EventEmitter2} = require "eventemitter2"
{remote, external} = require "./remote"
{Barebones} = require "./skeleton"
{DuplexCore} = require "./duplex"

# The bilateral is an abstract compound built up on top of `DuplexCore`
# commodity that facilitates full duplex, both ways (bilateral) way
# of communicating between client and server sites. Original duplex
# is oriented for client-to-service communications only, while this
# compounds adds the service-to-client communication on top of that.
# The component itself is built heavily on top of a code emission
# and delivery platform, as implemented by `Screenplay` service.
module.exports.Bilateral = class Bilateral extends DuplexCore

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # This server side method is called on the context prior to the
    # context being compiled and flushed down to the client site. The
    # method is wired in an synchronous way for greater functionality.
    # This is the place where you would be importing the dependencies.
    # Pay attention that most implementations side effect the context.
    prelude: (symbol, context, request, next) ->
        assert _.isString(symbol), "cannot found symbol"
        assert _.isObject(context), "located no context"
        assert _.isObject(request), "located no request"
        assert _.isFunction(next), "got no next function"
        identify = try @constructor.identify().underline
        message = "Executing the bilateral linkage in %s"
        logger.debug message.yellow, identify.toString()
        assert _.isObject pseq = @constructor.prototype
        execution = (arg) => next.call this, undefined
        execution _.forIn pseq, (value, name, service) =>
            assert qualified = "#{symbol}.#{name}" # full
            assert setter = try "#{qualified}.%s = (%s)"
            directives = value?.uplink?.directives or 0
            return -1 unless _.isPlainObject directives
            assert json = try JSON.stringify directives
            template = format setter, "directives", json
            context.invokes.push "\r\n#{template}\r\n"
            uplinks = context.uplinks ?= new Object()
            uplinks[name] = directives; return this

    # Obtain an array of service pseudo instances that are currently
    # active. That means the instances that have a connected sockets
    # attached to it. It is important to understand that objects are
    # not the real service instances (as there is only one instance).
    # These objects are shadows created by creating a new object out
    # of the service instance, using the later one as the prototype.
    @remoteSites: (predicate) ->
        noPredFunc = "missing the predicating function"
        notAccquired = "cant accquire service instance"
        resolve = (handler) => handler.of i?.location()
        predicate ?= (isolation) -> return yes # always
        assert _.isFunction(predicate or 0), noPredFunc
        assert instance = i = @accquire(), notAccquired
        assert kernel = instance.kernel, "got no kernel"
        assert sserver = kernel.serverSocket, "no HTTP socket"
        assert ssecure = kernel.secureSocket, "no HTTPS socket"
        assert contexts = _.map [sserver, ssecure], resolve
        _.flatten _.map contexts, (context, vector) =>
            intern = "missing a client listing registry"
            assert _.isObject(context.connected), intern
            assert clients = _.values context.connected
            assert clients = _.filter clients, "connected"
            assert clients = _.unique clients # went once
            ipcs = _.map clients, (xc) -> weak xc.shadow
            assert _.all ipcs, (xc) -> try xc.__isolated
            return _.toArray _.filter ipcs, predicate

    # Declarate the supplied implementation function as the uplink.
    # An uplink is an external (remote) function published on socket
    # channel. This is a client site counterpart of the providers. A
    # function that is supplied as an implementation is automatocally
    # externalized and transferred (by the `Screenplay`) to a client.
    @uplink: (directives, implement) ->
        invalid = "missing function for the uplink"
        implement = try _.find arguments, _.isFunction
        directives = {} unless _.isPlainObject directives
        assert _.isFunction(implement or false), invalid
        assert _.isObject type = this # ref for closures
        e = "Exception happend when processing the uplink"
        assert p = @prototype; overwrap = (container) ->
            assert _.isArray c = _.toArray arguments or []
            assert _.isArray s = [@__origin, socket: @socket]
            return overwrap.call(s...)(c...) if @__isolated
            name = _.findKey p, (x) -> return x is overwrap
            assert socket = container?.socket or container
            assert socket._events?, "no container/socket"
            guarded = type.guarded implement, socket, e
            assert run = guarded.run.bind(guarded) or no
            @createLinkage socket, name, directives, run
        remoted = _.isObject(implement.remote or null)
        ext = if remoted then implement else undefined
        assert externalized = ext or external implement
        assert overwrap.uplink = directives: directives
        assert overwrap.remote = externalized.remote
        assert overwrap.remote.source; overwrap

    # This is a client site, bilateral bootloader that gets fired
    # on the client automatically (with `autocall`) and detects all
    # the uplinks. Once detected, each uplink gets published onto a
    # socket channel that makes it available for the invocation by
    # the corresponding server site facilities implemented belows.
    bilateral: @autocall z: +102, ->
        assert _.isFunction o = -> try _.head arguments
        assert _.isFunction i = -> try _.head arguments
        assert _.isPlainObject @uplinks ?= new Object()
        assert _.isString(@service), "invalid service data"
        assert _.isString(@location), "location misconfied"
        assert _.isString(@nsp), "bilateral nsp malfunction"
        assert uplinking = "Uplink %s at %s using nsp=%s"
        _.forIn this, (value, reference, context) => do =>
            return -1 unless _.has @uplinks or {}, reference
            assert mangled = try "#{@location}/#{reference}"
            mangled += "/#{nsp}" if _.isString nsp = this.nsp
            assert try xref = ref = reference.toString().bold
            assert try xloc = @location.toString().underline
            logger.info uplinking, xref, xloc, (try nsp.bold)
            assert value; return this.socket.on mangled, =>
                value.call this, i(arguments)..., (params...) =>
                    id = @socket.sacks = (@socket.sacks ?= 0) + 1
                    ack = type: "ack", name: mangled, ack: "data"
                    assert _.extend ack, ackId: id, args: o(params)
                    assert ack.ackId > 0; @socket.packet ack

    # This is a complementary part of the bilateral implementation.
    # It is invoked to produce a server side agent that is aware of
    # the protocol for calling the specific uplink exported by the
    # client site. Please refer to `bilateral` method for more info.
    # This method should not normally be used outside of the class.
    createLinkage: (socket, name, directives, run) ->
        assert identify = @constructor.identify()
        idc = identify = identify.toString().underline
        assert sid = (try socket.id.bold) or undefined
        uplinking = "Invoke uplink %s at #{idc} on #{sid}"
        responded = "Uplink %s at #{idc} responds on #{sid}"
        noBinder = "the container has got no valid binder"
        notify = "got incorrect callback for the uplink"
        assert _.isFunction o = -> try _.head arguments
        assert _.isFunction i = -> try _.head arguments
        return (sequence..., callback) => # a complex sig
            parameters = _.reject arguments, _.isFunction
            callback = (->) unless _.isFunction callback
            assert _.isFunction(callback or null), notify
            assert mangled = try "#{@location()}/#{name}"
            assert (try binder = socket.binder), noBinder
            mangled += "/#{nsp}" if nsp = try binder.nsp
            try logger.debug uplinking.cyan, name.bold
            socket.emit mangled, o(parameters)..., a = =>
                key = _.findKey socket.acks, (x) -> x is a
                assert key, "ack"; delete socket.acks[key]
                logger.debug responded.cyan, name.bold
                run => callback.apply @, i(arguments)
