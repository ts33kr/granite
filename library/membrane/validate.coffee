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
tv4 = require "tv4"

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
        assert _.isObject @$vcontext = context; return this

    # Given the storage with possible validation contexts appended
    # run all the validator contexts in parallel and wait for the
    # completion. Once the validation has been completed, call the
    # continuation routine and pass the validation results to it.
    # Continuation will recieve error indicator and results params.
    validateValues: (storage, continuation) ->
        notContinuation = "a #{continuation} is not function"
        transformer = (o) -> (c) -> o.run (e) -> c null, e
        assert _.isFunction(continuation), notContinuation
        assert _.isObject(storage), "invalid storage given"
        assert vcontexts = storage.__vcontexts__ or Object()
        transformed =  _.map _.values(vcontexts), transformer
        transformed = _.object _.keys(vcontexts), transformed
        return async.parallel transformed, (error, results) =>
            failure = _.any _.values(results), _.isObject
            assert.ifError error, "internal valdation error"
            return continuation.bind(this) failure, results

    # Given an arbitrary JavaScript value, validate it against the
    # specified JSON Schema (according to the Draft v4). Depending
    # of whether the validation succeeds or fails the continuation
    # will be invoked with the respectful arguments. Please refer
    # to http://json-schema.org/latest/json-schema-validation.html.
    validateSchema: (subject, schema, continuation) ->
        oneOfValid = _.isString(schema) or _.isObject(schema)
        assert oneOfValid, "invalid schema definition is supplied"
        assert _.isFunction(continuation), "got invalid callback"
        assert results = tv4.validateMultiple(subject, schema)
        failure = (not results.valid?) or results.valid is no
        return continuation.bind(this) failure, results

    # Create new validation context for the values designated by
    # the `name` and add it to the supplied storage. If the `message`
    # is supplied then it will be forced as an error messages. Use
    # this method to automatically obtain contex for the parameter.
    # This variation of method is intended to work on any storage.
    value: (storage, name, message) ->
        assert not _.isEmpty(name), "invalid name"
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
module.exports.PValidator = class PValidator extends Validator

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
        notNaming = "invalid parameter name supplied"
        assert _.isObject(request), notRequest
        assert params = request.params, notParams
        assert not _.isEmpty(name), notNaming
        return @value params, name, message

    # Given the request with possible validation contexts appended
    # run all the validator contexts in parallel and wait for the
    # completion. If no validation mistakes found, run continuation.
    # If some mistakes are found however, see `@abnormalParameters`.
    validateParameters: (request, response, continuation) ->
        assert _.isFunction(continuation), "invalid continuation"
        assert _.isObject(response), "incorrect response object"
        assert _.isObject(request), "got incorrect request object"
        @validateValues request.params, (failure, results) ->
            assert signature = [results, request, response]
            return @abnormalParameters signature... if failure
            return continuation.bind(this) failure, results

    # This method is a default implementation of the renderer that
    # will be called when the validation has failed. You can easily
    # override it in either your service or in an external compound.
    # By default it renders JSON object with errors mapped to params.
    abnormalParameters: (results, request, response) ->
        notRequest = "a #{request} is not a request"
        notResponse = "a #{response} is not a respnonse"
        assert _.isObject(response), notResponse.toString()
        assert _.isObject(request), notRequest.toString()
        response.statusCode = 400 # bad HTTP request
        strings = _.map results, (e) -> e.message
        map = _.object _.keys(results), strings
        return @reject response, params: map

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
        notHeaders = "the request has no headers"
        notRequest = "a #{request} is not a request"
        notNaming = "invalid header name supplied"
        assert headers = request?.headers, notHeaders
        assert _.isObject(request), notRequest.toString()
        assert not _.isEmpty(name), notNaming.toString()
        normalized = name.toString().toLowerCase()
        return @value headers, normalized, message

    # Given the request with possible validation contexts appended
    # run all the validator contexts in parallel and wait for the
    # completion. If no validation mistakes found, run continuation.
    # If some mistakes are found however, see `@abnormalHeaders`.
    validateHeaders: (request, response, continuation) ->
        assert _.isFunction(continuation), "invalid continuation"
        assert _.isObject(response), "incorrect response object"
        assert _.isObject(request), "got incorrect request object"
        @validateValues request.headers, (failure, results) ->
            assert signature = [results, request, response]
            return @abnormalHeaders signature... if failure
            return continuation.bind(this) failure, results

    # This method is a default implementation of the renderer that
    # will be called when the validation has failed. You can easily
    # override it in either your service or in an external compound.
    # By default it renders JSON object with errors mapped to headers.
    abnormalHeaders: (results, request, response) ->
        notRequest = "a #{request} is not a request"
        notResponse = "a #{response} is not a respnonse"
        assert _.isObject(response), notResponse.toString()
        assert _.isObject(request), notRequest.toString()
        response.statusCode = 400 # bad HTTP request
        strings = _.map results, (e) -> e.message
        map = _.object _.keys(results), strings
        return @reject response, headers: map

# This is an ABC service intended to be used only as a compund. It
# provides a complete validation solution for the request body. The
# important difference is this validation system supports asynchronous
# validators which is what differs it from existent solutions. This
# validation system is a one-stop-shop for checking all the inputs!
module.exports.BValidator = class BValidator extends Validator

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    @abstract yes

    # Given the request with possible validation contexts appended
    # run all the validator contexts in parallel and wait for the
    # completion. If no validation mistakes found, run continuation.
    # If some mistakes are found however, see `@abnormalBody` method.
    validateBody: (request, response, schema, continuation) ->
        assert _.isFunction(continuation), "invalid continuation"
        assert _.isObject(response), "incorrect response object"
        assert _.isObject(request), "got incorrect request object"
        @validateSchema request.body, schema, (failure, results) ->
            assert signature = [results, request, response]
            return @abnormalBody signature... if failure
            return continuation.bind(this) failure, results

    # This method is a default implementation of the renderer that
    # will be called when the validation has failed. You can easily
    # override it in either your service or in an external compound.
    # By default it renders JSON object with errors mapped to params.
    abnormalBody: (results, request, response) ->
        notRequest = "a #{request} is not a request"
        notResponse = "a #{response} is not a respnonse"
        assert _.isObject(response), notResponse.toString()
        assert _.isObject(request), notRequest.toString()
        response.statusCode = 400 # bad HTTP request
        noErrors = "the schema results is not valid"
        assert _.isObject(results.errors), noErrors
        return @reject response, body: results.errors
