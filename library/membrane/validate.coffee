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
events = require "eventemitter2"
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

# This is an ABC service intended to be used only as a compound. It
# provides the internal abstractions that are necessary for validators.
# This class is not a complete implementation, it just servres as the
# boilerplate for the actual validators implementation. Those actually
# follow below, please refer to each one for more specific information.
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
        return @$vcontext if arguments.length is 0
        noContext = "the #{context} is not a class"
        assert _.isObject(context?.__super__), noContext
        noRun = "the #{context} has no valid run method"
        noChain = "the #{context} has no valid chain method"
        assert _.isFunction(context.prototype.run), noRun
        assert _.isFunction(context.prototype.chain), noChain
        @$vcontext = context; return this

    # Given the storage with possible validation contexts appended
    # run all the validator contexts in parallel and wait for the
    # completion. Once the validation has been completed, call the
    # continuation routine and pass the validation results to it.
    # Continuation will recieve error indicator and results params.
    validateValues: (storage, continuation) ->
        notStorage = "a #{storage} is not a storage"
        notContinuation = "a #{continuation} is not function"
        transformer = (o) -> (c) -> o.run (e) -> c null, e
        assert _.isFunction(continuation), notContinuation
        assert _.isObject(storage), notStorage
        vcontexts = storage.__vcontexts__ or {}
        transformed =  _.map _.values(vcontexts), transformer
        transformed = _.object _.keys(vcontexts), transformed
        async.parallel transformed, (error, results) =>
            assert not error, "internal valdation error"
            errors = _.any _.values(results), _.isObject
            return continuation.bind(this) errors, results

    # Create new validation context for the values designated by
    # the `name` and add it to the supplied storage. If the `message`
    # is supplied then it will be forced as an error messages. Use
    # this method to automatically obtain contex for the parameter.
    # This variation of method is intended to work on any storage.
    value: (storage, name, message) ->
        assert _.notEmpty(name), "invalid name"
        context = @constructor.validationContext?()
        context = Primitive unless _.isObject context
        assert storage; value = storage[name]
        vcontexts = storage.__vcontexts__ ?= {}
        return obtain if obtain = vcontexts[name]
        created = new context value, message
        vcontexts[name] = created; created

# This is an ABC service intended to be used only as a compund. It
# provides a complete validation solution for request parameters. The
# important difference is this validation system supports asynchronous
# validators which is what differs it from existent solutions. This
# validation system is a one-stop-shop for checking all the inputs!
module.exports.RValidator = class RValidator extends Validator

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    @abstract yes

    # Create a validation context for the parameter designated by
    # the `name` and add it to the current request. If the `message`
    # is supplied then it will be forced as an error messages. Use
    # this method to automatically obtain contex for the parameter.
    param: (request, name, message) ->
        notParams = "the request has no params"
        notRequest = "a #{request} is not a request"
        assert _.isObject(request), notRequest
        assert params = request.params, notParams
        return @value params, name, message

    # This method is a default implementation of the renderer that
    # will be called when the validation has failed. You can easily
    # override it in either your service or in an external compound.
    # By default it renders JSON object with errors mapped to params.
    renderParamValidation: (results, request, response) ->
        notRequest = "a #{request} is not a request"
        notResponse = "a #{response} is not a respnonse"
        assert _.isObject(response), notResponse
        assert _.isObject(request), notRequest
        response.statusCode = 400 # bad parameters
        strings = _.map results, (e) -> e.message
        map = _.object _.keys(results), strings
        return @reject response, params: map

    # Given the request with possible validation contexts appended
    # run all the validator contexts in parallel and wait for the
    # completion. If no validation mistakes found, run continuation.
    # If some mistakes are found, however, `@renderParamValidation`.
    validateParameters: (request, response, continuation) ->
        notRequest = "a #{request} is not a request"
        notResponse = "a #{response} is not a response"
        notContinuation = "a #{continuation} is not function"
        assert _.isFunction(continuation), notContinuation
        assert _.isObject(response), notResponse
        assert _.isObject(request), notRequest
        @validateValues request.params, (error, results) ->
            signature = [results, request, response, continuation]
            return @renderParamValidation signature... if error
            return continuation.bind(this) results

# This is an ABC service intended to be used only as a compund. It
# provides a complete validation solution for request headers. The
# important difference is this validation system supports asynchronous
# validators which is what differs it from existent solutions. This
# validation system is a one-stop-shop for checking all the inputs!
module.exports.HValidator = class HValidator extends Validator

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    @abstract yes

    # Create a validation context for request header designated by
    # the `name` and add it to the current request. If the `message`
    # is supplied then it will be forced as an error messages. Use
    # this method to automatically obtain contex for the parameter.
    header: (request, name, message) ->
        notParams = "the request has no params"
        notRequest = "a #{request} is not a request"
        assert _.isObject(request), notRequest
        assert headers = request.headers, notParams
        return @value headers, name, message

    # This method is a default implementation of the renderer that
    # will be called when the validation has failed. You can easily
    # override it in either your service or in an external compound.
    # By default it renders JSON object with errors mapped to headers.
    renderHeaderValidation: (results, request, response) ->
        notRequest = "a #{request} is not a request"
        notResponse = "a #{response} is not a respnonse"
        assert _.isObject(response), notResponse
        assert _.isObject(request), notRequest
        response.statusCode = 400 # bad headers
        strings = _.map results, (e) -> e.message
        map = _.object _.keys(results), strings
        return @reject response, headers: map

    # Given the request with possible validation contexts appended
    # run all the validator contexts in parallel and wait for the
    # completion. If no validation mistakes found, run continuation.
    # If some mistakes are found, however, `@renderHeaderValidation`.
    validateParameters: (request, response, continuation) ->
        notRequest = "a #{request} is not a request"
        notResponse = "a #{response} is not a response"
        notContinuation = "a #{continuation} is not function"
        assert _.isFunction(continuation), notContinuation
        assert _.isObject(response), notResponse
        assert _.isObject(request), notRequest
        @validateValues request.headers, (error, results) ->
            signature = [results, request, response, continuation]
            return @renderHeaderValidation signature... if error
            return continuation.bind(this) results
