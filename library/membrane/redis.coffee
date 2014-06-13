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
assert module.exports.RedisClient = class RedisClient extends Service

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # Allows to configure custom connection options for Redis DB.
    # This is making sense if you want to have a service-isolated
    # Redis connection, using `REDIS_ENVELOPE_SERVICE` and this
    # connection is supposed to be wired into a different Redis
    # server or database. This variable is used to supply that.
    # It should be a function, returning a Redis config object.
    @REDIS_CONFIG: undefined

    # These defintions are the presets available for configuring
    # the Redis envelope getting functions. Please set the special
    # class value `REDIS_ENVELOPE` to either one of these values or
    # to a custom function that will generate/retrieve the Redis
    # envelope, when necessary. Depending on this, the system will
    # generate a new connection on the container, if it does not
    # contain an opened connection yet. The default container is
    # the kernel preset using the `REDIS_ENVELOPE_KERNEL` value.
    @REDIS_ENVELOPE_KERNEL: -> return @kernel
    @REDIS_ENVELOPE_SERVICE: -> @$redis ?= {}

    # A hook that will be called prior to unregistering the service
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    # This implementation correctly ends Redis connection, if any.
    unregister: (kernel, router, next) ->
        @constructor.REDIS_ENVELOPE ?= -> kernel
        envelope = this.constructor.REDIS_ENVELOPE
        envelope = try envelope.apply this, arguments
        return next() unless _.isObject envelope.redis
        {host, port, options} = envelope.redis or Object()
        assert host and port and options, "invalid Redis"
        message = "Disconnecting from the Redis at %s:%s"
        warning = "Latest Redis envelope was not a kernel"
        logger.info message.underline.magenta, host, port
        logger.debug warning.grey unless envelope is kernel
        try @emit "redis-gone", envelope.redis, envelope
        try kernel.emit? "redis-gone", envelope.redis, @
        try envelope.redis.end(); delete envelope.redis
        next.call this, undefined; return this

    # A hook that will be called prior to registering the service
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    # This implementation open a new Redis connection, if configed.
    register: (kernel, router, next) ->
        @constructor.REDIS_ENVELOPE ?= -> kernel
        envelope = this.constructor.REDIS_ENVELOPE
        envelope = envelope.apply this, arguments
        amc = @constructor.REDIS_CONFIG or -> null
        assert config = nconf.get("redis") or amc()
        return next() unless _.isObject config or 0
        return next() if _.isObject try envelope.redis
        {host, port, options} = config or new Object()
        assert _.isString(host), "got invalid Redis host"
        assert _.isNumber(port), "git invalid Redis port"
        assert _.isObject(options), "invalid Redis options"
        message = "Connecting to Redis at %s:%s".toString()
        noRedis = "Something has gone wrong, no Redis client"
        warning = "Latest Redis envelope was not a kernel".grey
        assert spawner = redisio.createClient.bind redisio
        logger.info message.underline.magenta, host, port
        logger.debug warning unless envelope is kernel
        envelope.redis = spawner port, host, options
        assert _.isObject(envelope.redis), noRedis
        kernel.emit "redis-ready", envelope.redis, @
        @emit "redis-ready", envelope.redis, kernel
        next.call this, undefined; return this

    # A hook that will be called prior to instantiating the service
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    # This implementation sets the Redis connection access handle.
    instance: (kernel, service, next) ->
        @constructor.REDIS_ENVELOPE ?= -> kernel
        envelope = this.constructor.REDIS_ENVELOPE
        envelope = try envelope.apply this, arguments
        return next undefined if _.has service, "redis"
        ack = "Acquire Redis client handle in %s".grey
        sig = => this.emit "redis-ready", @redis or null
        define = -> Object.defineProperty arguments...
        mkp = (prop) -> define service, "redis", prop
        dap = -> mkp arguments...; next(); sig(); this
        dap enumerable: yes, configurable: no, get: ->
            redis = try envelope.redis or undefined
            noRedis = "an envelope has no Redis client"
            identify = try this.constructor.identify()
            try logger.debug ack, identify.underline
            assert _.isObject(redis), noRedis; redis
