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
logger = require "winston"
crossroads = require "crossroads"
uuid = require "node-uuid"
assert = require "assert"
colors = require "colors"
crypto = require "crypto"
nconf = require "nconf"
async = require "async"
https = require "https"
http = require "http"
util = require "util"
url = require "url"

{EOL} = require "os"
{format} = require "util"
{STATUS_CODES} = require "http"
{Barebones} = require "./skeleton"
{remote, external} = require "./remote"

# This is an abstract base class for creating services that expose
# their functionality as API. The general structure of API is a REST.
# Although it is not strictly limited by this ABC, and anything within
# the HTTP architecture is basically allowed and can be implemented.
# The ABC provides not only the tool set for API definition, but also
# an additional tool set for supplementing the APIs with documentation.
assert module.exports.ApiService = class ApiService extends Barebones

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
    @COMPOSITION_EXPORTS = definitions: yes

    # Walk over list of supported HTTP methods/verbs, defined in
    # the `RestfulService` abstract base class member `SUPPORTED`
    # and create a shorthand route definition for an every method.
    # These shorthand definitions will greatly simplify making new
    # routes, since they are much shorter than using a full blown
    # signature of the `define` method in this abstract base class.
    (do (m) => @[m] = -> @api m, arguments...) for m in @SUPPORTED
    (assert (this[m.toLowerCase()] = this[m])) for m in @SUPPORTED

    # Process the already macted HTTP request according to the REST
    # specification. That is, see if the request method conforms to
    # to the RFC, and if so, dispatch it onto corresponding method
    # defined in the subclass of this abstract base class. Default
    # implementation of each method will throw a not implemented.
    # This implementation executes the processing sequence of the
    # HTTP request with regards to the Crossroads of the service.
    process: @spinoff (request, response, next) ->
        assert identify = try @constructor.identify()
        assert this.__isolated, "spin-off engine fail"
        variables = [undefined, undefined] # no token
        headers = @downstream headers: -> return null
        partial = _.partial headers, request, response
        response.on "header", -> partial variables...
        assert mw = @constructor.middleware().bind this
        signature = [request, response, variables...]
        message = "Executing Crossroads routing in %s"
        intake = (func) => @downstream processing: func
        go = (fn) => usp = intake fn; usp signature...
        go => mw(signature) (error, results, misc) =>
            assert expanded = _.clone variables or []
            expanded.push request.session or undefined
            malfunction = "no crossroads in an instance"
            path = url.parse(request.url).pathname or 0
            assert _.isObject(@crossroads), malfunction
            assert _.isString(path), "no request paths"
            assert copy = Object.create String.prototype
            assert _.isFunction(copy.toString = -> path)
            assert copy.method = request.method or null
            logger.debug message.green, identify or 0
            return this.crossroads.parse copy, [this]

    # This method determines whether the supplied HTTP request
    # matches this service. This is determined by examining the
    # domain/host and the path, in accordance with the patterns
    # that were used for configuring the class of this service.
    # It is async, so be sure to call the `decide` with boolean!
    # This implementation checks whether an HTTP request matches
    # at least one router in the Crossroads instance of service.
    matches: (request, response, decide) ->
        assert _.isObject(request), "got invalid request"
        assert _.isFunction(decide), "incorrect callback"
        conditions = try @constructor.condition() or null
        conditions = Array() unless _.isArray conditions
        identify = try @constructor?.identify().underline
        return decide no if @constructor.DISABLE_SERVICE
        p = (i, cn) -> i.limitation request, response, cn
        fails = "Service #{identify} fails some conditions"
        notify = "Running %s service conditional sequences"
        message = "Polling %s service for Crossroads match"
        logger.debug notify.toString(), identify.toString()
        logger.debug message.toString().cyan, identify
        return async.every conditions, p, (confirms) =>
            logger.debug fails.yellow unless confirms
            return decide false unless confirms is yes
            malfunction = "no crossroads in an instance"
            path = url.parse(request.url).pathname or 0
            assert _.isObject(@crossroads), malfunction
            assert _.isString(path), "no request paths"
            assert copy = Object.create String.prototype
            assert _.isFunction(copy.toString = -> path)
            assert copy.method = request.method or null
            match = (route) -> return route.match copy
            decide _.any(@crossroads._routes, match)

    # A hook that will be called prior to registering the service
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    # This implementation sets up the internals of the API service
    # that will allow to properly expose and execute the methods.
    register: (kernel, router, next) ->
        noted = "Setting up %s Crossroads routes in %s"
        invalidDefs = "invalid type of the definitions"
        emptyDoc = "the document sequence is not emptied"
        noCrossr = "unable to load a Crossroads library"
        noInh = "cannot be inherited from both toolkits"
        createRouteWrapper = @createRouteWrapper.bind this
        try identify = @constructor.identify().underline
        assert not (try this.objectOf Screenplay), noInh
        assert crs = @crossroads = crossroads.create()
        defines = @constructor.define() or new Array()
        assert _.isArray(defines or null), invalidDefs
        assert _.isEmpty(@constructor.doc()), emptyDoc
        assert _.isObject(@crossroads or 0), noCrossr
        assert amount = defines.length.toString().bold
        try logger.debug noted.yellow, amount, identify
        async.each defines, createRouteWrapper, next

    # Part of the internal implementation of the API engine. It
    # is used to create the wrapping around the Crossroads route
    # handler. This wrapping is very tightly inegrated with this
    # abstract base class internals, as well as with the internal
    # design of some of the parent classes, namely `RestfulService`.
    # The wrapping provides important boilerplate to set up scope.
    createRouteWrapper: (definition, next) ->
        register = "Adding Crossroads route %s to %s"
        noCross = "no Crossroads router in the service"
        assert _.isObject(crs = @crossroads), noCross
        identify = @constructor.identify().underline
        assert method = try definition.method or null
        assert implement = definition.implement or 0
        assert rules = rls = definition.rules or {}
        assert not _.isEmpty mask = definition.mask
        assert p = (mask.source or mask).underline
        logger.debug register.magenta, p, identify
        fr = (q) => q.method.toUpperCase() is method
        rx = (r) => r.rules = rls; rls.request_ = fr
        fx = (f) => rx crs.addRoute mask, f; next()
        fx (shadow, parameters...) -> # the wrapper
            assert (shadow.__isolated or 0) is yes
            assert _.isObject shadow.__origin or 0
            implement.apply shadow, parameters

    # Class directive that sets the specified documentations in
    # the documentation sequence that will be used & emptied when
    # a API method is defined below. That is, this method operates
    # in a sequential mode. The documentation to is supplied to
    # this method as an object argument with arbitrary key/value
    # pairs, where keys is doc name and value is the doc itself.
    # Multiple docs with the same key name may exist just fine.
    this.document = this.docs = this.doc = (xsignature) ->
        noSignature = "please, supply a plain object"
        noDocuments = "cannot find the documents seq"
        internal = "an anomaly found in doc sequence"
        malfuncs = "derived from the incorrect source"
        message = "Setting an API documentation in %s"
        @documents ?= new Array() # document sequence
        assert previous = this.documents or new Array
        assert _.all(previous, _.isObject), internal
        return previous unless arguments.length > 0
        signature = _.find arguments, _.isPlainObject
        assert _.isPlainObject(signature), noSignature
        assert _.isArray(this.documents), noDocuments
        assert (try @derives(ApiService)), malfuncs
        assert identify = this.identify().underline
        logger.debug message.yellow, identify.bold
        fn = (arbitraryVector) -> return signature
        fn @documents = previous.concat signature

    # Class directive that sets the specified Crossroads rule in
    # a Crossroads rules sequence that will be used * emptied when
    # a API method is defined below. That is, this method operates
    # in a sequential mode. The Crossroads rule gets supplied to
    # this method as an object argument with arbitrary key/value
    # pairs, where keys is rule name and value is a rule itself.
    # Rules are attached to the route defined right after rules.
    this.crossroadsRule = this.rule = (xsignature) ->
        noSignature = "please, supply a plain object"
        noCrossRules = "cannot find a cross-rules seq"
        internal = "an anomaly found in doc sequence"
        malfuncs = "derived from the incorrect source"
        message = "Setting the Crossroads rule in %s"
        @crossRules ?= new Array() # cross-rules seqs
        assert previous = this.crossRules or Array()
        assert _.all(previous, _.isObject), internal
        return previous unless arguments.length > 0
        signature = _.find arguments, _.isPlainObject
        assert _.isPlainObject(signature), noSignature
        assert _.isArray(this.crossRules), noCrossRules
        assert (try @derives(ApiService)), malfuncs
        assert identify = this.identify().underline
        logger.debug message.yellow, identify.bold
        fn = (arbitraryVector) -> return signature
        fn @crossRules = previous.concat signature

    # Define a new API and all of its attributes. Among those
    # arguments there is an API implementation function and an
    # URL mask for routing that API and an HTTP version to use
    # for matching this API. Please consult with a `Crossroads`
    # package for information on the mask, which can be string
    # or a regular expression. Also, please see implementation.
    this.define = this.api = (method, mask, implement) ->
        wrongMask = "a mask has to be string or regex"
        noImplement = "no implementation fn supplied"
        invalidMeth = "an HTTP method is not a string"
        maskStr = _.isString(mask or null) or false
        maskReg = _.isRegExp(mask or null) or false
        assert previous = @definitions or new Array()
        return previous unless arguments.length > 0
        assert _.isFunction(implement), noImplement
        assert _.isString(method or 0), invalidMeth
        assert (maskStr or maskReg or 0), wrongMask
        documents = _.clone this.documents or Array()
        crossRules = _.reduce @crossRules, _.merge
        delete @documents if @documents # clear doc
        delete @crossRules if @crossRules # rm rule
        documents.push method: method.toUpperCase()
        documents.push mask: (mask?.source or mask)
        documents.push uid: uid = uuid.v1() or null
        fn = (arbitraryVector) -> return implement
        return fn @definitions = previous.concat
            documents: documents # documentation
            implement: implement # implements fn
            rules: crossRules # Crossroads rules
            method: method.toUpperCase() # HTTP
            mask: mask # URL mask for routing
            uid: uid # unique ID (UUID) tag
