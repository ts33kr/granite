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
util = require "util"
url = require "url"

_ = require "lodash"
extendz = require "./extends"
routing = require "./routing"
scoping = require "./scoping"

{format} = require "util"
{Archetype} = require "./archetype"
{urlOfServer} = require "./tools"
{urlOfMaster} = require "./tools"

# This is an abstract base class for every kind of service in this
# framework and the end user application. It provides the matching
# and processing logic based on domain matches and RE match/extract
# logics, to deal with paths. Remember that this service is just a
# an internal base class, you generally should not use it directly.
module.exports.Service = class Service extends Archetype

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # Every service has to have a public constructor that accepts
    # the kernel instance as a parameter. You can override it as
    # you see fit, but be sure to invoke the super constructor and
    # it is highly advised to store the kernel instance in object.
    # It is also taking care of assigning a service identification.
    constructor: (@kernel) -> super and @uuid = uuid.v4()

    # Either obtain or set the HTTP location of the current service.
    # This method is a proxy that forwards the invocation to the
    # service constructor, for the purpose of easy access to service
    # location when programmatically operating on the instances. Do
    # refer to the original constructor method for more information.
    location: -> @constructor.location arguments...

    # This method is a tool for obtaining a fully qualified path to
    # access to the resource, according to the HTTP specification.
    # This includes details such as host, port, path and alike. The
    # method knows how to disambiguate between SSL and non SSL paths.
    # Refer to the original constructor method for more information.
    qualified: -> @constructor.qualified arguments...

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

    # An important method whose responsibility is to create a new
    # instance of the service, which is later will be registered in
    # the router. This is invoked by the watcher when it discovers
    # new suitable services to register. This works asynchronously!
    @spawn: (kernel, callback) ->
        noKernel = "no kernel supplied is given"
        assert _.isObject(kernel or 0), noKernel
        assert _.isFunction lazy = try @lazy()
        do => lazy.call this, kernel, callback
        assert service = new this arguments...
        assert downstream = service.downstream
        downstream = try downstream.bind service
        assert instance = downstream instance: =>
            callback.call this, service, kernel
        instance kernel, service; return service

    # This method implements a clever little lazy initialize system
    # for the services. Basically, if you supply a fucntion to this
    # method invocation, it will save it as a lazy config function,
    # and execute it when the service is about to be spawned. But
    # if you don't supply anything - it returns an executor method
    # that will invoke all the lazy config functions in sequence.
    @lazy: (implement) ->
        apply = (s) => (method) => method.apply this, s
        execute = => _.each @$lazy or [], apply arguments
        assert id = try @identify().toString().underline
        m = "Executing lazy configuration for #{id}".grey
        return if this.lazyexc? and this.lazyexc is yes
        logger.debug m unless (arguments.length or 0) > 0
        @lazyexc = yes unless (arguments.length or 0) > 0
        return execute unless (arguments.length or 0) > 0
        executable = "please supply a valid lazy function"
        assert _.isFunction(implement or null), executable
        return @$lazy = (@$lazy or []).concat implement

    # This method provides a handy, convenient tool for obtainting a
    # stringified identificator tag (a reference) for a service class.
    # This tag is supposed to be something between machine and human
    # readable. Typically, this is a short hash function, such as an
    # MD5 hash represented (stringified) with HEX digesting mechanism.
    @reference: ->
        installed = _.isString @$reference
        return @$reference if installed is yes
        noOrigin = "#{identify()} has no origin"
        assert hasher = crypto.createHash "md5"
        assert location = @origin.id, noOrigin
        assert factor = "#{location}:#{@identify()}"
        digest = hasher.update(factor).digest "hex"
        assert digest; return @$reference = digest

    # This method is a tool for obtaining a fully qualified path to
    # access to the resource, according to the HTTP specification.
    # This includes details such as host, port, path and alike. The
    # method knows how to disambiguate between SSL and non SSL paths.
    # Do not confuse it with `location` method that deals locations.
    @qualified: (master=yes) ->
        int = "internal error getting qualified"
        noLocation = "the service has no location"
        securing = require "../membrane/securing"
        assert not _.isEmpty(@location()), noLocation
        isProtected = this.derives securing.OnlySsl
        sel = master and urlOfMaster or urlOfServer
        link = sel.call this, isProtected, @location()
        assert not _.isEmpty(link), int; return link

    # Either obtain or set the HTTP location of the current service.
    # If not location has been set, but the one is requested then
    # the deduced default is returned. Default location is the first
    # resource regular expression pattern being unescaped to string.
    # Do not confuse it with `qualified` method that deals with URL.
    @location: (location) ->
        current = => @$location or automatic
        automatic = _.head(@resources)?.unescape()
        return current() if arguments.length is 0
        isEmpty = "the location must not be empty"
        noLocation = "the location is not a string"
        assert _.isString(location), noLocation
        assert not _.isEmpty(location), isEmpty
        @$location = location.toString(); this

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
        logger.debug associate, inspected, identify
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
        logger.debug associate, inspected, identify
        return this # return itself for chaining...

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
        assert gdomain isnt null, "missing the domain"
        assert gresource isnt null, "missing resource"
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
