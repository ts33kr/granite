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
api = require "../gearing/api"
service = require "../gearing/service"
document = require "../gearing/document"

# This service exposes the entiry hierarchical structure of the
# service documentation, as they scanned and found in the current
# kernel instance. It exposes the data in a structured hierarchy
# encoded with JSON. Please refer to the implementation for info.
module.exports.ApiDoc = class ApiDoc extends api.Stub

    # These invocations establish the parameters which are going
    # to be used for matching HTTP requests against this service.
    # Typically an HTTP pathname pattern and a domain name pattern.
    # Try not to put constraints on the domain, unless necessary.
    @resource "/api/doc"
    @domain @ANY

    # Get the contents of the resources at the established path. It
    # is a good idea for this HTTP method to be idempotent. As the
    # rule, this method does not have to alter any contents or data
    # of the resource. Use for unobtrusive retrieval of resources.
    GET: (request, response) ->
        collected = document.collect @kernel
        response.send _.map collected, (record) ->
            constructor = record.service.constructor
            title: constructor.nick or constructor.name
            pathname: _.head(constructor.resources)?.unescape()
            patterns: _.map constructor.resources, "source"
            methods: _.map record.methods, (doc, method) ->
                exmaple: doc.example()
                argument: doc.argument()
                synopsis: doc.synopsis()
                results: doc.results()
                inputs: doc.inputs()
                method: method

    # This block describes certain method a abrbitrary service. The
    # exact process of how it is being documented depends on how the
    # documented function is implemented. Please refer to `Document`
    # class and its module implementation for more information on it.
    document.describe @::GET, ->
        @synopsis "Get all of the APIs in the system"
        @results "An array of objects, each describes services"
