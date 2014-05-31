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

    # Dereference the potentially existent entity from the session
    # into the supplied container, where the session is residing. It
    # basically retrieves the hibernated entity, ressurects it and
    # defined the appropriate getter property on supplied container.
    # If the entity or session does not exist, nothing gets defined.
    dereference: (container, callback) ->
        assert key = @constructor.ACCESS_ENTITY_SYMBOL
        assert sid = "x-authenticate-entity" # external
        isVanillaSession = _.isObject container.cookie
        container = session: container if isVanillaSession
        return callback() unless session = container.session
        return callback() unless content = session[sid]
        delete container[key] if _.has container, key
        @ressurectEntity ?= (xc, xn) -> xn null, xc
        @ressurectEntity content, (error, entity) =>
            format = (m) -> "ressurection error: #{m}"
            masked = format error.message if error
            return callback Error masked if error
            s = enumerable: no, configurable: yes
            p = enumerable: yes, configurable: yes
            p.get = s.get = -> entity or undefined
            Object.defineProperty container, key, p
            Object.defineProperty session, key, p
            @emit "ressurect", container, entity
            assert container[key]?; callback()

    # Authenticate supplied entity as the authorized entity against
    # the session found in the specified session container. Session
    # container could be either a request or duplex socket or other
    # member that has the session storage installed under `session`.
    # The method also saves the session once it has authenticated.
    authenticate: (container, entity, rme, callback) ->
        noSave = "the session has not save function"
        noSession = "container has no session object"
        message = "Persisted %s entity against session"
        isVanillaSession = _.isObject container.cookie
        container = session: container if isVanillaSession
        assert symbol = @constructor.ACCESS_ENTITY_SYMBOL
        assert session = container?.session, noSession
        assert _.isObject(entity), "malformed entity"
        @hibernateEntity ?= (xe, xn) -> xn null, xe
        @hibernateEntity entity, (error, content) =>
            return callback error, undefined if error
            assert not _.isEmpty(content), "no content"
            session["x-authenticate-entity"] = content
            assert _.isFunction(session.save), noSave
            session.cookie.maxAge = 2628000000 if rme
            session.random = _.random 0, 1, yes # force
            try logger.debug message.blue, symbol.bold
            session.touch() # mark the session changed
            session.save => @dereference container, =>
                @emit "hibernate", container, entity
                return callback undefined, content

    # A hook that will be called prior to firing up the processing
    # of the service. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    ignition: (request, response, next) ->
        assert _.isString id = @constructor.identify()
        assert symbol = @constructor.ACCESS_ENTITY_SYMBOL
        format = (ms) -> "ingition access error: #{ms}"
        atm = "Attempting ignition dereferencing at %s"
        success = "Got valid ignition entity at #{id}"
        set = "Set %s to be access entity reference"
        logger.debug atm, try id.toString().underline
        try @dereference request, (error, supply) =>
            @emit "access-entity-ignition", arguments...
            s = succeeded = _.isObject request[symbol]
            logger.debug success.green if succeeded
            logger.debug set.green, symbol.bold if s
            return next undefined if _.isEmpty error
            assert message = error.message or error
            logger.error format(message).red
            return next.call this, error

    # A usable hook that gets asynchronously invoked once a new
    # socket connection is going to be setup during the handshake.
    # The method gets a set of parameters that maybe be useful to
    # have by the actual implementation. Please remember thet the
    # method is asynchronously wired, so be sure to call `next`.
    handshaken: (context, handshake, next) ->
        assert _.isString id = @constructor.identify()
        assert symbol = @constructor.ACCESS_ENTITY_SYMBOL
        format = (ms) -> "handshake access error: #{ms}"
        atm = "Attempting handshake dereferencing at %s"
        success = "Got valid handshake entity at #{id}"
        set = "Set %s to be access entity reference"
        logger.debug atm, try id.toString().underline
        try @dereference handshake, (error, supply) =>
            @emit "access-entity-handshake", arguments...
            s = succeeded = _.isObject handshake[symbol]
            logger.debug success.green if succeeded
            logger.debug set.green, symbol.bold if s
            return next undefined if _.isEmpty error
            assert message = error.message or error
            logger.error format(message).red
            return next.call this, error
