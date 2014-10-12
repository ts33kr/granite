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
uuid = require "node-uuid"
crypto = require "crypto"
colors = require "colors"
async = require "async"
nconf = require "nconf"
http = require "http"
weak = require "weak"
util = require "util"
url = require "url"

_ = require "lodash"
extendz = require "./extends"
routing = require "./routing"
scoping = require "./scoping"

{format} = require "util"
{Archetype} = require "./arche"
{urlOfServer} = require "./toolkit"
{urlOfMaster} = require "./toolkit"

# This is an abstract base class for every kind of service in this
# framework and the end user application. It provides the matching
# and processing logic based on domain matches and RE match/extract
# logics, to deal with paths. Remember that this service is just a
# an internal base class, you generally should not use it directly.
# Also, all of its functionality can be overriden by any service.
module.exports.Service = class Service extends Archetype

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # Symbol declaration table, that states what keys, if those are
    # vectors (arrays) should be exported and then merged with their
    # counterparts in the destination, once the composition process
    # takes place. See the `Archetype::composition` hook definition
    # for more information. Keys are names, values can be anything.
    @COMPOSITION_EXPORTS: configures: yes

    # A hook that will be called each time when the kernel beacon
    # is being fired. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    beacon: (kernel, timestamp, next) -> next()

    # A hook that will be called prior to instantiating the service
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    instance: (kernel, service, next) -> next()

    # A hook that will be called prior to registering the service
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    register: (kernel, router, next) -> next()

    # A hook that will be called prior to unregistering the service
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    unregister: (kernel, router, next) -> next()

    # A hook that will be called prior to firing up the processing
    # of the service. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    ignition: (request, response, next) -> next()

    # This instance method is a shortcut that internally makes use
    # of the service disposition data, obtained by call underlying
    # method `disposition` of the service class itself. The alias
    # exists primarily for the purpose of supporting some legacy
    # constructs defined well before the underlying method were.
    # For the new code, you should perhaps use `disposition`.
    reference: -> @constructor.disposition().reference

    # This instance method is a shortcut that internally makes use
    # of the service disposition data, obtained by call underlying
    # method `disposition` of the service class itself. The alias
    # exists primarily for the purpose of supporting some legacy
    # constructs defined well before the underlying method were.
    # For the new code, you should perhaps use `disposition`.
    location: -> @constructor.disposition().location

    # This instance method is a shortcut that internally makes use
    # of the service disposition data, obtained by call underlying
    # method `disposition` of the service class itself. The alias
    # exists primarily for the purpose of supporting some legacy
    # constructs defined well before the underlying method were.
    # For the new code, you should perhaps use `disposition`.
    qualified: -> @constructor.disposition().master

    # This is an instance method that will be invoked by the router
    # on every service, prior to actually registering it. Method is
    # intended to ask the service itself if wants and deems okay to
    # be registered with the current router and kernel. This sort of
    # functionality can be used to disambiguate what services should
    # be loaded at what environments and configuratin circumstances.
    consenting: (kernel, router, consent) -> consent yes

    # Every service has to have a public constructor that accepts
    # the kernel instance as a parameter. You can override it as
    # you see fit, but be sure to invoke the super constructor and
    # it is highly advised to store the kernel instance in object.
    # It is also taking care of assigning a service identification.
    constructor: (@kernel) -> super; @uuid = uuid.v4()

    # This is the proxy method that uses the global kernel instance
    # to use for finding the instance of the current service class.
    # This instance is supposed to be properly registered with the
    # router in order to be found. The actual lookup implementation
    # is located in the `accquire` method of `GraniteKernel` class.
    # Please refer to the original implementation for the guidance.
    @accquire: -> global.GRANITE_KERNEL.accquire this, yes

    # An important method whose responsibility is to create a new
    # instance of the service, which is later will be registered in
    # the router. This is invoked by the watcher when it discovers
    # new suitable services to register. This works asynchronously!
    # You need to take this into account, when overriding this one.
    @spawn: (kernel, callback, alloc) ->
        noKernel = "no kernel supplied or given"
        noFunc = "got no valid callback function"
        assert _.isObject(kernel or null), noKernel
        assert _.isFunction(callback or null), noFunc
        alloc ?= => new this kernel, callback, alloc
        assert (service = alloc()).objectOf this or 0
        assert downstream = try service.downstream or 0
        message = "Spawned a new instance of %s service"
        firings = "Downstream spawning sequences in %s"
        identify = try @identify().toString().underline
        logger.debug message.grey, identify.toString()
        exec = (fun) => fun kernel, service; service
        assert downstream = downstream.bind service
        return exec instance = downstream instance: =>
            this.configure().call service, (results) =>
                logger.debug firings.grey, identify
                callback.call this, service, kernel
                try service.emit "instance", kernel

    # This method is used to obtain all the available disposition
    # data of this services. Disposition data is basically the data
    # related to HTTP locations (supposedly) of the service using
    # the different variations. This also includes some of internal
    # referential data that does not pertain to HTTP per se. Please
    # refer to the method source code for the detailed information.
    @disposition: (forceSsl=no) ->
        securing = require "../membrane/securing"
        assert hasher = try crypto.createHash "md5"
        noAbsolute = "the service origin is missing"
        assert absolute = this.origin?.id, noAbsolute
        assert _.isString(noAbsolute), "invalid origin"
        assert _.isString identify = try this.identify()
        assert factor = "#{absolute}:#{identify}" or 0
        onlySsl = @derives securing.OnlySsl or forceSsl
        digest = try hasher.update(factor).digest "hex"
        deduce = try _.head(this.resources)?.unescape()
        assert not _.isEmpty(digest), "MD5 digest fail"
        assert $reference = digest or this.reference?()
        assert internal = "/#{$reference}/#{identify}"
        $location = deduce or @location?() or internal
        $location = internal unless $location or null
        $server = try urlOfServer onlySsl, $location
        $master = try urlOfMaster onlySsl, $location
        return new Object # make and return summary
            reference: $reference or null # MD5-ed
            location: $location or null # relative
            server: $server or null # server URL
            master: $master or null # master URL

    # This method should process the already matched HTTP request.
    # But since this is an abstract base class, this implementation
    # only extracts the domain and pathname captured groups, and
    # returns them to the caller. Override it to do some real job.
    # The captured groups may be used by the overrider or ditched.
    process: (request, response, next) ->
        gdomain = null; gresource = null # var holders
        assert resources = @constructor.resources or []
        assert domains = @constructor.domains or [/^.+$/]
        assert pathname = url.parse(request.url).pathname
        assert identify = @constructor.identify().underline
        hostname = try _.head request.headers.host.split ":"
        assert not _.isEmpty hostname, "missing hostname"
        pdomain = (repat) -> gdomain = hostname.match repat
        presource = (repat) -> gresource = pathname.match repat
        xdomain = try _.find(domains, pdomain) or null # side
        xresource = _.find(resources, presource) or null # side
        message = "Begin service processing sequence in %s"
        logger.debug message.toString().yellow, identify
        assert _.isObject request.service = try weak this
        assert request.domains = gdomain, "missing domain"
        assert request.resources = gresource, "no resource"
        @emit "process", gdomain, gresource, arguments...
        return domain: gdomain, resource: gresource

    # This method determines whether the supplied HTTP request
    # matches this service. This is determined by examining the
    # domain/host and the path, in accordance with the patterns
    # that were used for configuring the class of this service.
    # It is async, so be sure to call the `decide` with boolean!
    matches: (request, response, decide) ->
        assert resources = @constructor.resources or []
        assert domains = @constructor.domains or [/^.+$/]
        assert pathname = url.parse(request.url).pathname
        assert identify = @constructor.identify().underline
        hostname = try _.head request.headers.host.split ":"
        assert not _.isEmpty hostname, "missing hostname"
        pdomain = (pattern) -> try pattern.test hostname
        presource = (pattern) -> try pattern.test pathname
        message = "Polling %s service for a basic match"
        logger.debug message.toString().yellow, identify
        domainOk = try _.some(domains, pdomain) or false
        resourceOk = _.some(resources, presource) or false
        matches = domainOk is yes and resourceOk is yes
        this.emit "matches", matches, request, response
        return decide domainOk and resourceOk

    # This method handles the rescuing of the request/response pair
    # when some error happens during the processing of the request
    # under this service. This method is able to to deliver content
    # as the response if it is desirable. If not, the request will
    # simply be reject with Node.js/Connect. Beware about `next`!
    rescuing: (error, request, response, next) ->
        assert plain = try @constructor.identify()
        assert expose = "failures:exposeExceptions"
        assert not _.isEmpty method = request.method
        identify = @constructor.identify().underline
        template = "Exception in a #{method} at %s: %s"
        logger.error template.red, identify, error.stack
        @emit "failure", this, error, request, response
        message = "Executed error rescue handler in %s"
        logger.debug message.red, identify.toString()
        return next() unless nconf.get(expose) is yes
        response.setHeader "Content-Type", "text/plain"
        response.writeHead 500, http.STATUS_CODES[500]
        render = format template, plain, error.stack
        response.end render; return next undefined

    # This is a very basic method that adds the specified regular
    # expression pattern to the list of permitted resource patterns.
    # The patterns are associated with a service class, not object.
    # Supports implicit extraction of captured groups in the match.
    # Use this to configure what resources should match with service.
    @resource: (pattern) ->
        associate = "Associating %s resource with %s"
        identify = @identify().underline.toString()
        r = (s) -> new RegExp "^#{RegExp.escape(s)}$"
        pattern = try r pattern if _.isString pattern
        inspected = try pattern.unescape()?.underline
        inspected = pattern unless _.isString inspected
        source = not _.isEmpty try pattern.source or null
        notReg = "the #{inspected} is not a valid regexp"
        assert _.isRegExp(pattern) and source or 0, notReg
        assert @resources = (@resources or []).concat pattern
        assert @resources = _.unique this.resources or []
        logger.silly associate, inspected, identify
        return this # return itself for chaining...

    # This is a very basic method that adds the specified regular
    # expression pattern to the list of permitted domain patterns.
    # The patterns are associated with a service class, not object.
    # Supports implicit extraction of captured groups in the match.
    # Use this to configure what domains should match with service.
    @domain: (pattern) ->
        associate = "Associating %s domain with %s"
        identify = @identify().underline.toString()
        r = (s) -> new RegExp "^#{RegExp.escape(s)}$"
        pattern = try r pattern if _.isString pattern
        inspected = try pattern.unescape()?.underline
        inspected = pattern unless _.isString inspected
        source = not _.isEmpty try pattern.source or null
        notReg = "the #{inspected} is not a valid regexp"
        assert _.isRegExp(pattern) and source or 0, notReg
        assert @domains = (@domains or []).concat pattern
        assert @domains = _.unique this.domains or []
        logger.silly associate, inspected, identify
        return this # return itself for chaining...
