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
events = require "events"
colors = require "colors"
logger = require "winston"

_ = require "lodash"
routing = require "./routing"
service = require "./service"

# This is an abstract base class for every service in the system
# and in the end user application that provides a REST interface
# to some arbitrary resource, determined by HTTP path and guarded
# by the domain matching. This is the crucial piece of framework.
# It supports strictly methods defined in the HTTP specification.
module.exports.Api = class Api extends service.Service

    # An array of HTTP methods (also called verbs) supported by the
    # this abstract base class. The array of methods is strictly
    # limited by the HTTP specification by default. You can though
    # override it and provie support for more methods, up to you.
    @SUPPORTED = ["GET", "PUT", "POST", "DELETE", "OPTIONS"]

    # This method is intended for indicating to a client that the
    # method that has been used to make the request is not supported
    # by this service of the internals that are comprising service.
    # Can be used from the outside, but generally should not be done.
    unsupported: (request, response, next) ->
        methodNotAllowed = 405
        codes = http.STATUS_CODES
        message = codes[methodNotAllowed]
        doesJson = response.accepts /json/
        response.writeHead(methodNotAllowed, message)
        descriptor = error: message, code: methodNotAllowed
        @emit("unsupported", request, response, next)
        return response.send descriptor if doesJson
        response.send message; this

    # Process the already macted HTTP request according to the REST
    # specification. That is, see if the request method conforms to
    # to the RFC, and if so, dispatch it onto corresponding method
    # defined in the subclass of this abstract base class. Default
    # implementation of each method will throw a not implemented.
    process: (request, response, next) ->
        knowns = @constructor.SUPPORTED
        parameters = [request, response, next]
        tokens = super(parameters...)
        method = request?.method?.toUpperCase()?.trim()
        return @unsupported(parameters...) unless method in knowns
        missing = "Missing implementation for #{method} method"
        throw new Error(missing) unless method of this
        variables = [tokens.resource, tokens.domain]
        this[method](request, response, variables...); this

    # This method should generally be used to obtain HTTP methods that
    # are allowed on this resources. This is not the only possible way
    # of implementing this method, because it usually can have a lot of
    # different interpretations other than the one in the HTTP spec.
    OPTIONS: (request, response) ->
        knowns = @constructor.SUPPORTED
        doesJson = response.accepts /json/
        pathname = try url.parse(request.url).pathname
        checkIfSupported = (method) => @[method] isnt @unsupported
        supported = _.filter(knowns, checkIfSupported)
        descriptor = methods: supported, resource: pathname
        return respons.send descriptor if doesJson
        response.send supported.join ", "; this

# An abstract base class with all of the HTTP methods, defined in
# the HTTP specification and covered by the base implementation
# stubbed with default implementations. By default, the methods
# will throw the 405, method not allowed HTTP error status code.
# The methods have implementations, but marked as unsupported.
module.exports.Stub = class Stub extends Api

    # Delete the contents of the resources at the establushed path. It
    # generally should destroy the contents of the resource for good.
    # Be sure to provide enough protection for your API for destructive
    # HTTP methods like this one. Apply it to indicate destruction.
    DELETE: @::unsupported

    # Append the contents to the resources at the established path. It
    # usually means adding new content in addition to the old one. This
    # HTTP method nicely maps to INSERT method of the storage engines.
    # Use this method to successively append new contents to resources.
    POST: @::unsupported

    # Alter the contents of the resources at the established path. It
    # usually means replacing the old contents with the new contents.
    # This HTTP method nicely maps to UPDATE method of the storages.
    # Use this method to repetidely replace the contents of resources.
    PUT: @::unsupported

    # Get the contents of the resources at the established path. It
    # is a good idea for this HTTP method to be idempotent. As the
    # rule, this method does not have to alter any contents or data
    # of the resource. Use for unobtrusive retrieval of resources.
    GET: @::unsupported
