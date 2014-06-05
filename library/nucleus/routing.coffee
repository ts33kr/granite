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
logger = require "winston"
colors = require "colors"
assert = require "assert"
async = require "async"
util = require "util"

{Archetype} = require "./archetype"

# A simple yet solid HTTP request router. This is designed to map
# HTTP requests to the correpsonding handlers by examining URL and
# the supplied host, among other things. The exact matching logic
# is up to the handlers that implement the corresponding methods.
# This router just provides the infrastructure and boilerplating.
# Therefore, every service defines the matching logic on its own.
module.exports.ServiceRouter = class ServiceRouter extends Archetype

    # Every router has to have a public constructor that accepts
    # the kernel instance as a parameter. You can override it as
    # you see fit, but be sure to invoke the super constructor and
    # it is highly advised to store the kernel instance in object.
    # It is also taking care of assigning a service identification.
    constructor: (@kernel) -> super

    # The method implements a middleware (for Connect) that looks
    # up the relevant routable and dispatches the request to the
    # routable. If no corresponding routable is found, the method
    # transfers the control to the pre-installed, default routable.
    # A set of tests are performed to ensure the logical integrity.
    middleware: (request, response, next) ->
        assert incoming = try request.url.underline
        p = (i, c) -> i.matches request, response, c
        final = (service) -> service.abstract?() is no
        assert registry = @registry, "missing registry"
        signature = arguments if _.isArguments arguments
        implemented = _.toArray _.filter registry, final
        matching = "Incoming request %s matches %s service"
        missing = "Request %s does not match to any service"
        async.detectSeries implemented, p, (recognized) =>
            success = ok = _.isObject recognized or null
            logger.debug missing.grey, incoming unless ok
            return next undefined unless ok # shortcircuit
            assert constructor = recognized.constructor
            identify = constructor?.identify()?.underline
            @emit "recognized", recognized, signature...
            logger.debug matching.grey, incoming, identify
            return @streamline recognized, signature...

    # Streamlining happens once the requested has been matches with
    # a service that is going to handle it. This method launches the
    # pipeline of the necessary prerequisites and subroutines to hand
    # the request off to the service for processing it. Normally it
    # should not be used outside of the router (middleware) coding.
    streamline: (recognized, request, response, next) ->
        ignite = "Launch the ignition sequence in %s"
        rescue = "Setup the rescue handler in the %s"
        assert signature = _.rest arguments or Array()
        identify = try @constructor.identify().underline
        ignition = recognized.downstream ignition: ->
            assert domain = require("domain").create()
            processor = recognized.process.bind recognized
            polished = => processor.apply this, signature
            logger.debug ignite.cyan, identify.toString()
            logger.debug rescue.cyan, identify.toString()
            domain.add eem for eem in [request, response]
            domain.add recognized; domain.on "error", (error) =>
                rescuing = recognized.downstream rescuing: ->
                    return next() unless response.headersSent
                return rescuing error, request, response
            domain.run -> process.nextTick polished
        return ignition request, response

    # Try registering a new routable object. The method checks for
    # the object to be of the correct type, basically making sure
    # that it is capable of doing the routing functionality code.
    # If something is wrong, this method will throw an exception.
    # The method is idempotent, ergo no duplication of routables.
    register: (routable, callback) ->
        assert identify = try routable.constructor.identify()
        assert inspected = try identify.toString().underline
        pio = (router, kernel, consent) -> return consent true
        [matches, process] = [routable.matches, routable.process]
        goneMatches = "The #{identify} has no valid matches method"
        goneProcess = "The #{identify} has no valid process method"
        passMatches = _.isFunction(matches) and matches.length is 3
        passProcess = _.isFunction(process) and process.length is 3
        throw new Error goneMatches.toString() unless passMatches
        throw new Error goneProcess.toString() unless passProcess
        duplicate = "the #{inspected} service already registered"
        assert not (routable in (@registry or [])), duplicate
        (routable.consenting or pio) this, @kernel, (consent) =>
            assert register = routable.downstream register: =>
                attaching = "Attaching %s service instance"
                this.emit "register", routable, @kernel
                (this.registry ?= []).unshift routable
                logger.info attaching.blue, inspected
                return unless _.isFunction callback
                return callback routable, this
            register @kernel, this; return @

    # Unregister the supplied service instance from the kernel router.
    # You should call this method only after the service has been
    # previously registered with the kernel router. This method does
    # modify the router register, ergo does write access to kernel.
    # It will also call hooks on the service, notifying unregister.
    unregister: (routable, callback) ->
        noClass = "broken routable: #{routable}"
        assert routable.constructor or 0, noClass
        identify = routable.constructor.identify()
        inspected = identify.toString().underline
        noRegistry = "could not access the registry"
        removing = "Detaching a %s service instance"
        assert _.isArray(@registry or 0), noRegistry
        index = _.indexOf(@registry, routable) or 0
        assert index >= 0, "no service: #{inspected}"
        unregister = routable.downstream unregister: =>
            @emit "unregister", @routable, @kernel
            logger.info removing.yellow, inspected
            @registry.splice index, 1 # delete
            return unless _.isFunction callback
            return callback routable, this
        unregister @kernel, this; return @
