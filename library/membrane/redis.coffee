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

asciify = require "asciify"
connect = require "connect"
logger = require "winston"
events = require "eventemitter2"
colors = require "colors"
assert = require "assert"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"
url = require "url"

_ = require "lodash"
redisio = require "redis"
{Barebones} = require "./skeleton"
{Service} = require "../nucleus/service"

# This is an ABC service intended to be used only as a compund. It
# provides the ready to use Redis client to any service that composits
# this service in. The initialization is performed only once. If the
# configuration environment does not contains the necessary information
# then this service will not attempt to setup a Redis client at all.
module.exports.RedisClient = class RedisClient extends Service

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # A hook that will be called prior to unregistering the service
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    unregister: (kernel, router, next) ->
        return next() unless _.isObject kernel.redis
        {host, port, options} = kernel.redis or Object()
        message = "Disconnecting from Redis at %s:%s"
        logger.info message.cyan.underline, host, port
        try @emit "redis-gone", kernel.redis, kernel
        try kernel.emit? "redis-gone", kernel.redis
        try kernel.redis.end(); delete kernel.redis
        next.call this, undefined; return this

    # A hook that will be called prior to registering the service
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    register: (kernel, router, next) ->
        config = nconf.get "redis" or null
        return next() unless _.isObject config
        return next() if _.isObject kernel.redis
        {host, port, options} = config or Object()
        assert _.isString(host), "got invalid Redis host"
        assert _.isNumber(port), "git invalid Redis port"
        assert _.isObject(options), "invalid Redis options"
        message = "Connecting to Redis at %s:%s".toString()
        noRedis = "Something has gone wrong, no Redis client"
        assert spawner = redisio.createClient.bind redisio
        logger.info message.cyan.underline, host, port
        kernel.redis = spawner port, host, options
        assert _.isObject(kernel.redis), noRedis
        @emit "redis-ready", kernel.redis, kernel
        kernel.emit "redis-ready", kernel.redis
        next.call this, undefined; return this

    # A hook that will be called prior to instantiating the service
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    instance: (kernel, service, next) ->
        return next undefined if _.has service, "redis"
        define = -> Object.defineProperty arguments...
        mkp = (prop) -> define service, "redis", prop
        dap = -> mkp arguments...; next(); return this
        dap enumerable: yes, configurable: no, get: ->
            redis = try @kernel.redis or undefined
            noRedis = "a kernel has no Redis client"
            assert _.isObject(redis), noRedis; redis
