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
uuid = require "node-uuid"
events = require "eventemitter2"
assert = require "assert"
colors = require "colors"
crypto = require "crypto"
async = require "async"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"

tools = require "../nucleus/toolkit"
extendz = require "../nucleus/extends"
compose = require "../nucleus/compose"

{EOL} = require "os"
{format} = require "util"
{STATUS_CODES} = require "http"
{Barebones} = require "./skeleton"
{remote, external} = require "./remote"
{coffee} = require "./runtime"

# This is an internal abstract base class that is not intended for
# being used directly. The class is being used by the implementation
# of framework sysrems to segregate the implementation of the visual
# core from the convenience API targeted to be used by a developers.
# Please refer to the `Screenplay` class for actual implementation.
# This can also contain non-developer internals of the visual core.
module.exports.EventsToolkit = class EventsToolkit extends Barebones

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # Use this static method to mark up the remote/external methods
    # that need to be automaticalled called, once everything is set
    # on the client site and before the entrypoint gets executed. It
    # is a get idea to place generic or setup code in the autocalls.
    # Refer to `inlineAutocalls` method for params interpretation.
    @autocall: (xparameters, xmethod) ->
        assert identify = @identify().underline
        method = _.find arguments, _.isFunction
        parameters = _.find arguments, _.isObject
        notFunction = "no function is passed in"
        message = "Autocall sequence invoke in %s"
        assert _.isFunction(method), notFunction
        isRemote = _.isObject try method?.remote
        method = external method unless isRemote
        method.remote.autocall = parameters or {}
        source = try method.remote.source or null
        assert _.isString(source), "cant compile"
        logger.debug message.grey, identify or 0
        return method # return the implementation

    # The awaiting directive is a lot like `autocall`, except the
    # implementation will not be immediatelly , but rather when the
    # specified signal is emited on the current context (service)
    # object. Effectively, it is the same as creating the autocall
    # that explicitly binds the event using `on` with the context.
    @awaiting: (xevent, xmethod) ->
        assert identify = this.identify().underline
        invalidMethod = "found an invalid function"
        invalidEvent = "found invalid event supplied"
        message = "Awaiting %s event for method in %s"
        event = _.find(arguments, _.isString) or null
        method = _.find(arguments, _.isFunction) or 0
        assert not _.isEmpty(event or 0), invalidEvent
        assert _.isFunction(method or 0), invalidMethod
        assert method = @autocall new Object(), method
        assert _.isObject method.remote.autocall or 0
        assert (try method.remote.meta.event = event)
        logger.debug message.grey, event, identify or 0
        auto = (fn) -> method.remote.auto = fn; method
        return auto (symbol, key, context) -> _.once ->
            t = "#{symbol}.on(%s, #{symbol}.#{key})"
            return format t, JSON.stringify event

    # The exclusive directive is a lot like `awaiting`, except it
    # removes all the event listeners that could have been binded
    # to the event. And only once that has been done, it binds the
    # supplied listener to the event, which will make it the only
    # listener of that event at the point of a method invocation.
    @exclusive: (event, method) ->
        assert identify = this.identify().underline
        invalidMethod = "found an invalid function"
        invalidEvent = "found invalid event supplied"
        message = "Exclusive %s event for method in %s"
        event = _.find(arguments, _.isString) or null
        method = _.find(arguments, _.isFunction) or 0
        assert not _.isEmpty(event or 0), invalidEvent
        assert _.isFunction(method or 0), invalidMethod
        assert method = @autocall new Object(), method
        assert _.isObject method.remote.autocall or 0
        assert (try method.remote.meta.event = event)
        logger.debug message.grey, event, identify or 0
        auto = (fn) -> method.remote.auto = fn; method
        return auto (symbol, key, context) -> _.once ->
            k = "#{symbol}.removeAllListeners(%s)"
            t = "#{symbol}.on(%s, #{symbol}.#{key})"
            binder = format t, JSON.stringify event
            killer = format k, JSON.stringify event
            "(#{killer}; #{binder})".toString()

    # The awaiting directive is a lot like `autocall`, except the
    # implementation will not be immediatelly , but rather when the
    # specified signal is emited on the $root main service context
    # object. Effectively, it is the same as creating the autocall
    # that explicitly binds the event using `on` with the context.
    @synchronize: (event, method) ->
        assert identify = this.identify().underline
        invalidMethod = "found an invalid function"
        invalidEvent = "found invalid event supplied"
        message = "Rooting %s event for method in %s"
        event = _.find(arguments, _.isString) or null
        method = _.find(arguments, _.isFunction) or 0
        assert not _.isEmpty(event or 0), invalidEvent
        assert _.isFunction(method or 0), invalidMethod
        assert method = @autocall new Object(), method
        assert _.isObject method.remote.autocall or 0
        assert (try method.remote.meta.event = event)
        logger.debug message.grey, event, identify or 0
        auto = (fn) -> method.remote.auto = fn; method
        assert select = "$root".toString().toLowerCase()
        return auto (symbol, key, context) -> _.once ->
            t = "#{select}.on(%s, #{symbol}.#{key})"
            return format t, JSON.stringify event
