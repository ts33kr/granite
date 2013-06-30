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

_ = require "underscore"
logger = require "winston"
events = require "events"
colors = require "colors"
util = require "util"

# A simple yet solid HTTP request router. This is designed to map
# HTTP requests to the correpsonding handlers by examining URL and
# the supplied host, among other things. The exact matching logic
# is up to the handlers that implement the corresponding methods.
# This router just provides the infrastructure and boilerplating.
module.exports.Router = class Router extends events.EventEmitter

    # The method implements a middleware (for Connect) that looks
    # up the relevant routable and dispatches the request to the
    # routable. If no corresponding routable is found, the method
    # transfers the control to the pre-installed, default routable.
    # A set of tests are performed to ensure the logical integrity.
    lookupMiddleware: (request, response, next) ->
        incoming = util.inspect(request)
        parameters = [request, response, next]
        predicate = (routable) -> routable.matches(parameters...)
        recognized = _.find(@registry or [],  predicate) or null
        if recognized? then inspected = util.inspect(recognized)
        logger.debug("An #{incoming} matches #{inspected}".grey) if recognized?
        return recognized.process(parameters...) and next() if recognized?
        logger.warn("No routable for #{incoming} request".yellow)
        matches = @fallback?.matches(request, response, next)
        return @fallback.process(parameters...) and next() if matches?
        logger.warn("Fallback failed for #{incoming}".yellow); next()

    # Try registering a new routable object. The method checks for
    # the object to be of the correct type, basically making sure
    # that it is capable of doing the routing functionality code.
    # If something is wrong, this method will throw an exception.
    # The method is idempotent, ergo no duplication of routables.
    registerRoutable: (routable) ->
        inspected = util.inspect(routable)
        duplicate = routable in @registry or []
        [matches, process] = [routable.matches, routable.process]
        goneMatches = "The #{routable} has no valid matches method"
        goneProcess = "The #{routable} has no valid process method"
        passMatches = _.isFunction(matches) and matches?.length is 3
        passProcess = _.isFunction(process) and process?.length is 3
        throw new Error(goneMatches) unless passMatches
        throw new Error(goneProcess) unless passProcess
        logger.info("Adding #{inspected} to the registry".magenta)
        (@registry ?= [] push routable unless duplicate)
        (@emit("registered", routable) unless duplicate); this

    # Install the routable that should handle the requests that are
    # not handled via the registered routables. The routable has to
    # implement the same interface as the usual routable. This method
    # ensures this by performing the same tests as register method.
    # Remember that it should implement the widescope matching logic.
    installFallback: (routable) ->
        inspected = util.inspect(routable)
        [matches, process] = [routable.matches, routable.process]
        goneMatches = "The #{routable} has no valid matches method"
        goneProcess = "The #{routable} has no valid process method"
        passMatches = _.isFunction(matches) and matches?.length is 3
        passProcess = _.isFunction(process) and process?.length is 3
        throw new Error(goneMatches) unless passMatches
        throw new Error(goneProcess) unless passProcess
        logger.info("Installing #{inspected} as fallback".magenta)
        @fallback = routable; @emit("fallback", routable); this
