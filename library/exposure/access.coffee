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
request = require "request"
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
module.exports.Access = class Access extends Barebones

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    @abstract yes

    # A usable hook that gets asynchronously invoked once a new
    # socket connection is going to be setup during the handshake.
    # The method gets a set of parameters that maybe be useful to
    # have by the actual implementation. Please remember thet the
    # method is asynchronously wired, so be sure to call `next`.
    handshake: (context, hso, next) -> @dereference hso, next

    # A hook that will be called prior to firing up the processing
    # of the service. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    ignition: (req, response, next) -> @dereference req, next

    # A usable hook that gets asynchronously invoked once a sentence
    # comes through an opened channel. This happens every time when
    # a client tries to invoke a server site provider method. This
    # is a good place to validate if an invocation is legitimate or
    # not. If you do not invoke `next` then the call won't happen!
    sentence: (sob, trail..., next) -> @dereference sob, next

    # Dereference the potentially existent entity from the session
    # into the supplied container, where the session is residing. It
    # basically retrieves the hibernated entity, ressurects it and
    # defined the appropriate getter property on supplied container.
    # If the entity or session does not exist, nothing gets defined.
    dereference: (container, callback) ->
        sid = "x-authenticate-entity"; key = "entity"
        return callback() unless session = container.session
        return callback() unless content = session[sid]
        delete container[key] if _.has container, key
        @ressurectEntity ?= (xc, xn) -> xn null, xc
        @ressurectEntity content, (error, entity) ->
            format = (e) -> "ressurection error: #{e}"
            return callback format error if error
            assert p = new Object enumerable: yes
            p.get = -> return entity or undefined
            Object.defineProperty container, key, p
            assert container[key]?; callback()

    # Authenticate supplied entity as the authorized entity against
    # the session found in the specified session container. Session
    # container could be either a request or duplex socket or other
    # member that has the session storage installed under `session`.
    # The method also saves the session once it has authenticated.
    authenticate: (container, entity, rme, callback) ->
        noSave = "the session has not save function"
        noSession = "container has no session object"
        assert session = container?.session, noSession
        assert _.isObject(entity), "malformed entity"
        @hibernateEntity ?= (xe, xn) -> xn null, xe
        @hibernateEntity entity, (error, content) =>
            return callback error, undefined if error
            assert not _.isEmpty(content), "no content"
            session["x-authenticate-entity"] = content
            assert _.isFunction(session.save), noSave
            session.cookie.maxAge = 2628000000 if rme
            session.save => @dereference container, ->
                return callback undefined, content
