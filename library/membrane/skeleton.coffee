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
assert = require "assert"
colors = require "colors"
logger = require "winston"

extendz = require "../nucleus/extends"
compose = require "../nucleus/compose"

{RestfulService} = require "../nucleus/restful"

# This is an abstract base class for every service in the system
# and in the end user application that provides a REST interface
# to some arbitrary resource, determined by HTTP path and guarded
# by the domain matching. This is the crucial piece of framework.
# It supports strictly methods defined in the HTTP specification.
module.exports.Barebones = class Barebones extends RestfulService

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # A hook that will be called once the Connect middleware writes
    # off the headers. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    headers: (request, response, resource, domain, next) -> next()

    # A hook that will be called prior to invoking the API method
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    processing: (request, response, resource, domain, next) -> next()

    # This method should generally be used to obtain HTTP methods that
    # are allowed on this resources. This is not the only possible way
    # of implementing this method, because it usually can have a lot of
    # different interpretations other than the one in the HTTP spec.
    # The method is an HTTP verb, coherent with the REST interface.
    # Lookup the `RestfulService` for meaning of other parameters.
    OPTIONS: (request, response, resource, domain, session) ->
        assert knowns = try @constructor.SUPPORTED
        doesJson = response.accepts(/json/) or false
        pathname = try url.parse(request.url).pathname
        assert _.isString(pathname), "could not get path"
        assert _.isObject(request), "got invalid request"
        assert _.isObject(response), "got invalid response"
        assert _.isArray(resource), "malformed resource"
        assert _.isArray(domain), "malformed domain name"
        checkIfSupported = (m) => @[m] isnt @unsupported
        existing = _.filter knowns, (name) => this[name]?
        supported = try _.filter existing, checkIfSupported
        descriptor = methods: supported, resource: pathname
        return this.push response, descriptor if doesJson
        assert _.isString formatted = supported.join ", "
        assert formatted = _.sprintf "%s\r\n", formatted
        response.send formatted.toString(); return @
