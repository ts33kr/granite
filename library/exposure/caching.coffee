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
bower = require "bower"
asciify = require "asciify"
connect = require "connect"
logger = require "winston"
events = require "eventemitter2"
assert = require "assert"
colors = require "colors"
crypto = require "crypto"
nconf = require "nconf"
https = require "https"
path = require "path"
http = require "http"
util = require "util"

{Extending} = require "../nucleus/extends"
{Composition} = require "../nucleus/compose"
{Barebones} = require "../membrane/skeleton"
{Archetype} = require "../nucleus/arche"

# This toolkit contains a set of routines that help to define the
# caching strategies. All of them are simple and definitely not for
# the heavy or production usage, but rather for most simple cases.
# Generally, you would only apply these strategies when implementing
# an API endpoint, within the `ApiService` abstract base class tool.
# Please refer to each strategy for more relevant information on it.
module.exports.CachingToolkit = class CachingToolkit extends Barebones

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # A decorator strategy for wrapping the API endpoint function
    # with an LRU (least-recently-used) type of cache that normally
    # uses the `request.path` as its key. This given cache strategy
    # is highly dependent on the usage of the `response.send` func
    # in order for the cache to work. Please see `plumbs` module
    # for more info on that. Also, depends on the spin off engine.
    # Please see the `lru-cache` package for more relevant info.
    @memoryCache: (size, time, keys) -> (implement) ->
        noSize = "no maximum size of cache supplied"
        noTime = "no TTL timeout for cache var given"
        noImpl = "no implementation endpoint supplied"
        noSpin = "not spin-off engine valuess detected"
        invKey = "the generated cache key is not valid"
        noReq = "no request in the spinned-off object"
        noRes = "no response in the spinned-off object"
        assert _.isFunction lru = require "lru-cache"
        assert _.isNumber(size or undefined), noSize
        assert _.isNumber(time or undefined), noTime
        assert _.isFunction(implement or no), noImpl
        assert options = try max: size, maxAge: time
        assert _.isObject caching = try lru options
        assert keys = (-> @request.path) unless keys
        assert i = -> _.isString _.first arguments
        hits = "Hit memory cache of %s at %s".green
        miss = "Missed memory cache of %s at %s".red
        return (captured...) -> # decorative wrapper
            assert @__isolated and @__origin, noSpin
            assert _.isObject(@request or 0), noReq
            assert _.isObject(@response or 0), noRes
            assert key = keys.call(this) or 0, invKey
            ident = @constructor.identify().underline
            set = (dx) -> caching.set key, dx if i(dx)
            c = cached = caching.get(key) or undefined
            logger.debug hits, key.bold, ident if c?
            return @response.send cached if cached?
            try logger.debug miss, key.bold, ident
            @response.once "sdat", (dx) => set dx
            implement.apply this, captured # call
