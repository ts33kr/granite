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
filesize = require "filesize"
asciify = require "asciify"
connect = require "connect"
request = require "request"
logger = require "winston"
colors = require "colors"
async = require "async"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"

{CachingToolkit} = require "./caching"
{OnlySsl} = require "../membrane/securing"
{GraniteKernel} = require "../nucleus/kernel"
{Barebones} = require "../membrane/skeleton"
{ApiService} = require "../membrane/api"

# This is an API service shipped out-of-the-box with the framework.
# It is intended for serving the JSON inventory of the all available
# API services in the application. Services can be confidured to be
# hidden from the inventory. Also, the inventory service itself can
# be entirely disabled using the configuration system. Please refer
# to this service implementation source code for more information.
module.exports.ApiInventory = class ApiInventory extends ApiService

    # These declarations below are implantations of the abstracted
    # components by the means of the dynamic recomposition system.
    # Please take a look at the `Composition` class implementation
    # for all sorts of information on the composition system itself.
    # Each of these will be dynamicall integrated in class hierarchy.
    @implanting CachingToolkit

    # Impose a conditional limitation on the service. The limiation
    # will be invoked when a router is determining whether a service
    # matches the condition or not. The limitation has to either do
    # accept or decline. Do this by calling `decide` with a boolean!
    # Especially useful for service with the same resource but with
    # different conditions, such as mobile only and desktop only.
    @condition (r, s, decide) -> decide nconf.get "api:inventory"

    # A decorator strategy for wrapping the API endpoint function
    # with an LRU (least-recently-used) type of cache that normally
    # uses the `request.url` as its key. This given cache strategy
    # is highly dependent on the usage of the `response.send` func
    # in order for the cache to work. Please see `plumbs` module
    # for more info on that. Also, depends on the spin off engine.
    # Please see the `lru-cache` package for more relevant info.
    @cached: @memoryCache 25, 1000 * 60 * 60 # TTL, milliseconds

    # Define an API endpoint in the current API service. Endpoint
    # is declared using the class directives with the name of one
    # of the valid HTTP verbs. The directive can be upper & lower
    # cased with no difference. Please see `RestfulService` class
    # for more information on verbs, especially `SUPPORTED` const.
    # Also, take a look at `ApiService` for advanced definitions.
    @docs follow: "http://ts33kr.github.io/granite/exposure/inventory.html"
    @docs github: ["ts33kr", "granite", "library/exposure/inventory.coffee"]
    @docs returns: "A JSON array, where each item is an API endpoint object"
    @docs synopsis: "Entire JSON inventory of all API services in the system"
    @docs sidenote: "The responses are cached using request URL as the keys"
    @docs version: GraniteKernel.FRAMEWORK.version, mime: "application/json"
    @docs markings: ["framework", "api", "inventory", "discovery", "tool"]
    @argv uid: "Optional UUID to query the specific API endpoint"
    @rule uid: /^[\w-]{36}$/ # an optional UUID v.1 identifier
    @get "/api/inventory/:uid:", @guard @cached (scoped) ->
        identify = try @constructor.identify().underline
        assert _.isObject Asc = ApiService # a shorthand
        malfReg = "the routing registry seems is broken"
        noKernRout = "failed to obtain the kernel router"
        message = "Building entire API inventory in %s"
        pub = (sv) => not sv.constructor.HIDE_INVENTORY
        predicate = (sv) => sv.objectOf(Asc) and pub(sv)
        logger.debug message.toString().magenta, identify
        assert router = (try @kernel.router), noKernRout
        assert registry = (try router.registry), malfReg
        assert apis = _.filter(registry, predicate) or []
        assert defs = (a.constructor.api() for a in apis)
        assert defs = _.flatten _.cloneDeep(defs or [])
        delete def.rules for def in defs when def.rules
        fetcher = (v) -> (v.length > 1 and v) or _.head v
        m = (a, v) -> (a[i] ?= []).push j for i, j of v; a
        assert reduce = (ds) -> _.reduce ds, m, Object()
        assert flattn = (ds) -> _.mapValues ds, fetcher
        d.documents = reduce d.documents for d in defs
        d.documents = flattn d.documents for d in defs
        return this.response.send defs unless scoped
        this.response.send _.find defs, uid: scoped
