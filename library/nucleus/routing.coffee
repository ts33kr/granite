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
events = require "events"
colors = require "colors"
util = require "util"

# A simple yet solid HTTP request router. This is designed to map
# HTTP requests to the correpsonding handlers by examining URL and
# the supplied host, among other things. The exact matching logic
# is up to the handlers that implement the corresponding methods.
# This router just provides the infrastructure and boilerplating.
module.exports.Router = class Router extends events.EventEmitter

    # Every router has to have a public constructor that accepts
    # the kernel instance as a parameter. You can override it as
    # you see fit, but be sure to invoke the super constructor and
    # it is highly advised to store the kernel instance in object.
    constructor: (@kernel) ->

    # The method implements a middleware (for Connect) that looks
    # up the relevant routable and dispatches the request to the
    # routable. If no corresponding routable is found, the method
    # transfers the control to the pre-installed, default routable.
    # A set of tests are performed to ensure the logical integrity.
    middleware: (request, response, next) ->
        incoming = "#{request.url.underline}"
        parameters = [request, response, next]
        predicate = (routable) -> routable.matches parameters...
        recognized = _.find(@registry or [],  predicate)
        if recognized? then constructor = recognized.constructor
        identify = constructor?.identify()?.underline
        @emit "recognized", recognized, parameters... if recognized?
        matching = "Request #{incoming} matches #{identify} service"
        logger.debug matching.grey if recognized?
        return recognized.process parameters... if recognized?
        logger.warn "No routable for #{incoming} request".yellow
        next() unless response.headersSent

    # Try registering a new routable object. The method checks for
    # the object to be of the correct type, basically making sure
    # that it is capable of doing the routing functionality code.
    # If something is wrong, this method will throw an exception.
    # The method is idempotent, ergo no duplication of routables.
    register: (routable) ->
        identify = routable?.constructor?.identify()
        inspected = identify.toString().underline
        duplicate = routable in (@registry or [])
        [matches, process] = [routable.matches, routable.process]
        goneMatches = "The #{identify} has no valid matches method"
        goneProcess = "The #{identify} has no valid process method"
        passMatches = _.isFunction(matches) and matches?.length is 3
        passProcess = _.isFunction(process) and process?.length is 3
        throw new Error goneMatches unless passMatches
        throw new Error goneProcess unless passProcess
        logger.info "Attaching #{inspected} service instance".blue
        (@registry ?= []).push routable unless duplicate
        @emit "registered", routable unless duplicate
        routable.register?(); this
