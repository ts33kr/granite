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
util = require "util"

{Archetype} = require "./archetype"

# A simple yet solid HTTP request router. This is designed to map
# HTTP requests to the correpsonding handlers by examining URL and
# the supplied host, among other things. The exact matching logic
# is up to the handlers that implement the corresponding methods.
# This router just provides the infrastructure and boilerplating.
module.exports.Router = class Router extends Archetype

    # Every router has to have a public constructor that accepts
    # the kernel instance as a parameter. You can override it as
    # you see fit, but be sure to invoke the super constructor and
    # it is highly advised to store the kernel instance in object.
    constructor: (@kernel) ->

    # Try registering a new routable object. The method checks for
    # the object to be of the correct type, basically making sure
    # that it is capable of doing the routing functionality code.
    # If something is wrong, this method will throw an exception.
    # The method is idempotent, ergo no duplication of routables.
    register: (routable, callback) ->
        identify = routable?.constructor?.identify()
        inspected = identify.toString().underline
        [matches, process] = [routable.matches, routable.process]
        goneMatches = "The #{identify} has no valid matches method"
        goneProcess = "The #{identify} has no valid process method"
        passMatches = _.isFunction(matches) and matches.length is 3
        passProcess = _.isFunction(process) and process.length is 3
        throw new Error goneMatches unless passMatches
        throw new Error goneProcess unless passProcess
        return this if routable in (@registry or [])
        register = routable.upstreamAsync "register", =>
            attaching = "Attaching %s service instance"
            logger.info attaching.blue, inspected
            @emit "register", routable, @kernel
            (@registry ?= []).unshift routable
            return unless _.isFunction callback
            return callback routable, this
        register @kernel, this; @

    # Unregister the supplied service instance from the kernel router.
    # You should call this method only after the service has been
    # previously registered with the kernel router. This method does
    # modify the router register, ergo does write access to kernel.
    # It will also call hooks on the service, notifying unregister.
    unregister: (routable, callback) ->
        noClass = "broken routable: #{routable}"
        assert routable?.constructor?, noClass
        identify = routable.constructor.identify()
        inspected = identify.toString().underline
        noRegistry = "Could not access the registry"
        removing = "Removing %s service instance"
        assert _.isArray @registry, noRegistry
        index = _.indexOf @registry, routable
        assert index >= 0, "service #{inspected} is missing"
        unregister = routable.upstreamAsync "unregister", =>
            @emit "unregister", @routable, @kernel
            logger.info removing.yellow, inspected
            @registry.splice index, 1 # delete
            return unless _.isFunction callback
            return callback routable, this
        unregister @kernel, this; @

    # The method implements a middleware (for Connect) that looks
    # up the relevant routable and dispatches the request to the
    # routable. If no corresponding routable is found, the method
    # transfers the control to the pre-installed, default routable.
    # A set of tests are performed to ensure the logical integrity.
    middleware: (request, response, next) ->
        incoming = "#{request.url.underline}"
        args = a if _.isArguments a = arguments
        predicate = (routable) -> routable.matches args...
        recognized = _.find @registry or [],  predicate
        missing = "Request %s does not match any service"
        logger.debug missing.grey, incoming unless recognized?
        return next() unless _.isObject recognized
        constructor = recognized.constructor
        identify = constructor?.identify()?.underline
        @emit "recognized", recognized, arguments...
        matching = "Request %s matches %s service"
        logger.debug matching.grey, incoming, identify
        return results = recognized.process arguments...
        next() unless response.headerSent
