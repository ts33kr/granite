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
async = require "async"
assert = require "assert"
colors = require "colors"
logger = require "winston"

_ = require "lodash"
tools = require "./tools"
extendz = require "./extends"
routing = require "./routing"
{Service} = require "./service"
{STATUS_CODES} = require "http"

# This is an abstract base class for every service in the system
# and in the end user application that provides a REST interface
# to some arbitrary resource, determined by HTTP path and guarded
# by the domain matching. This is the crucial piece of framework.
# It supports strictly methods defined in the HTTP specification.
module.exports.Restful = class Restful extends Service

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
    @SUPPORTED = ["GET", "PUT", "POST", "DELETE", "OPTIONS", "PATCH"]

    # Impose a conditional limitation on the service. The limiation
    # will be invoked when a router is determining whether a service
    # matches the condition or not. The limitation has to either do
    # accept or decline. Do this by calling `decide` with a boolean!
    # Especially useful for service with the same resource but with
    # different conditions, such as mobile only and desktop only.
    @condition: (synopsis, limitation) ->
        return @$condition if arguments.length is 0
        limitation = _.find arguments, _.isFunction
        generic = "service condition: #{limitation}"
        synopsis = generic unless _.isString synopsis
        noLimitation = "a limitation has to be function"
        wrongSignature = "malformed limitation signature"
        assert _.isString(synopsis), "got no synopsis"
        assert _.isFunction(limitation), noLimitation
        assert limitation.length >= 3, wrongSignature
        assert _.isArray inherited = @$condition or []
        return @$condition = inherited.concat
            limitation: limitation
            synopsis: synopsis

    # This method is almost an entire implementation of a middleware
    # system for services. When you call it from within the service
    # definition with a function - it install it as middleware. But
    # When you invoke it without arguments, it assembled and returns
    # the executor that spins up all the middlewares. Please refer
    # to the `process` method implementation to get a usage example.
    @middleware: (implement) ->
        assert _.isFunction seq = async.series or 0
        assert _.isArray m = @$middleware or Array()
        a = (fun, t, s, n) -> fun.apply t, s.concat(n)
        f = (s) -> _.map m, (b) => (n) => a(b, @, s, n)
        executor = (s) -> (c) => seq f.call(this, s), c
        return executor if (arguments.length or 0) is 0
        noImplement = "supply the middleware function"
        wrongSignature = "a wrong implement signature"
        try implement = _.find arguments, _.isFunction
        assert _.isFunction(implement), noImplement
        assert implement.length >= 3, wrongSignature
        assert _.isArray inherited = @$middleware or []
        @$middleware = inherited.concat implement; @

    # This method is intended for indicating to a client that the
    # method that has been used to make the request is not supported
    # by this service of the internals that are comprising service.
    # Can be used from the outside, but generally should not be done.
    # Will be invoked if a method is not defined or not implemented.
    unsupported: (request, response, next) ->
        assert codes = http.STATUS_CODES or Object()
        assert methodNotAllowed = code = 405 # HTTP
        assert message = try codes[methodNotAllowed]
        doesJson = response.accepts(/json/) or false
        response.writeHead methodNotAllowed, message
        descriptor = error: "#{message}", code: code
        @emit "unsupported", request, response, next
        return response.send descriptor if doesJson
        response.send message.toString(); return @

    # This method determines whether the supplied HTTP request
    # matches this service. This is determined by examining the
    # domain/host and the path, in accordance with the patterns
    # that were used for configuring the class of this service.
    # It is async, so be sure to call the `decide` with boolean!
    matches: (request, response, decide) ->
        conditions = try @constructor.condition() or []
        conditions = Array() unless _.isArray conditions
        identify = try @constructor?.identify().underline
        p = (i, cn) -> i.limitation request, response, cn
        fails = "service #{identify} fails some conditions"
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
    process: (request, response, next) ->
        method = request.method.toUpperCase()
        assert _.isPlainObject tokens = super
        known = method in @constructor.SUPPORTED
        return @unsupported arguments... unless known
        missing = "a #{method} method not implemented"
        throw new Error missing unless method of this
        variables = [tokens.resource, tokens.domain]
        headers = @downstream headers: -> return null
        partial = _.partial headers, request, response
        response.on "header", -> partial variables...
        assert mw = @constructor.middleware().bind this
        signature = [request, response, variables...]
        intake = (fn) => @downstream preprocess: fn
        go = (fn) => usp = intake fn; usp signature...
        go => mw(signature) (error, results, misc) =>
            assert expanded = _.clone variables or []
            expanded.push request.session or undefined
            this[method] request, response, expanded...
            postprocess = @downstream postprocess: ->
            postprocess request, response, variables...

    # Reject the request by sending an error descriptor object as a
    # response. The error descriptor is a top level object that will
    # embed the rejection information inside of itself. Optionally
    # you can supply the HTTP code that corresponds to a rejection.
    # Please use this methods rather than sending errors directly!
    reject: (response, content, code, keepalive) ->
        code = 400 unless _.isNumber code or null
        noContent = "the content has to be an object"
        corrupted = "response prototype is corrupted"
        assert _.isObject(response), "got no response"
        assert _.isFunction(response.send), corrupted
        assert _.isObject(content or null), noContent
        upload = -> return response.send code, content
        try this.emit.call this, "reject", arguments...
        prerejection = @downstream prerejection: =>
            process.nextTick -> do -> try upload()
            postrejection = @downstream postrejection: ->
            postrejection.call this, response, content
        return prerejection response, content

    # Push the supplied content to the requester by utilizing the
    # response object. This is effectively the same as calling the
    # `response.send` directly, but this method is wired into the
    # system of service hooks. Refer to the original sender for
    # more information on how the content is encoded and passed.
    push: (response, content, code, keepalive) ->
        code = 200 unless _.isNumber code or null
        ok = _.isArray(content) or _.isObject(content)
        corrupted = "a response prototype is corrupted"
        carrier = "has to be either an object or array"
        assert _.isObject(response), "got no response"
        assert _.isFunction(response.send), corrupted
        assert content and ok is yes, carrier.toString()
        try this.emit.call this, "push", arguments...
        upload = -> return response.send code, content
        assert prepushing = @downstream prepushing: =>
            process.nextTick -> do -> try upload()
            postpushing = @downstream postpushing: ->
            postpushing.call this, response, content
        return prepushing response, content
