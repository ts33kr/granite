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
events = require "events"
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
service = require "../nucleus/service"
extendz = require "./../nucleus/extends"
{Document} = require "../nucleus/document"

# This is an abstract base class API stub service. Its purpose is
# providing the boilerplate for documentation and speicification of
# the services using the built it documentation mechanisn. This class
# provide not only function for definition but also for retrieval of
# the documentation on either the per-service or all-at-once basis.
module.exports.Specification = class Specification extends stubs.WithHooks

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    @abstract yes

    # Describe the supplied method of arbitrary service, in a structured
    # and expected way, so that it can later be used to programmatically
    # process such documentation and do with it whatever is necessary.
    # This approach gives unique ability to build self documented APIs.
    @specification: (method, descriptor) ->
        validated = _.isFunction descriptor
        missing = "The #{descriptor} is not a descriptor"
        throw new Error missing unless validated
        method.document ?= new Document
        previous = method.document.descriptor
        method.document.descriptor = ->
            ok = _.isFunction previous
            previous.apply @, arguments if ok
            descriptor.apply @, arguments

    # Traverse all of the services that are registered with the router
    # and collect the documentation for each method, then given this
    # information, build a hierarhical tree object of all the methods
    # and the services that implement them and return to the invoker.
    collectSpecifications: (substitution) ->
        services = @kernel?.router?.registry
        services = substitution if substitution?
        assert _.isArray(services), "no services"
        logger.debug "Collecting API documentation"
        _.map services, (service) -> do (service) ->
            constructor = service.constructor
            supported = constructor.SUPPORTED
            unsupported = service.unsupported
            implemented = (m) -> service[m] isnt unsupported
            doc = (m) -> service[m].document or new Document
            filtered = _.filter supported, implemented
            methods = _.object filtered, _.map(filtered, doc)
            args = (method) -> [method, service, @kernel]
            doc.descriptor? args(m)... for m, doc of methods
            service: service, methods: methods
