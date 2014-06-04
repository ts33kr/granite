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
async = require "async"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"

{Archetype} = require "../nucleus/archetype"
{Barebones} = require "../membrane/skeleton"

# An abstract base compound that provides an extensive functionality
# and solution for authenticating entities against requests and some
# other processing entities that are tight into a session, such as
# the duplex providers, etc. Please refer to the implementation for
# more information on the capabilities and options of this compound.
module.exports.AccessGate = class AccessGate extends Barebones

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # This definition specifies the symbol (key) that will be used
    # for persisting the authenticated entity into the containers.
    # It also will be used to retrieve the authenticated entity off
    # the container. Definition may (and should) be overriden by
    # the implementing services, in case if rename is necessary.
    @ACCESS_ENTITY_SYMBOL = "account"

    # Symbol declaration table, that states what keys, if those are
    # vectors (arrays) should be exported and then merged with their
    # counterparts in the destination, once the composition process
    # takes place. See the `Archetype::composition` hook definition
    # for more information. Keys are names, values can be anything.
    @COMPOSITION_EXPORTS = resurrections: 1, hibernations: 1

    # Add the supplied implementation function to the internal stack
    # of functions that will be invoked every time the access system
    # is resurrecting the entity out of the session. These functions
    # will be called asynchronously, with an ability to abruptly end
    # the execution. Please consult with the `async` package and the
    # source code of this method for more details on the mechanics.
    @resurrection: (xoptions, ximplement) ->
        noOptions = "the options must be an object"
        noImplement = "must have implementation body"
        noSignature = "function has invalid signature"
        message = "Install session resurrector in %s"
        assert identify = this.identify().underline
        implement = _.find arguments, _.isFunction
        options = _.find arguments, _.isPlainObject
        assert previous = @resurrections or Array()
        return previous unless arguments.length > 0
        assert _.isObject(options or {}), noOptions
        assert _.isFunction(implement), noImplement
        assert (implement.length) > 1, noSignature
        logger.debug message.yellow, identify.bold
        fn = (arbitraryVector) -> return implement
        return fn @resurrections = previous.concat
            implement: implement or _.noop
            options: options or Object()

    # Add the supplied implementation function to the internal stack
    # of functions that will be invoked every time the access system
    # is hibernating the entity inside the session. These functions
    # will be called asynchronously, with an ability to abruptly end
    # the execution. Please consult with the `async` package and the
    # source code of this method for more details on the mechanics.
    @hibernation: (xoptions, ximplement) ->
        noOptions = "the options must be an object"
        noImplement = "must have implementation body"
        noSignature = "function has invalid signature"
        message = "Install session hibernator in %s"
        assert identify = this.identify().underline
        implement = _.find arguments, _.isFunction
        options = _.find arguments, _.isPlainObject
        assert previous = @hibernations or Array()
        return previous unless arguments.length > 0
        assert _.isObject(options or {}), noOptions
        assert _.isFunction(implement), noImplement
        assert (implement.length) > 1, noSignature
        logger.debug message.yellow, identify.bold
        fn = (arbitraryVector) -> return implement
        return fn @hibernations = previous.concat
            implement: implement or _.noop
            options: options or Object()

    # Dereference the potentially existent entity from the session
    # into the supplied container, where the session is residing. It
    # basically retrieves the hibernated entity, resurrects it and
    # defined the appropriate getter property on supplied container.
    # If the entity or session does not exist, nothing gets defined.
    # Please refer to source code, as it contains important details.
    dereference: (container, callback) ->
        {series, apply} = async or require "async"
        assert key = @constructor.ACCESS_ENTITY_SYMBOL
        assert sid = "x-authenticate-entity" # external
        isVanillaSession = _.isObject container.cookie
        container = session: container if isVanillaSession
        return callback() unless session = container.session
        return callback() unless content = session[sid]
        delete container[key] if _.has container, key
        surrogate = _.unique @constructor.resurrection()
        functions = (o.implement.bind @ for o in surrogate)
        boxd = (obj) -> (apply fn, obj for fn in functions)
        fasn = (o, c) -> series boxd(o), (e, r) -> c(e, o)
        @resurrectEntity ?= (c, fn) -> fasn _.clone(c), fn
        @resurrectEntity content, (error, entity) =>
            format = (m) -> "resurrection error: #{m}"
            masked = format error.message if error
            return callback Error masked if error
            s = enumerable: no, configurable: yes
            p = enumerable: yes, configurable: yes
            p.get = s.get = -> entity or undefined
            Object.defineProperty container, key, p
            Object.defineProperty session, key, p
            @emit "resurrect", container, entity
            assert container[key]?; callback()

    # Authenticate supplied entity as the authorized entity against
    # the session found in the specified session container. Session
    # container could be either a request or duplex socket or other
    # member that has the session storage installed under `session`.
    # The method also saves the session once it has authenticated.
    # Please refer to source code, as it contains important details.
    authenticate: (container, entity, rme, callback) ->
        {series, apply} = async or require "async"
        noSave = "the session has not save function"
        noSession = "container has no session object"
        message = "Persisted %s entity against session"
        isVanillaSession = _.isObject container.cookie
        container = session: container if isVanillaSession
        assert symbol = @constructor.ACCESS_ENTITY_SYMBOL
        assert session = container?.session, noSession
        assert _.isObject(entity), "malformed entity"
        surrogate = _.unique @constructor.hibernation()
        functions = (o.implement.bind @ for o in surrogate)
        boxd = (obj) -> (apply fn, obj for fn in functions)
        fasn = (o, c) -> series boxd(o), (e, r) -> c(e, o)
        @hibernateEntity ?= (c, fn) -> fasn _.clone(c), fn
        @hibernateEntity entity, (error, content) =>
            return callback error, undefined if error
            assert not _.isEmpty(content), "no content"
            session["x-authenticate-entity"] = content
            assert _.isFunction(session.save), noSave
            session.cookie.maxAge = 2628000000 if rme
            session.random = _.random 0, 1, yes # force
            try logger.debug message.yellow, symbol.bold
            session.touch() # mark the session changed
            session.save => @dereference container, =>
                @emit "hibernate", container, entity
                return callback undefined, content

    # A hook that will be called prior to firing up the processing
    # of the service. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    # This implementation is a gateway into the access control sys.
    ignition: (request, response, next) ->
        assert _.isString id = @constructor.identify()
        assert symbol = @constructor.ACCESS_ENTITY_SYMBOL
        format = (ms) -> "ingition access error: #{ms}"
        atm = "Attempting ignition dereferencing at %s"
        success = "Got valid ignition entity at #{id}"
        set = "Set %s to be access entity reference"
        logger.debug atm, try id.toString().underline
        this.dereference request, (error, supply) =>
            @emit "access-entity-ignition", arguments...
            s = succeeded = _.isObject request[symbol]
            logger.debug success.yellow if succeeded
            logger.debug set.yellow, symbol.bold if s
            return next undefined if _.isEmpty error
            assert message = error.message or error
            logger.error format(message).red
            return next.call this, error

    # A usable hook that gets asynchronously invoked once a new
    # socket connection is going to be setup during the handshake.
    # The method gets a set of parameters that maybe be useful to
    # have by the actual implementation. Please remember thet the
    # method is asynchronously wired, so be sure to call `next`.
    # This implementation is a gateway into the access control sys.
    handshaken: (context, socket, next) ->
        assert handshake = try socket.request or null
        assert _.isString id = @constructor.identify()
        assert symbol = @constructor.ACCESS_ENTITY_SYMBOL
        format = (ms) -> "handshake access error: #{ms}"
        atm = "Attempting handshake dereferencing at %s"
        success = "Got valid handshake entity at #{id}"
        set = "Set %s to be access entity reference"
        logger.debug atm, try id.toString().underline
        this.dereference handshake, (error, supply) =>
            @emit "access-entity-handshake", arguments...
            s = succeeded = _.isObject handshake[symbol]
            logger.debug success.yellow if succeeded
            logger.debug set.yellow, symbol.bold if s
            return next undefined if _.isEmpty error
            assert message = error.message or error
            logger.error format(message).red
            return next.call this, error
