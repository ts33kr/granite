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
{EventEmitter2} = require "eventemitter2"

# A base class for all the validation contexts. Basically the conext
# encapsulates the necessary internal details as well as provides a
# set of validators to be used. So in order to create custom ones, you
# will need to create a descendant of this class and set is as context.
# The context setting happens on the service level with the directive.
module.exports.Context = class Context extends EventEmitter2

    # Create a new instance of the validation context with the given
    # value set as the subject for validation. Each validator will
    # refer to this value to perform their validation logic on it.
    # If the message arg is passed in then it will be used by force.
    constructor: (@value, @message) ->

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
        (@validators ?= []).push validator; @

    # Run the entire stack of chained validators. Once done, callback
    # will be called with an error parameter passed in. If any of the
    # validators in the chain has failed, then this parameter will have
    # an error object set in with an appropriate message about mistake.
    run: (callback) ->
        validators = @validators ?= []
        invalid = "inconsistent validators"
        assert _.isArray(validators), invalid
        async.series validators, (error) =>
            failed = _.isObject error
            custom = _.isString @message
            matches = failed and custom
            error.message = @message if matches
            @emit "run", error; callback error

# This is the basis for the default validation context. It contains
# a set of primitive and standard validators that can be used either
# directly or as a foundation for more complex validators that could
# be defined in the descendants of the default context implementation.
module.exports.Primitive = class Primitive extends Context

    # Check if the value is not empty. The validation will succeed
    # if the value is a string that contains anything, and not empty.
    # Please refer to the implementation for more details on the way
    # validator works. Also, refer to the `validate` module for info.
    notEmpty: -> @chain (callback) =>
        message = "the value is missing or empty"
        return callback() unless _.isEmpty @value
        return callback new Error message
