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
        assert limitation.length is 3, wrongSignature
        assert _.isArray inherted = @$condition or []
        return @$condition = inherted.concat
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
        assert implement.length is 5, wrongSignature
        assert _.isArray inherited = @$middleware or []
        @$middleware = inherited.concat implement; @

    # This method is intended for indicating to a client that the
    # method that has been used to make the request is not supported
    # by this service of the internals that are comprising service.
    # Can be used from the outside, but generally should not be done.
    unsupported: (request, response, next) ->
        assert methodNotAllowed = 405
        assert codes = http.STATUS_CODES
        assert message = codes[methodNotAllowed]
        doesJson = response.accepts(/json/) or no
        response.writeHead methodNotAllowed, message
        descriptor = error: message, code: methodNotAllowed
        @emit "unsupported", request, response, next
        return response.send descriptor if doesJson
        response.send message; return this

    # This method determines whether the supplied HTTP request
    # matches this service. This is determined by examining the
    # domain/host and the path, in accordance with the patterns
    # that were used for configuring the class of this service.
    # It is async, so be sure to call the `decide` with boolean!
    matches: (request, response, decide) ->
        conditions = @constructor.condition?()
        conditions = [] unless _.isArray conditions
        identify = @constructor?.identify().underline
        p = (i, c) -> i.limitation request, response, c
        fails = "service #{identify} fails some conditions"
        return super request, response, (decision) =>
            return decide no unless decision
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
        method = request?.method?.toUpperCase()?.trim()
        [tokens, knowns] = [super, @constructor.SUPPORTED]
        return @unsupported arguments... unless method in knowns
        missing = "Missing implementation for #{method} method"
        throw new Error missing unless method of this
        variables = [tokens.resource, tokens.domain]
        headers = @upstreamAsync "headers", _.identity
        partial = _.partial headers, request, response
        response.on "header", -> partial variables...
        assert mw = @constructor.middleware().bind this
        prestreamer = @upstreamAsync "preprocess", =>
            mw([request, response, variables...]) (error) =>
                this[method](request, response, variables...)
                poststreamer = @upstreamAsync "postprocess"
                poststreamer request, response, variables...
        prestreamer request, response, variables...

    # Reject the request by sending an error descriptor to as the
    # response. The error descriptor is a top level object that will
    # embed the supplied content object inside of itself. Optionally
    # you can supply the failing code and an HTTP response phrase.
    # Please use this methods rather than sending errors directly!
    reject: (response, content, code, phrase) ->
        noContent = "content has to be an object"
        assert _.isObject(content or 0), noContent
        try @emit "reject", this, response, content
        code = 400 unless _.isNumber(code or null)
        assert phrase = phrase or STATUS_CODES[code]
        uploader = -> response.send errors: content
        prestreamer = @upstreamAsync "prerejection", =>
            response.writeHead code, phrase; uploader()
            poststreamer = @upstreamAsync "postrejection"
            return poststreamer response, content
        return prestreamer response, content

    # Push the supplied content to the requester by utilizing the
    # response object. This is effectively the same as calling the
    # `response.send` directly, but this method is wired into the
    # system of service hooks. Refer to the original sender for
    # more information on how the content is encoded and passed.
    push: (response, content) ->
        isContent = content isnt undefined
        noContent = "No valid content supplied"
        throw new Error noContent unless isContent
        try @emit "push", this, response, content
        uploader = -> return response.send content
        prestreamer = @upstreamAsync "prepushing", =>
            poststreamer = @upstreamAsync "postpushing"
            uploader(); poststreamer response, content
        return prestreamer response, content
