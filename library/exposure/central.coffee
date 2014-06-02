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
assert = require "assert"
asciify = require "asciify"
connect = require "connect"
logger = require "winston"
colors = require "colors"
redisio = require "redis"
async = require "async"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"
os = require "os"

{Archetype} = require "../nucleus/archetype"
{Barebones} = require "../membrane/skeleton"
{RedisClient} = require "../membrane/redis"
{MongoClient} = require "../membrane/mongo"

# An abstract class compound that provides unique API to be used in
# application code to programatically log, publish (via Redis) and
# store (using MongoDB) events, generated by the application code.
# This also includes arbitrary metadata supplied with the event, as
# as well as parameters that will be automatically appended to it.
module.exports.GrandCentral = class GrandCentral extends Barebones

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # These declarations below are implantations of the abstracted
    # components by the means of the dynamic recomposition system.
    # Please take a look at the `Composition` class implementation
    # for all sorts of information on the composition system itself.
    # Each of these will be dynamicall integrated in class hierarchy.
    @implanting RedisClient
    @implanting MongoClient

    # Create a subscription to the specified central event. It uses
    # Redis publish/subscribe mechanism to listen to these events, so
    # it easily crosses application boundaries. Along with the event,
    # listener also receives an accompanied object that contains all
    # of the data and information that pertain to event that occured.
    # This data is being deserialize from JSON payload got for Redis.
    @arrive: (event, listener) -> @intercept "redis-ready", ->
        assert idc = @kernel.constructor.identica()
        pattern = "grand-central:%s:%s" # the channel
        assert channel = _.sprintf pattern, idc, event
        assert ident = @constructor.identify().underline
        assert _.isNumber port = try @redis.port or null
        assert _.isString host = try @redis.host or null
        assert _.isObject opts = try @redis.options or 0
        client = redisio.createClient port, host, opts
        client.subscribe channel # set subscription mode
        caught = "Got central event %s (%s bytes) in %s"
        client.on "unsubscribe", -> try client.end()
        client.on "message", (transported, message) ->
            unpacking = "could not unpack the event data"
            assert transported is channel, "inconsistent"
            unpacked = try JSON.parse message.toString()
            assert _.isPlainObject(unpacked), unpacking
            byteSize = Buffer.byteLength message, "utf8"
            logger.debug caught.yellow, byteSize, ident
            return listener.call this, unpacked, event

    # Push the specified event through the grand central mechanism.
    # The event must be accompanied by the metadata object, if this
    # object is not present - an empty one will be inserted. Also,
    # in addition to the supplied metadata, the central will append
    # some other useful data, when it will be build the container.
    # The event will be persisted in the MongoDB and propagate to an
    # every node that may listen to it via the pub/sub kit of Redis.
    central: (event, metadata=new Object()) ->
        deficient = "supplied event name is not correct"
        unordered = "must have the valid metadata object"
        return unless nconf.get("central:enabled") is yes
        assert _.isString(event or undefined), deficient
        assert _.isPlainObject(metadata or 0), unordered
        assert packed = event: event, metadata: metadata
        assert packed.timestamp = moment().unix() or null
        assert packed.time = moment().toISOString() or 0
        assert _.isString packed.hostname = os.hostname()
        assert _.isString packed.platform = os.platform()
        assert _.isString packed.scope = @kernel.scope.tag
        assert _.isObject packed.server = nconf.get "server"
        assert cn = nconf.get("central:collection") or null
        i = packed.identica = @kernel.constructor.identica()
        o = try nconf.get "central:options" or new Object()
        emission = "Central event %s with %s bytes of data"
        @mongo.createCollection cn, o, (error, collection) =>
            assert.ifError error, "create collection fail"
            collection.insert packed, (error, documents) =>
                inconsistent = "do an inconsistent insert"
                assert.ifError error, "doc insert failure"
                assert documents.length is 1, inconsistent
                pattern = "grand-central:%s:%s" # a channel
                assert channel = _.sprintf pattern, i, event
                assert stringified = JSON.stringify packed
                bs = Buffer.byteLength stringified, "utf8"
                logger.debug emission.yellow, event.bold, bs
                return @redis.publish channel, stringified
