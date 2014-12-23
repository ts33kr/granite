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

url = require "url"
http = require "http"
util = require "util"
weak = require "weak"
async = require "async"
assert = require "assert"
colors = require "colors"
logger = require "winston"

_ = require "lodash"
tools = require "./toolkit"
extendz = require "./extends"
routing = require "./routing"
{STATUS_CODES} = require "http"
{Service} = require "./service"

# This is an abstract base class for every service in the system
# and in the end user application that provides a REST interface
# to some arbitrary resource, determined by HTTP path and guarded
# by the domain matching. This is the crucial piece of framework.
# It supports strictly methods defined in the HTTP specification,
# yet providing a tiny enough structure to be able to override it.
module.exports.RestfulService = class RestfulService extends Service

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # An array of HTTP methods (also called verbs) supported by the
    # this abstract base class. The array of methods is strictly
    # limited by the HTTP specification by default. You can though
    # override it and provie support for more methods, up to you.
    # If you do, then be sure to provide the necessary stubbing.
    @SUPPORTED: ["GET", "PUT", "POST", "DELETE", "OPTIONS", "PATCH"]

    # Symbol declaration table, that states what keys, if those are
    # vectors (arrays) should be exported and then merged with their
    # counterparts in the destination, once the composition process
    # takes place. See the `Archetype::composition` hook definition
    # for more information. Keys are names, values can be anything.
    @COMPOSITION_EXPORTS: conditions: 1, middlewares: 1

    # Impose a conditional limitation on the service. The limiation
    # will be invoked when a router is determining whether a service
    # matches the condition or not. The limitation has to either do
    # accept or decline. Do this by calling `decide` with a boolean!
    # Especially useful for service with the same resource but with
    # different conditions, such as mobile only and desktop only.
    @condition: (xsynopsis, xlimitation) ->
        return try @conditions if arguments.length is 0
        synopsis = _.find(arguments, _.isString) or null
        limitation = try _.find(arguments, _.isFunction)
        generic = "service condition: #{limitation.name}"
        try synopsis = generic unless _.isString synopsis
        noLimitation = "a limitation has to be function"
        wrongSignature = "malformed limitation signature"
        assert _.isString(synopsis), "got no synopsis"
        assert _.isFunction(limitation), noLimitation
        assert limitation.length >= 3, wrongSignature
        assert _.isArray inherited = @conditions or []
        fn = (arbitraryVector) -> return limitation
        assert inherited = try _.unique inherited
        return fn @conditions = inherited.concat
            limitation: limitation # a function
            synopsis: synopsis # an explanation

    # This method is almost an entire implementation of a middleware
    # system for services. When you call it from within the service
    # definition with a function - it install it as middleware. But
    # When you invoke it without arguments, it assembled and returns
    # the executor that spins up all the middlewares. Please refer
    # to the `process` method implementation to get a usage example.
    @middleware: (ximplement) ->
        seq = -> log(); async.series arguments...
        log = -> logger.debug message.yellow, idc
        idc = this.identify().toString().underline
        assert _.isArray m = @middlewares or Array()
        message = "Running middleware sequence for %s"
        a = (fun, t, s, n) -> fun.apply t, s.concat(n)
        f = (s) -> _.map m, (b) => (n) => a(b, @, s, n)
        executor = (s) -> (c) => seq f.call(this, s), c
        return executor if (arguments.length or 0) is 0
        noImplement = "supply the middleware function"
        wrongSignature = "a wrong implement signature"
        try implement = _.find arguments, _.isFunction
        assert _.isFunction(implement or 0), noImplement
        assert (implement?.length >= 3), wrongSignature
        assert _.isArray inherited = @middlewares or []
        @middlewares = try inherited.concat implement
        @middlewares = _.unique @middlewares; this

    # An experimental spinoff engine that is based on the isolated
    # providers concept. Basically, an HTTP verb or the middleware
    # that is decorated with this method will be isolated to be run
    # under the shadow of the real service instance. The process is
    # idempotent. Please refer to the implementation of this method
    # and to the implementation of the `DuplexCore` for information.
    @spinoff: (implement) -> (request, response, signed) ->
        noImplement = "no valid implementation body"
        assert _.isFunction(implement), noImplement
        assert _.isArguments capture = arguments or 0
        m = "Spinned off incoming HTTP request at %s"
        shadow = request.shadow or Object.create this
        execute = -> implement.apply shadow, capture
        return execute() if _.isObject request.shadow
        assert _.isObject try request.shadow = shadow
        _.extend shadow, __isolated: yes, __origin: @
        _.extend shadow, response: try weak response
        _.extend shadow, request: try weak request
        s = get: -> try request.session or undefined
        e = get: -> try request[symbol] or undefined
        {AccessGate} = require "../shipped/access"
        symbol = try AccessGate.ACCESS_ENTITY_SYMBOL
        logger.debug m.grey, request.url?.underline
        Object.defineProperty shadow, "session", s
        Object.defineProperty shadow, symbol, e
        @emit "spinoff", capture...; execute()

    # This method is intended for indicating to a client that the
    # method that has been used to make the request is not supported
    # by this service of the internals that are comprising service.
    # Can be used from the outside, but generally should not be done.
    # Will be invoked if a method is not defined or not implemented.
    unsupported: (request, response, vars...) ->
        method = try request.method.toUpperCase()
        assert codes = http.STATUS_CODES or Object()
        assert methodNotAllowed = code = 405 # HTTP
        identify = @constructor?.identify().underline
        assert _.isObject(request), "got invalid request"
        assert _.isObject(response), "got invalid response"
        notify = "Unsupported HTTP method call %s in %s"
        assert message = try codes[methodNotAllowed]
        doesJson = response.accepts(/json/) or false
        response.writeHead methodNotAllowed, message
        descriptor = error: "#{message}", code: code
        assert stringified = JSON.stringify descriptor
        @emit "unsupported", request, response, vars...
        logger.debug notify.red, method.bold, identify
        return response.send stringified if doesJson
        response.end message.toString(); return @

    # This method determines whether the supplied HTTP request
    # matches this service. This is determined by examining the
    # domain/host and the path, in accordance with the patterns
    # that were used for configuring the class of this service.
    # It is async, so be sure to call the `decide` with boolean!
    matches: (request, response, decide) ->
        assert _.isObject(request), "got invalid request"
        assert _.isFunction(decide), "incorrect callback"
        conditions = try @constructor.condition() or null
        conditions = Array() unless _.isArray conditions
        identify = try @constructor?.identify().underline
        return decide no if @constructor.DISABLE_SERVICE
        p = (i, cn) -> i.limitation request, response, cn
        fails = "Service #{identify} fails some conditions"
        notify = "Running %s service conditional sequences"
        logger.debug notify.toString(), identify.toString()
        return super request, response, (decision) =>
            return decide no unless decision is yes
            async.every conditions, p, (confirms) ->
                return decide yes if confirms
                logger.debug fails.yellow
                decide no; return this

    # Process the already macted HTTP request according to the REST
    # specification. That is, see if the request method conforms to
    # to the RFC, and if so, dispatch it onto corresponding method
    # defined in the subclass of this abstract base class. Default
    # implementation of each method will throw a not implemented.
    process: @spinoff (request, response, next) ->
        method = request.method.toUpperCase()
        known = method in @constructor.SUPPORTED
        tokens = Service::process.apply @, arguments
        fits = known and (method of this) # yay or nay
        return @unsupported arguments... unless fits
        assert this.__isolated, "spin-off engine fail"
        variables = [tokens.resource, tokens.domain]
        headers = @downstream headers: -> return null
        partial = _.partial headers, request, response
        response.on "header", -> partial variables...
        assert mw = @constructor.middleware().bind this
        signature = [request, response, variables...]
        intake = (fn) => @downstream processing: fn
        go = (fn) => usp = intake fn; usp signature...
        go => mw(signature) (error, results, misc) =>
            assert expanded = _.clone variables or []
            expanded.push request.session or undefined
            this[method] request, response, expanded...
