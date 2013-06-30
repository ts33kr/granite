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

_ = require "underscore"
logger = require "winston"
colors = require "colors"
util = require "util"
url = require "url"

# This is an abstract base class for every kind of service in this
# framework and the end user application. It provides the matching
# and processing logic based on domain matches and RE match/extract
# logics, to deal with paths. Remember that this service is just a
# an internal base class, you generally should not use it directly.
module.exports.Service = class Service extends Object

    # Here follows a set of definitions that predefine the usual
    # suspects in establishing the matching patterns. Basically,
    # a number of convenient shorthands for wildcard patterns.
    # Use them when you need to wildcard or do a wide match.
    @ANY = /^.+$/
    @ROOT = "^/$"

    # This method determines whether the supplied HTTP request
    # matches this service. This is determined by examining the
    # domain/host and the path, in accordance with the patterns
    # that were used for configuring the class of this service.
    matches: (request, response, next) ->
        return no unless request.headers.url?
        return no unless request.headers.host?
        domains = @constructor.domains or []
        resources = @constructor.resources or []
        pathname = url.parse(request.url).pathname
        hostname = _.first(request.headers.host.split(":"))
        pdomain = (pattern) -> pattern.test(hostname)
        presource = (pattern) -> pattern.test(pathname)
        domainOk = _.some(domains, pdomain)
        resourceOk = _.some(resources, presource)
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
        assert.ok(gdomain isnt null, "missing domain")
        assert.ok(gresource isnt null, "missing resource")
        return domain: gdomain, resource: gresource

    # This is a very basic method that adds the specified regular
    # expression pattern to the list of permitted resource patterns.
    # The patterns are associated with a service class, not object.
    # Supports implicit extraction of captured groups in the match.
    # Use this to configure what resources should match with service.
    @resource: (pattern) ->
        current = util.inspect(this)
        inspected = util.inspect(pattern)
        notRegexp = "The #{inspected} is not a valid regular expression"
        throw new Error(notRegexp) unless _.isRegExp(pattern)
        logger.info("Associating #{inspected} resource with #{current}".cyan)
        (@resources ?= []) push pattern unless pattern in @resources
        return this

    # This is a very basic method that adds the specified regular
    # expression pattern to the list of permitted domain patterns.
    # The patterns are associated with a service class, not object.
    # Supports implicit extraction of captured groups in the match.
    # Use this to configure what domains should match with service.
    @domain: (pattern) ->
        current = util.inspect(this)
        inspected = util.inspect(pattern)
        notRegexp = "The #{inspected} is not a valid regular expression"
        throw new Error(notRegexp) unless _.isRegExp(pattern)
        logger.info("Associating #{inspected} domain with #{current}".cyan)
        (@domains ?= []) push pattern unless pattern in @domains
        return this
