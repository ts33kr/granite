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
assert = require "assert"
events = require "eventemitter2"
colors = require "colors"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"
url = require "url"

{Zombie} = require "../nucleus/zombie"
{RedisClient} = require "../membrane/redis"

# This zombie service exposes session storage engine implementation.
# This implementation uses Redis to store the session data. It does
# make use of `RedisClient` and other wirings specific to framework.
# It is highly recommended to use this storage engine in production
# environments. Please refer to `plumbs` module for how to make use.
assert module.exports.RedisSession = class RedisSession extends Zombie

    # These declarations below are implantations of the abstracted
    # components by the means of the dynamic recomposition system.
    # Please take a look at the `Composition` class implementation
    # for all sorts of information on the composition system itself.
    # Each of these will be dynamicall integrated in class hierarchy.
    @implanting RedisClient

    # The dirty way of inheriting the prototypal properties of the
    # abstract session store engine found in the standard Connect
    # shipment. This is necessary in order to inherit the default
    # implementations of some generic, engine agnostic methods.
    # Refer to the inherited class implementation for refernce.
    _.extend @prototype, connect.session.Store.prototype

    # Part of the session engine interface contract implemenetation.
    # This method is supposed to be called when a session engine asks
    # the storage to destroy a session with the specified session ID.
    # The session may or may not exist. Please refer to the `Connect`.
    destory: (sid, callback) ->
        assert _.isString qualified = @namespaced sid
        assert _.isObject(@redis), "no Redis client yet"
        message = "Redis session engine error at destroy"
        process = "Destroying a Redis stored session %s"
        logger.debug process.grey, try sid.underline
        @redis.del qualified, (error, trailings...) ->
            @emit "session-destroy", sid, callback
            logger.error message.red, error if error
            return callback.call this, error if error
            return callback.apply this, arguments

    # Part of the session engine interface contract implemenetation.
    # This method is supposed to be called when a session engine asks
    # the storage to suspend a session with the specified session ID.
    # The session may or may not exist. Please refer to the `Connect`.
    set: (sid, session, callback) ->
        assert encoded = try JSON.stringify session
        assert _.isString qualified = @namespaced sid
        expire = session?.cookie?.maxAge / 1000 | 0
        expire = 86400 unless expire and expire > 0
        message = "Redis session engine error at set"
        encFailed = "failed to encode payload to JSON"
        assert _.isObject(@redis), "no Redis client yet"
        assert not _.isEmpty(encoded or null), encFailed
        @redis.setex qualified, expire, encoded, (error) ->
            @emit "session-set", sid, session, callback
            logger.error message.red, error if error
            return callback.call this, error if error
            return callback.apply this, arguments

    # Part of the session engine interface contract implemenetation.
    # This method is supposed to be called when a session engine asks
    # the storage to retrieve a session with the specified session ID.
    # The session may or may not exist. Please refer to the `Connect`.
    get: (sid, callback) ->
        assert _.isString qualified = @namespaced sid
        message = "Redis session engine error at get"
        df = "failed to decode JSON payload on the get"
        assert _.isObject(@redis), "no Redis client yet"
        @redis.get qualified, (error, data, trailings...) ->
            @emit "session-get", sid, data, callback
            logger.error message.red, error if error
            return callback.call this, error if error
            return callback.call this unless data
            assert data = try data.toString() or 0
            assert json = try JSON.parse(data), df
            return callback undefined, json

    # Obtain and return a fully namespaced key name for the specified
    # session ID. It tried to lookup the prefix from a configuration.
    # If no configure prefix is found, use the default hardcoded one.
    # A supplied session ID tag must conform to a set of restrictions.
    namespaced: (sid, prefixOverride) ->
        noSid = "sid argument has to be non empty"
        wrongSid = "sid argument has to be a string"
        assert not _.isEmpty(sid), noSid.toString()
        assert _.isString(sid), wrongSid.toString()
        prefix = nconf.get "session:redis:prefix"
        prefix = prefix or "session:redis:storage"
        prefix = prefixOverride if prefixOverride
        return "#{prefix}:#{sid}".toString()
