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
assert = require "assert"
asciify = require "asciify"
connect = require "connect"
logger = require "winston"
events = require "eventemitter2"
colors = require "colors"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"

{Barebones} = require "../membrane/skeleton"
{schema} = require "../membrane/schema"
{Api} = require "../nucleus/api"

# This service exposes the entiry hierarchical structure of the
# service documentation, as they scanned and found in the current
# kernel instance. It exposes the data in a structured hierarchy
# encoded with JSON. Please refer to the implementation for info.
module.exports.ApiDoc = class ApiDoc extends Barebones

    # These invocations establish the parameters which are going
    # to be used for matching HTTP requests against this service.
    # Typically an HTTP pathname pattern and a domain name pattern.
    # Try not to put constraints on the domain, unless necessary.
    # Also, the compounds for the composition system belong here.
    @resource "/api/doc"

    # Here follows the definition of the JSON schema that represents
    # some data structure used throughout the service of compound in
    # which it is constructed or referenced from. This construction
    # produces a usable, pure JSON Schema Draft v4. No further build
    # up is possible, as the returned object clean of utility members.
    @SERVICES = schema "#services", "schema for the API inventory", ->
        @unique @objects "a unique object that describes a service", ->
            location: @must -> @string "HTTP location of the service"
            identify: @must -> @string "human readable ID of the service"
            patterns: -> @strings "a regexp pattern that matches HTTP path"
            methods: -> @objects "an HTTP method supported by the service", ->
                method: @must -> @choose "an HTTP method (verb)", Api.SUPPORTED
                relevant: -> @string "a relevant link or refernce or pointer"
                synopsis: -> @string "a short summary of what the method does"
                outputs: -> @string "human readable of what method returns away"
                version: -> @string "human and machine readble version of method"
                inputs: -> @string "human readable of what method takes as input"
                leads: -> @string "a URL that leads to invocation of method"
                notes: -> @string "a human readable remarks about the method"
                produces: @strings "one of MIME types produced by the method"
                consumes: @strings "one of MIME types consumed by the method"
                schemas: -> @object "arbitrary JSON schemas for this method"
                argument: -> @objects "a descriptor of a method argument"
                failure: -> @objects "a descriptor of a possible failure"
                markings: -> @object "arbitrary labels to put on method"
                github: -> @objects "a reference to a file on GitHub"

    # Get the contents of the resources at the established path. It
    # is a good idea for this HTTP method to be idempotent. As the
    # rule, this method does not have to alter any contents or data
    # of the resource. Use for unobtrusive retrieval of resources.
    GET: (request, response) ->
        collected = @collectDescriptions()
        @push response, _.map collected, (record) ->
            constructor = record.service.constructor
            location: record.service.location()
            identify: constructor.identify()
            patterns: _.map constructor.resources, "source"
            methods: _.map record.methods, (document, method) ->
                relevant: document.relevant()
                markings: document.markings()
                argument: document.argument()
                synopsis: document.synopsis()
                produces: document.produces()
                consumes: document.consumes()
                version: document.version()
                failure: document.failure()
                outputs: document.outputs()
                schemas: document.schemas()
                inputs: document.inputs()
                github: document.github()
                notes: document.notes()
                leads: document.leads()
                method: method

    # This block describes certain method of abrbitrary service. The
    # exact process of how it is being documented depends on how the
    # documented function is implemented. Please refer to `Document`
    # class and its module implementation for more information on it.
    @GET (method, service, kernel) ->
        @relevant "ts33kr.github.io/granite/exposure/apidoc.html"
        @github "ts33kr", "granite", "library/exposure/apidoc.coffee"
        @synopsis "Get inventory of all APIs available in the system"
        @outputs "An array of objects, each describes a service"
        @markings framework: "critical", stable: "positive"
        @schemas exhaust: service.constructor.SERVICES
        @version kernel.package.version or undefined
        @produces "application/json"
