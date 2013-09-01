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

asciify = require "asciify"
connect = require "connect"
assert = require "assert"
logger = require "winston"
events = require "eventemitter2"
colors = require "colors"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"
url = require "url"

_ = require "lodash"
api = require "../nucleus/api"
stubs = require "../nucleus/stubs"
tools = require "../nucleus/tools"
{Document} = require "./document"

# This is an abstract base class API stub service. Its purpose is
# providing the boilerplate for documentation and speicification of
# the services using the built it documentation mechanisn. This class
# provide not only function for definition but also for retrieval of
# the documentation on either the per-service or all-at-once basis.
module.exports.Descriptor = class Descriptor extends stubs.WithHooks

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    @abstract yes

    # Define a set of aliases that allow for extremely convenient
    # and short way of running the description against the REST
    # methods. These definitions proxy the calls from static scope
    # to the prototype scope, and implicitly run the description
    # routine on the targeted REST methods. Prefer using these.
    @OPTIONS = -> @describe @prototype.OPTIONS, arguments...
    @DELETE = -> @describe @prototype.DELETE, arguments...
    @PATCH = -> @describe @prototype.PATCH, arguments...
    @POST = -> @describe @prototype.POST, arguments...
    @GET = -> @describe @prototype.GET, arguments...
    @PUT = -> @describe @prototype.PUT, arguments...

    # Traverse all of the services that are registered with the router
    # and collect the documentation for each method, then given this
    # information, build a hierarhical tree object of all the methods
    # and the services that implement them and return to the invoker.
    collectDescriptions: (substitution) ->
        services = @kernel?.router?.registry
        services = substitution if substitution?
        assert _.isArray(services), "invalid services"
        logger.debug "Collecting API documentation"
        _.map services, (service) => do (service) =>
            unsupported = service.unsupported
            supported = service.constructor.SUPPORTED
            implemented = (m) -> service[m] isnt unsupported
            fix = (m) => @constructor.describe service[m], ->
            doc = (m) => (service[m].document or fix(m)).blankSlate()
            filtered = _.filter supported, implemented
            methods = _.object filtered, _.map(filtered, doc)
            args = (method) => [method, service, @kernel]
            url = tools.urlWithHost no, service.location()
            doc.leads url for m, doc of methods when not doc.leads()
            doc.descriptor? args(m)... for m, doc of methods
            return service: service, methods: methods

    # Describe the supplied method of arbitrary service, in a structured
    # and expected way, so that it can later be used to programmatically
    # process such documentation and do with it whatever is necessary.
    # This approach gives unique ability to build self documented APIs.
    @describe: (method, descriptor) ->
        noMethod = "The #{method} is not a valid method"
        noDescriptor = "The #{descriptor} is not a descriptor"
        assert _.isFunction(method), noMethod
        assert _.isFunction(descriptor), noDescriptor
        previous = method.document?.descriptor
        method.document ?= new Document
        method.document.descriptor = ->
            previous?.apply this, arguments
            descriptor.apply this, arguments
        method.document.blankSlate = ->
            document = new Document
            document.descriptor = @descriptor
            document.blankSlate = @blankSlate
            return document
        return method.document
