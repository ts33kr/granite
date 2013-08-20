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
logger = require "winston"
events = require "events"
colors = require "colors"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"

_ = require "lodash"
api = require "../nucleus/api"
stubs = require "../nucleus/stubs"
tools = require "../nucleus/tools"
service = require "../nucleus/service"
document = require "./document"
skeleton = require "./skeleton"

# This service exposes the entiry hierarchical structure of the
# service documentation, as they scanned and found in the current
# kernel instance. It exposes the data in a structured hierarchy
# encoded with JSON. Please refer to the implementation for info.
module.exports.ApiDoc = class ApiDoc extends skeleton.Standard

    # These invocations establish the parameters which are going
    # to be used for matching HTTP requests against this service.
    # Typically an HTTP pathname pattern and a domain name pattern.
    # Try not to put constraints on the domain, unless necessary.
    # Also, the compounds for the composition system belong here.
    @resource "/api/doc"
    @domain @WILDCARD

    # Get the contents of the resources at the established path. It
    # is a good idea for this HTTP method to be idempotent. As the
    # rule, this method does not have to alter any contents or data
    # of the resource. Use for unobtrusive retrieval of resources.
    GET: (request, response) ->
        collected = @collectSpecifications()
        @push response, _.map collected, (record) ->
            constructor = record.service.constructor
            location: record.service.location()
            identify: constructor.nick or constructor.name
            patterns: _.map constructor.resources, "source"
            methods: _.map record.methods, (doc, method) ->
                notes: doc.notes()
                leads: doc.leads()
                failure: doc.failure()
                argument: doc.argument()
                synopsis: doc.synopsis()
                outputs: doc.outputs()
                inputs: doc.inputs()
                method: method

    # This block describes certain method of abrbitrary service. The
    # exact process of how it is being documented depends on how the
    # documented function is implemented. Please refer to `Document`
    # class and its module implementation for more information on it.
    @specification @prototype.GET, (method, service) ->
        @leads tools.urlWithHost no, service.location()
        @notes "See the Document class for more information"
        @synopsis "Get all of the APIs available in the system"
        @outputs "An array of objects, each describes a service"
