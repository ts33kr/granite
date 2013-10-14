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
util = require "util"

tools = require "./../nucleus/tools"
plumbs = require "./../nucleus/plumbs"
extendz = require "./../nucleus/extends"
compose = require "./../nucleus/compose"

{format} = require "util"
{STATUS_CODES} = require "http"
{EventEmitter2} = require "eventemitter2"
{remote, external} = require "./remote"
{Barebones} = require "./skeleton"
{Marshal} = require "./marshal"
{Duplex} = require "./duplex"

# The bilateral is an abstract compound built up on top of `Duplex`
# commodity that facilitates full duplex, both ways (bilateral) way
# of communicating between client and server sites. Original duplex
# is oriented for client-to-service communications only, while this
# compounds adds the service-to-client communication on top of that.
module.exports.Bilateral = class Bilateral extends Duplex

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    @abstract yes

    # This server side method is called on the context prior to the
    # context being compiled and flushed down to the client site. The
    # method is wired in an synchronous way for greater functionality.
    # This is the place where you would be importing the dependencies.
    # Pay attention that most implementations side effect the context.
    prelude: (symbol, context, request, next) ->
        _.forIn this, (value, name, service) =>
            set = "#{symbol}.#{name}.%s = (%s)"
            directives = value?.uplink?.directives
            return unless _.isPlainObject directives
            assert json = JSON.stringify directives
            template = format set, "directives", json
            context.invokes.push "\r\n#{template}\r\n"
            uplinks = context.uplinks ?= new Object
            uplinks[name] = directives; return @
        return next undefined

    # Declarate the supplied implementation function as the uplink.
    # An uplink is an external (remote) function published on socket
    # channel. This is a client site counterpart of the providers. A
    # function that is supplied as an implementation is automatocally
    # externalized and transferred (by the `Screenplay`) to a client.
    @uplink: (directives, implementation) ->
        invalidFunc = "supply a function for the uplink"
        implementation = _.find arguments, _.isFunction
        directives = {} unless _.isPlainObject directives
        assert _.isFunction(implementation), invalidFunc
        p = @prototype; overwrapping = (container) ->
            name = _.findKey p, (x) -> x is overwrapping
            assert socket = container.socket or container
            assert socket._events?, "no container/socket"
            return @createLinkage socket, name, directives
        remoted = _.isObject(implementation.remote or null)
        ext = if remoted then implementation else undefined
        assert externalized = ext or external implementation
        assert overwrapping.uplink = directives: directives
        assert overwrapping.remote = externalized.remote
        assert overwrapping.remote.source; overwrapping

    # This is a client site, bilateral bootloader that gets fired
    # on the client automatically (with `autocall`) and detects all
    # the uplinks. Once detected, each uplink gets published onto a
    # socket channel that makes it available for the invocation by
    # the corresponding server site facilities implemented belows.
    bilateral: @autocall z: +999, ->
        assert _.isFunction o = Marshal.serialize
        assert _.isFunction i = Marshal.deserialize
        uplinking = "Uplink %s at #{@location}, nsp=%s"
        _.forIn this, (value, reference, context) =>
            return unless reference of (@uplinks or {})
            assert mangled = "#{@location}/#{reference}"
            mangled += "/#{nsp}" if _.isString nsp = @nsp
            @socket.on mangled, (args..., callback) =>
                args.push c unless _.isFunction c = callback
                callback = null unless _.isFunction callback
                logger.info uplinking, reference, nsp
                assert args; return value i(args)..., =>
                    return c(o(arguments)...) if c = callback
                    id = @socket.sacks = (@socket.sacks ?= 0) + 1
                    packet = type: "ack", name: mangled, ack: "data"
                    _.extend packet, ackId: id, args: o(arguments)
                    assert packet.ackId; @socket.packet packet

    # This is a complementary part of the bilateral implementation.
    # It is invoked to produce a server side agent that is aware of
    # the protocol for calling the specific uplink exported by the
    # client site. Please refer to `bilateral` method for more info.
    # This method should not normally be used outside of the class.
    createLinkage: (socket, name, directives) ->
        assert identify = @constructor.identify()
        uplinking = "Invoking uplink #{identify}#%s"
        responded = "Uplink #{identify}#%s responded"
        noBinder = "container has got no valid binder"
        notify = "incorrect callback for the uplink"
        assert _.isFunction o = Marshal.serialize
        assert _.isFunction i = Marshal.deserialize
        return (parameters..., callback=(->)) =>
            assert _.isFunction(callback), notify
            assert mangled = "#{@location()}/#{name}"
            assert binder = socket.binder, noBinder
            mangled += "/#{nsp}" if nsp = binder.nsp
            logger.debug uplinking.cyan, name.bold
            socket.emit mangled, o(parameters)..., a = =>
                key = _.findKey socket.acks, (x) -> x is a
                assert key, "ack"; delete socket.acks[key]
                logger.debug responded.cyan, name.bold
                return callback.apply this, i(arguments)
