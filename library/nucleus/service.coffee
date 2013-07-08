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
routing = require "./routing"
scoping = require "./scoping"

# This is an abstract base class for every kind of service in this
# framework and the end user application. It provides the matching
# and processing logic based on domain matches and RE match/extract
# logics, to deal with paths. Remember that this service is just a
# an internal base class, you generally should not use it directly.
module.exports.Service = class Service extends events.EventEmitter

    # Here follows a set of definitions that predefine the usual
    # suspects in establishing the matching patterns. Basically,
    # a number of convenient shorthands for wildcard patterns.
    # Use them when you need to wildcard or do a wide match.
    @EVERYWHERE = undefined; @INDEX = /^\/$/; @ANY = /^.+$/

    # Every service has to have a public constructor that accepts
    # the kernel instance as a parameter. You can override it as
    # you see fit, but be sure to invoke the super constructor and
    # it is highly advised to store the kernel instance in object.
    constructor: (@kernel) ->

    # This is a very basic method that adds the specified regular
    # expression pattern to the list of permitted resource patterns.
    # The patterns are associated with a service class, not object.
    # Supports implicit extraction of captured groups in the match.
    # Use this to configure what resources should match with service.
    @resource: (pattern) ->
        duplicate = pattern in (@resources or [])
        regexify = (s) -> new RegExp "^#{RegExp.escape(s)}$"
        pattern = regexify(pattern)  if _.isString(pattern)
        inspected = pattern.unescape()?.underline or pattern.source
        associate = "Associating #{inspected} resource with #{@name}"
        notRegexp = "The #{inspected} is not a valid regular expression"
        throw new Error(notRegexp) unless _.isRegExp(pattern)
        (@resources ?= []).push pattern unless duplicate
        (logger.debug(associate.cyan) unless duplicate); this

    # This is a very basic method that adds the specified regular
    # expression pattern to the list of permitted domain patterns.
    # The patterns are associated with a service class, not object.
    # Supports implicit extraction of captured groups in the match.
    # Use this to configure what domains should match with service.
    @domain: (pattern) ->
        duplicate = pattern in (@domains or [])
        regexify = (s) -> new RegExp(RegExp.escape(s))
        pattern = regexify(pattern)  if _.isString(pattern)
        inspected = pattern.unescape()?.underline or pattern.source
        associate = "Associating #{inspected} domain with #{@name}"
        notRegexp = "The #{inspected} is not a valid regular expression"
        throw new Error(notRegexp) unless _.isRegExp(pattern)
        (@domains ?= []).push pattern unless duplicate
        (logger.debug(associate.cyan) unless duplicate); this

    # Publish the current service class (not instance) to the slots
    # in the specified scopes. If the service already exist in some
    # of the specified scopes, it will not be added again. If scopes
    # are not specified, the service will be published everywhere.
    @publish: (scopes...) ->
        inspected = @nick or @name
        registry = scoping.Scope.REGISTRY or {}
        scopes = undefined if _.isEqual scopes, [undefined]
        exists = (scope) => this in (scope.services or [])
        p = (scope) => (scope.services ?= []).push this
        n = (scope) => logger.debug(notification, inspected, scope.tag)
        notification = "Publishing %s service to %s scope".grey
        scopes = _.values(registry) unless scopes?.length > 0
        (p(s); n(s)) for own i, s of scopes when not exists(s)

    # Unregister the current service instance from the kernel router.
    # You should call this method only after the service has been
    # previously registered with the kernel router. This method does
    # modify the router register, ergo does write access to kernel.
    unregister: ->
        nick = @constructor?.nick
        name = @constructor?.name
        noKernel = "No kernel reference found"
        noRouter = "Could not access the router"
        unregister = "Unregistering the %s service"
        throw new Error(noKernel) unless @kernel?
        registry = @kernel.router?.registry
        throw new Error(noRouter) unless registry?
        filtered = _.without(registry, this)
        @emit("unregister", @kernel, @router)
        logger.info(unregister.yellow, nick or name)
        @kernel.router.registry = filtered; this

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
        hostname = _.first(request.headers.host.split(":"))
        pdomain = (pattern) -> pattern.test(hostname)
        presource = (pattern) -> pattern.test(pathname)
        domainOk = _.some(domains, pdomain)
        resourceOk = _.some(resources, presource)
        parameters = [request, response, next]
        matches = domainOk and resourceOk
        @emit("matches", matches, parameters...)
        return domainOk and resourceOk

    # This method should process the already matched HTTP request.
    # But since this is an abstract base class, this implementation
    # only extracts the domain and pathname captured groups, and
    # returns them to the caller. Override it to do some real job.
    # The captured groups may be used by the overrider or ditched.
    process: (request, response, next) ->
        gdomain = null; gresource = null
        pathname = url.parse(request.url).pathname
        hostname = _.first(request.headers.host.split(":"))
        domains = @constructor.domains or []
        resources = @constructor.resources or []
        pdomain = (p) -> gdomain = hostname.match(p)
        presource = (p) -> gresource = pathname.match(p)
        pdomain = _.find(domains, pdomain)
        presource = _.find(resources, presource)
        assert(gdomain isnt null, "missing domain")
        assert(gresource isnt null, "missing resource")
        parameters = [request, response, next]
        @emit("process", gdomain, gresource, parameters...)
        return domain: gdomain, resource: gresource
