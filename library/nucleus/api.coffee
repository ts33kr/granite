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
events = require "eventemitter2"
colors = require "colors"
logger = require "winston"

_ = require "lodash"
tools = require "./tools"
extendz = require "./extends"
routing = require "./routing"
service = require "./service"
{STATUS_CODES} = require "http"

# This is an abstract base class for every service in the system
# and in the end user application that provides a REST interface
# to some arbitrary resource, determined by HTTP path and guarded
# by the domain matching. This is the crucial piece of framework.
# It supports strictly methods defined in the HTTP specification.
module.exports.Api = class Api extends service.Service

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

    # This method is intended for indicating to a client that the
    # method that has been used to make the request is not supported
    # by this service of the internals that are comprising service.
    # Can be used from the outside, but generally should not be done.
    unsupported: (request, response, next) ->
        methodNotAllowed = 405
        codes = http.STATUS_CODES
        message = codes[methodNotAllowed]
        doesJson = response.accepts /json/
        response.writeHead methodNotAllowed, message
        descriptor = error: message, code: methodNotAllowed
        @emit "unsupported", request, response, next
        return response.send descriptor if doesJson
        response.send message; this

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
        prestreamer = @upstreamAsync "preprocess", =>
            this[method](request, response, variables...)
            poststreamer = @upstreamAsync "postprocess"
            poststreamer request, response, variables...
        prestreamer request, response, variables...

    reject: (response, content, code, phrase) ->
        isContent = _.isObject content
        noContent = "content has to be object"
        throw new Error noContent unless isContent
        @emit "reject", this, response, content
        code = 400 unless _.isNumber code
        phrase = phrase or STATUS_CODES[code]
        uploader = -> response.send errors: content
        prestreamer = @upstreamAsync "prerejection", =>
            response.writeHead(code, phrase); uploader()
            poststreamer = @upstreamAsync "postrejection"
            poststreamer response, content
        prestreamer response, content

    # Push the supplied content to the requester by utilizing the
    # response object. This is effectively the same as calling the
    # `response.send` directly, but this method is wired into the
    # system of service hooks. Refer to the original sender for
    # more information on how the content is encoded and passed.
    push: (response, content) ->
        isContent = content isnt undefined
        noContent = "No valid content supplied"
        throw new Error noContent unless isContent
        @emit "push", this, response, content
        uploader = -> response.send content
        prestreamer = @upstreamAsync "prepushing", =>
            poststreamer = @upstreamAsync "postpushing"
            uploader(); poststreamer response, content
        prestreamer response, content
