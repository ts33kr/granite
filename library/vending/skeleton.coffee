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
url = require "url"
http = require "http"
util = require "util"
events = require "events"
colors = require "colors"
logger = require "winston"

tools = require "./../nucleus/tools"
extendz = require "./../nucleus/extends"
compose = require "./../nucleus/compose"
{WithHooks} = require "./../nucleus/stubs"
{Specification} = require "./specify"

# This is an abstract base class for every service in the system
# and in the end user application that provides a REST interface
# to some arbitrary resource, determined by HTTP path and guarded
# by the domain matching. This is the crucial piece of framework.
# It supports strictly methods defined in the HTTP specification.
module.exports.Standard = class Standard extends WithHooks

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    @abstract yes

    # These invocations establish the parameters which are going
    # to be used for matching HTTP requests against this service.
    # Typically an HTTP pathname pattern and a domain name pattern.
    # Try not to put constraints on the domain, unless necessary.
    # Also, the compounds for the composition system belong here.
    @compose Specification

    # This method should generally be used to obtain HTTP methods that
    # are allowed on this resources. This is not the only possible way
    # of implementing this method, because it usually can have a lot of
    # different interpretations other than the one in the HTTP spec.
    OPTIONS: (request, response) ->
        knowns = @constructor.SUPPORTED
        doesJson = response.accepts /json/
        pathname = try url.parse(request.url).pathname
        checkIfSupported = (method) => @[method] isnt @unsupported
        supported = _.filter knowns, checkIfSupported
        descriptor = methods: supported, resource: pathname
        return response.send descriptor if doesJson
        formatted = supported.join(", ") + "\r\n"
        response.send formatted; this

    # This block describes certain method a abrbitrary service. The
    # exact process of how it is being documented depends on how the
    # documented function is implemented. Please refer to `Document`
    # class and its module implementation for more information on it.
    @specification @prototype.OPTIONS, (method, service) ->
        @leads tools.urlWithHost no, service.location()
        @notes "This method is default implemented for each service"
        @synopsis "Get a set of HTTP methods supported by service"
        @outputs "An array of supported methods, JSON or string"
