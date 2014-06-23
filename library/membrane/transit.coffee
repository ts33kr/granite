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

{EOL} = require "os"
{format} = require "util"
{STATUS_CODES} = require "http"
{Barebones} = require "./skeleton"
{remote, external} = require "./remote"
{coffee} = require "./runtime"

# This is an internal abstract base class that is not intended for
# being used directly. The class contains a set of routines that are
# automatically merged into every service that uses the visual core.
# Methods that are defined in this class intended for developers to
# extend the capabilities of the framework and explicitly to develop
# new abastract services and components. Please refer to the sources.
module.exports.TransitToolkit = class TransitToolkit extends Barebones

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
    @COMPOSITION_EXPORTS: renderers: yes, considerations: yes

    # Use this decorator to append a renderer function to sequence.
    # These are server side, instance methods that will be invoked
    # when the visual core is performing final assmbly/compilation
    # of the context. Basically, it is when a programmatic context
    # turns into a raw HTML/JS that gets then sent away to client.
    # For more info, please refer to `Screenplay#contextRendering`.
    @rendering: (renderer) ->
        {series, apply} = try async or require "async"
        assert _.isFunction ss = series # a func alias
        assert _.isFunction aa = apply # a func alias
        noFunction = "got no rendering function given"
        wrongUsage = "func should accept >= 2 arguments"
        assert _.isFunction b = (fn, ob) -> fn.bind ob
        xfn = (s) -> (j, d, c) -> ss xcp(@, s, j, d), c
        xcp = (obj, s, j, dm) -> xpp.call(obj, s, j, dm)
        xpp = (s, j, d) -> (aa b(f, @), j, d for f in s)
        assert previous = this.renderers or new Array()
        assert previous = try _.clone previous or Array()
        return xfn previous if (try arguments.length is 0)
        assert _.isFunction(renderer or null), noFunction
        assert ((renderer.length or 0) >= 2), wrongUsage
        assert @renderers = previous.concat [renderer]
        assert @renderers = _.unique this.renderers

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
        assert previous = @considerations or new Array()
        return _.object previous unless arguments.length
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
        raw = (try value.remote.symbol) or value.toString()
        logger.debug message.grey, token.bold, identify
        @considerations = previous.concat [[token, raw]]

    # This is a highly specialized method that is defined solely for
    # the purpose of creating the medium to advanced components that
    # provide specialized, domain specific end-to-end API. It creates
    # a decorator that when invoked - transfers all its parameters to
    # the intermediate (client side) function that was supplied here.
    # The function itself is set to be invoked by autocall mechanism.
    @transferred: (intermediate) -> ->
        noFunction = "no valid intermediate function"
        assert _.isFunction(intermediate), noFunction
        supplied = _.toArray arguments or new Array()
        intermediate = _.head eval "[#{intermediate}]"
        x = _.isString try intermediate.remote?.source
        prepared = intermediate # default prepared fnc
        prepared = this.autocall intermediate unless x
        assert not _.isEmpty method = prepared or null
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
