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
module.exports.VisualBillets = class VisualBillets extends Barebones

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
    @COMPOSITION_EXPORTS = renderers: yes

    # Use this method in the `prelude` scope to bring dependencies into
    # the scope. This method supports JavaScript scripts as a link or
    # JavaScript sources passed in as the remote objects. Please refer
    # to the implementation and the class for more information on it.
    # An internal implementations in the framework might be using it.
    inject: (context, subject, symbol) ->
        assert caching = context.caching ?= new Object()
        scripts = -> assert context.scripts.push subject
        sources = -> assert context.sources.push compile()
        compile = -> subject.remote.compile caching, symbol
        invalid = "not a remote object and not a JS link"
        assert _.isObject(context), "got invalid context"
        compilable = _.isFunction subject.remote?.compile
        return scripts.call this if _.isString subject
        return sources.call this if compilable
        throw new Error invalid.toString()

    # Use this decorator to append a renderer function to sequence.
    # These are server side, instance methods that will be invoked
    # when the visual core is performing final assmbly/compilation
    # of the context. Basically, it is when a programmatic context
    # turns into a raw HTML/JS that gets then sent away to client.
    # For more info, please refer to `Screenplay#contextRendering`.
    @rendering: (renderer) ->
        {series, apply} = async or require "async"
        noFunction = "no rendering function given"
        wrongUsage = "should accept >= 2 arguments"
        assert _.isFunction ss = series or undefined
        assert _.isFunction aa = apply or undefined
        assert _.isFunction b = (f, o) -> f.bind o
        fn = (s) -> (j, d, c) -> ss cp(@, s, j, d), c
        cp = (obj, s, j, dm) -> pp.call(obj, s, j, dm)
        pp = (s, j, d) -> (aa b(f, @), j, d for f in s)
        assert previous = @renderers or new Array()
        assert previous = try _.clone previous or []
        return fn previous if arguments.length is 0
        assert _.isFunction(renderer), noFunction
        assert (renderer.length >= 2), wrongUsage
        @renderers = previous.concat [renderer]
        assert @renderers = _.unique @renderers

    # This method implements overridiable type installation mechanism
    # similar to Beans in a way. It basically transfers remotable type
    # (or a function) onto the remote site and aliases it under given
    # token (name). The key here is this aliasing is done for every
    # method transferred to the client side. And the definitions table
    # that is used for aliasing is overridable based on inheritance.
    # This allows you to override type definitions that may be used in
    # the parent classes, without having to replace implementation code.
    @considering: (signature) ->
        message = "Set consideration of %s in %s"
        assert remotes = this.remotes or new Array()
        assert previous = @$considerations or Object()
        return previous if (try arguments.length) is 0
        identify = this.identify().toString().underline
        incorrect = "argument should be key/value pair"
        singleArg = "one definition possible at a time"
        fx = "value should be either remote or function"
        assert _.isObject(signature or null), incorrect
        assert _.keys(signature).length is 1, singleArg
        assert token = _.first _.keys(signature or null)
        assert value = _.first _.values(signature or 0)
        assert _.isFunction(value) or value.remote?, fx
        remotes.push value if (try value.remote.compile)
        raw = (try value.remote?.symbol) or ("#{value}")
        logger.debug message.grey, token.bold, identify
        assert this.$considerations = _.clone previous
        return this.$considerations[token] = raw

    # This is a highly specialized method that is defined solely for
    # the purpose of creating the medium to advanced components that
    # provide specialized, domain specific end-to-end API. It creates
    # a decorator that when invoked - transfers all its parameters to
    # the intermediate (client side) function that was supplied here.
    # The function itself is set to be invoked by autocall mechanism.
    @transferred: (intermediate) -> ->
        noFun = "no valid intermediate function"
        assert _.isFunction(intermediate), noFun
        supplied = _.toArray arguments or Array()
        intermediate = eval("[#{intermediate}]")[0]
        x = _.isString intermediate.remote?.source
        prepared = intermediate # default prepared
        prepared = @autocall intermediate unless x
        assert not _.isEmpty method = prepared or 0
        @prototype[_.uniqueId "__bts_trans_"] = method
        assert leaking = method.remote.leaking or {}
        i = _.isFunction; j = JSON.stringify # aliases
        aid = -> _.uniqueId "__bts_inline_arg_vector_"
        typ = (v) -> if i(v) then v.toString() else j(v)
        leaking[aid()] = typ arg for arg, ix in supplied
        auto = (fn) -> method.remote.auto = fn; method
        return auto (symbol, key, context) => _.once =>
            t = "#{symbol}.#{key}.apply(#{symbol},%s)"
            fk = (v) -> _.findKey leaking, (i) -> i is v
            compiled = (fk typ(val) for val in supplied)
            return format t, "[#{compiled.join(",")}]"

    # Use this static method to mark up the remote/external methods
    # that need to be automaticalled called, once everything is set
    # on the client site and before the entrypoint gets executed. It
    # is a get idea to place generic or setup code in the autocalls.
    # Refer to `inlineAutocalls` method for params interpretation.
    @autocall: (parameters, method) ->
        notFunction = "no function is passed in"
        method = _.find arguments, _.isFunction
        parameters = _.find arguments, _.isObject
        assert _.isFunction(method), notFunction
        isRemote = _.isObject try method?.remote
        method = external method unless isRemote
        method.remote.autocall = parameters or {}
        source = try method.remote.source or null
        assert _.isString source; return method

    # The awaiting directive is a lot like `autocall`, except the
    # implementation will not be immediatelly , but rather when the
    # specified signal is emited on the current context (service)
    # object. Effectively, it is the same as creating the autocall
    # that explicitly binds the event using `on` with the context.
    @awaiting: (event, method) ->
        invalidEvent = "an invalid event supplied"
        assert not _.isEmpty(event), invalidEvent
        assert method = @autocall Object(), method
        assert _.isObject method.remote.autocall
        assert try method.remote.meta.event = event
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
        invalidEvent = "an invalid event supplied"
        assert not _.isEmpty(event), invalidEvent
        assert method = @autocall Object(), method
        assert _.isObject method.remote.autocall
        assert try method.remote.meta.event = event
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
        invalidEvent = "an invalid event supplied"
        assert not _.isEmpty(event), invalidEvent
        assert method = @autocall Object(), method
        assert _.isObject method.remote.autocall
        select = "$root".toString().toLowerCase()
        assert try method.remote.meta.event = event
        auto = (fn) -> method.remote.auto = fn; method
        return auto (symbol, key, context) -> _.once ->
            t = "#{select}.on(%s, #{symbol}.#{key})"
            return format t, JSON.stringify event
