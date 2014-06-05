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
events = require "eventemitter2"
colors = require "colors"
logger = require "winston"

extendz = require "./../nucleus/extends"
compose = require "./../nucleus/compose"

{RestfulStubs} = require "./../nucleus/stubs"
{Descriptor} = require "./describe"
{Healthcare} = require "./health"

# This is an abstract base class for every service in the system
# and in the end user application that provides a REST interface
# to some arbitrary resource, determined by HTTP path and guarded
# by the domain matching. This is the crucial piece of framework.
# It supports strictly methods defined in the HTTP specification.
module.exports.Barebones = class Barebones extends RestfulStubs

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # These declarations below are implantations of the abstracted
    # components by the means of the dynamic recomposition system.
    # Please take a look at the `Composition` class implementation
    # for all sorts of information on the composition system itself.
    # Each of these will be dynamicall integrated in class hierarchy.
    @implanting Descriptor
    @implanting Healthcare

    # This block describes certain method of abrbitrary service. The
    # exact process of how it is being documented depends on how the
    # documented function is implemented. Please refer to `Document`
    # class and its module implementation for more information on it.
    # Also, see `Descriptor` compound implementation for reference!
    @OPTIONS (method, service, kernel) ->
        @relevant "ts33kr.github.io/granite/membrane/skeleton.html"
        @github "ts33kr", "granite", "library/membrane/skeleton.coffee"
        @remark "This method is default implemented for each service"
        @synopsis "Get a set of HTTP methods supported by service"
        @outputs "An array of supported methods, JSON or string"
        @markings framework: "critical", stable: "positive"
        @version kernel.framework.version or undefined
        @produces "application/json", "text/html"

    # This method should generally be used to obtain HTTP methods that
    # are allowed on this resources. This is not the only possible way
    # of implementing this method, because it usually can have a lot of
    # different interpretations other than the one in the HTTP spec.
    # The method is an HTTP verb, coherent with the REST interface.
    OPTIONS: (request, response, resource, domain, session) ->
        assert knowns = try @constructor.SUPPORTED
        doesJson = response.accepts(/json/) or false
        pathname = try url.parse(request.url).pathname
        checkIfSupported = (m) => @[m] isnt @unsupported
        supported = try _.filter knowns, checkIfSupported
        descriptor = methods: supported, resource: pathname
        return this.push response, descriptor if doesJson
        assert formatted = supported.join(", ") + "\r\n"
        response.send formatted.toString(); return @
