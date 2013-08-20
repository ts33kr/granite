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

assert = require "assert"
logger = require "winston"
events = require "events"
colors = require "colors"
util = require "util"
url = require "url"

_ = require "lodash"
extendz = require "./extends"
routing = require "./routing"
scoping = require "./scoping"

# This is an abstract base class for every kind of service in this
# framework and the end user application. It provides the matching
# and processing logic based on domain matches and RE match/extract
# logics, to deal with paths. Remember that this service is just a
# an internal base class, you generally should not use it directly.
module.exports.Service = class Service extends events.EventEmitter

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    @abstract yes

    # Here follows a set of definitions that predefine the usual
    # suspects in establishing the matching patterns. Basically,
    # a number of convenient shorthands for wildcard patterns.
    # Use them when you need to wildcard or do a wide match.
    @INDEX = /^\/$/; @WILDCARD = /^.+$/

    # Every service has to have a public constructor that accepts
    # the kernel instance as a parameter. You can override it as
    # you see fit, but be sure to invoke the super constructor and
    # it is highly advised to store the kernel instance in object.
    constructor: (@kernel) -> super

    # Either obtain or set the HTTP location of the current service.
    # This method is a proxy that forwards the invocation to the
    # service constructor, for the purpose of easy access to service
    # location when programmatically operating on the instances. Do
    # refer to the original constructor method for more information.
    location: -> @constructor.location arguments...

    # Either obtain or set the HTTP location of the current service.
    # If not location has been set, but the one is requested then
    # the deduced default is returned. Default location is the first
    # resource regular expression pattern being unescaped to string.
    @location: (location) ->
        current = => @$location? or automatic
        automatic = _.head(@resources)?.unescape()
        return current() if arguments.length is 0
        isLocation = _.isString location
        noLocation = "The location is not a string"
        throw new Error noLocation unless isLocation
        @$location = location.toString(); this

    # This is a very basic method that adds the specified regular
    # expression pattern to the list of permitted resource patterns.
    # The patterns are associated with a service class, not object.
    # Supports implicit extraction of captured groups in the match.
    # Use this to configure what resources should match with service.
    @resource: (pattern) ->
        identify = (@nick or @name).underline
        duplicate = pattern in (@resources or [])
        regexify = (s) -> new RegExp "^#{RegExp.escape(s)}$"
        pattern = regexify pattern  if _.isString pattern
        inspected = pattern.unescape()?.underline or pattern.source
        associate = "Associating #{inspected} resource with #{identify}"
        notRegexp = "The #{inspected} is not a valid regular expression"
        throw new Error notRegexp unless _.isRegExp pattern
        (@resources ?= []).push pattern unless duplicate
        (logger.debug associate.grey unless duplicate); this

    # This is a very basic method that adds the specified regular
    # expression pattern to the list of permitted domain patterns.
    # The patterns are associated with a service class, not object.
    # Supports implicit extraction of captured groups in the match.
    # Use this to configure what domains should match with service.
    @domain: (pattern) ->
        identify = (@nick or @name).underline
        duplicate = pattern in (@domains or [])
        regexify = (s) -> new RegExp RegExp.escape(s)
        pattern = regexify(pattern)  if _.isString(pattern)
        inspected = pattern.unescape()?.underline or pattern.source
        associate = "Associating #{inspected} domain with #{identify}"
        notRegexp = "The #{inspected} is not a valid regular expression"
        throw new Error notRegexp unless _.isRegExp pattern
        (@domains ?= []).push pattern unless duplicate
        (logger.debug associate.grey unless duplicate); this

    # Unregister the current service instance from the kernel router.
    # You should call this method only after the service has been
    # previously registered with the kernel router. This method does
    # modify the router register, ergo does write access to kernel.
    unregister: ->
        identify = @constructor.identify()
        inspected = identify.toString().underline
        noKernel = "No kernel reference found"
        noRouter = "Could not access the router"
        unregister = "Removing %s service instance"
        throw new Error noKernel unless @kernel?
        registry = @kernel.router?.registry
        throw new Error noRouter unless registry?
        @emit "unregister", @kernel, @router
        logger.info unregister.yellow, inspected
        index = _.indexOf registry, this
        assert index >= 0, "never registered"
        registry.splice index, 1; this

    # This method determines whether the supplied HTTP request
    # matches this service. This is determined by examining the
    # domain/host and the path, in accordance with the patterns
    # that were used for configuring the class of this service.
    matches: (request, response, next) ->
        return no unless request.url?
        return no unless request.headers.host?
        domains = @constructor.domains or []
        resources = @constructor.resources or []
        pathname = url.parse(request.url).pathname
        hostname = _.first request.headers.host.split ":"
        pdomain = (pattern) -> pattern.test hostname
        presource = (pattern) -> pattern.test pathname
        domainOk = _.some domains, pdomain
        resourceOk = _.some resources, presource
        parameters = [request, response, next]
        matches = domainOk and resourceOk
        @emit "matches", matches, parameters...
        return domainOk and resourceOk

    # This method should process the already matched HTTP request.
    # But since this is an abstract base class, this implementation
    # only extracts the domain and pathname captured groups, and
    # returns them to the caller. Override it to do some real job.
    # The captured groups may be used by the overrider or ditched.
    process: (request, response, next) ->
        gdomain = null; gresource = null
        pathname = url.parse(request.url).pathname
        hostname = _.first request.headers.host.split ":"
        domains = @constructor.domains or []
        resources = @constructor.resources or []
        pdomain = (p) -> gdomain = hostname.match p
        presource = (p) -> gresource = pathname.match p
        pdomain = _.find domains, pdomain
        presource = _.find resources, presource
        assert gdomain isnt null, "missing domain"
        assert gresource isnt null, "missing resource"
        parameters = [request, response, next]
        @emit "process", gdomain, gresource, parameters...
        return domain: gdomain, resource: gresource
