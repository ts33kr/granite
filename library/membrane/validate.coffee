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
asciify = require "asciify"
connect = require "connect"
logger = require "winston"
events = require "events"
colors = require "colors"
assert = require "assert"
async = require "async"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"
url = require "url"

{Primitive} = require "./primitive"
{Barebones} = require "./skeleton"

# This is an ABC service intended to be used only as a compund. It
# provides a complete validation solution for the framework. The
# important difference is this validation system supports asynchronous
# validators which is what differs it from existent solutions. This
# validation system is a one-stop-shop for checking all the inputs!
module.exports.Validator = class Validator extends Barebones

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    @abstract yes

    # Either get or set a class object that will be used as to create
    # new validation contexts. If this isnt configured per service
    # via this method - then the default `Context` class will be used
    # which inherits `Primitives` as a collection of the validators.
    # If you want to add validators - create and set context class.
    @validationContext: (context) ->
        invalid = "the #{context} is not a class"
        return @$vcontext if arguments.length is 0
        assert _.isObject(context?.__super__), invalid
        @$vcontext = context; return this

    # This method is a default implementation of the renderer that
    # will be called when the validation has failed. You can easily
    # override it in either your service or in an external compound.
    # By default it renders JSON object with errors mapped to params.
    renderValidation: (results, request, response) ->
        notRequest = "a #{request} is not a request"
        notResponse = "a #{response} is not a respnonse"
        assert _.isObject(response), notResponse
        assert _.isObject(request), notRequest
        message = (error) -> error.message
        strings = _.map results, message
        response.statusCode = 400
        map = _.object _.keys(results), strings
        return @push response, errors: params: map

    # Given the request with possible validation contexts appended
    # run all the validator contexsts in parallel and wait for the
    # completion. If no validation mistakes found, run continuation.
    # If some mistakes are found, however, run `@renderValidation`.
    continueWithValidation: (request, response, continuation) ->
        notRequest = "a #{request} is not a request"
        notResponse = "a #{response} is not a respnonse"
        notContinuation = "a #{continuation} is not function"
        transformer = (o) -> (c) -> o.run (e) -> c null, e
        assert _.isFunction(continuation), notContinuation
        assert _.isObject(response), notResponse
        assert _.isObject(request), notRequest
        vcontexts = request.vcontexts or {}
        transformed =  _.map _.values(vcontexts), transformer
        transformed = _.object _.keys(vcontexts), transformed
        async.parallel transformed, (error, results) =>
            assert not error, "internval valdation error"
            errors = _.any _.values(results), _.isObject
            hasRender = _.isFunction @renderValidation
            assert hasRender, "no method to render validation"
            params = [results, request, response, continuation]
            return @renderValidation params... if errors
            return continuation.bind(this)()

    # Create a validation context for the parameter designated by
    # the `name` and add it to the current request. If the `message`
    # is supplied then it will be forced as an error messages. Use
    # this method to automatically obtain contex for the parameter.
    check: (request, name, message) ->
        context = @constructor.validationContext?()
        context = Context unless _.isObject context
        assert request; value = request.params?[name]
        vcontexts = (request.vcontexts ?= {})
        return obtain if obtain = vcontexts[name]
        created = new context value, message
        vcontexts[name] = created; created

# A base class for all the validation contexts. Basically the conext
# encapsulates the necessary internal details as well as provides a
# set of validators to be used. So in order to create custom ones, you
# will need to create a descendant of this class and set is as context.
# The context setting happens on the servies level with the directive.
module.exports.Context = class Context extends Primitive

    # Create a new instance of the validation context with the given
    # value set as the subject for validation. Each validator will
    # refer to this value to perform their validation logic on it.
    # If the message arg is passed in then it will be used by force.
    constructor: (@value, @message) ->

    # Run the entire stack of chained validators. Once done, callback
    # will be called with an error parameter passed in. If any of the
    # validators in the chain has failed, then this parameter will have
    # an error object set in with an appropriate message about mistake.
    run: (callback) ->
        validators = @validators ?= []
        invalid = "inconsistent validators"
        assert _.isArray validators, invalid
        async.series validators, (error) =>
            failed = _.isObject error
            custom = _.isString @message
            matches = failed and custom
            error.message = @message if matches
            @emit "run", error
            callback error

    # Chain in a new validator to the context. Validator is a method
    # that will be called within this context that should look up the
    # value and see if it fits the validator logic and report either
    # an error, via standard async callback or pass on to the next one.
    chain: (validator) ->
        noFunction = "a #{validator} is not a function"
        wrongParams = "a validator should have 1 argument"
        assert _.isFunction(validator), noFunction
        assert validator.length is 1, wrongParams
        @emit "chain", validator, @validators
        (@validators ?= []).push validator
