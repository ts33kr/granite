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


{Document} = require "./document"
{RestfulStubs} = require "../nucleus/stubs"

# This is an abstract base class API stub service. Its purpose is
# providing the boilerplate for documentation and speicification of
# the services using the built it documentation mechanisn. This class
# provide not only function for definition but also for retrieval of
# the documentation on either the per-service or all-at-once basis.
module.exports.Descriptor = class Descriptor extends RestfulStubs

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # Define a set of aliases that allow for extremely convenient
    # and short way of running the description against the REST
    # methods. These definitions proxy the calls from static scope
    # to the prototype scope, and implicitly run the description
    # routine on the targeted REST methods. Prefer using these.
    @OPTIONS = (fn) -> @lazy -> @describe @prototype.OPTIONS, fn
    @DELETE = (fn) -> @lazy -> @describe @prototype.DELETE, fn
    @PATCH = (fn) -> @lazy -> @describe @prototype.PATCH, fn
    @POST = (fn) -> @lazy -> @describe @prototype.POST, fn
    @PUT = (fn) -> @lazy -> @describe @prototype.PUT, fn
    @GET = (fn) -> @lazy -> @describe @prototype.GET, fn

    # This method allows to configure the service with respect to
    # choosing to be documented or not. If the documentation is
    # enabled on the service, the description system will gather
    # its documentation and publish it via a doc system publisher.
    # The specific documentation settings will not be inherited!
    @documentation: (boolean) ->
        inquiry = arguments.length is 0 or false
        isDocumentation = @$documentation is this
        return isDocumentation if inquiry is yes
        invalidFlag = "the flag has to be boolean"
        assert _.isBoolean(boolean), invalidFlag
        return @$documentation = this if boolean
        delete @$documentation; return undefined

    # Traverse all of the services that are registered with the router
    # and collect the documentation for each method, then given this
    # information, build a hierarhical tree object of all the methods
    # and the services that implement them and return to the invoker.
    collectDescriptions: (substitution) ->
        assert services = @kernel?.router?.registry
        assert service = move if move = substitution
        assert _.isArray(services), "invalid services"
        publishing = (s) -> s.constructor.documentation()
        conformant = (s) -> do -> try s.objectOf Descriptor
        services = _.filter services, conformant or Array()
        services = _.filter services, publishing or Array()
        logger.debug "Collecting service API documentation"
        return _.map services, @documentService.bind this

    # Part of the internal descriptor system implementation. This
    # method is invoked for each of the collected service that are
    # determined to be eligable to publishing their documentation.
    # It basically extracts the documentation out of the service,
    # does the necessary initializations on it and return the doc.
    documentService: (service) ->
        assert unsupported = service.unsupported
        assert supported = service.constructor.SUPPORTED
        implemented = (m) -> service[m] isnt unsupported
        fix = (m) => @constructor.describe service[m], (->)
        doc = (m) => (service[m].document or fix(m)).blankSlate()
        filtered = _.filter supported, implemented or Array()
        methods = _.object filtered, _.map(filtered, doc)
        args = (method) => return [method, service, @kernel]
        assert not _.isEmpty link = service.qualified()
        doc.descriptor? args(m)... for m, doc of methods
        return service: service, methods: methods

    # Describe the supplied method of arbitrary service, in a structured
    # and expected way, so that it can later be used to programmatically
    # process such documentation and do with it whatever is necessary.
    # This approach gives unique ability to build self documented APIs.
    @describe: (method, descriptor) ->
        noMethod = "no target method has been supplied"
        noDescriptor = "got no valid descriptor supplied"
        assert _.isFunction(method or undefined), noMethod
        assert _.isFunction(descriptor or 0), noDescriptor
        assert _.isObject method.document ?= new Document
        assert method.document.descriptor = descriptor
        assert slate = method.document.blankSlate = ->
            assert document = new Document()
            document.descriptor = @descriptor
            document.blankSlate = @blankSlate
            return Object.create document
        return method.document
