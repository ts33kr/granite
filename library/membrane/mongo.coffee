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
mongodb = require "mongodb"
{Barebones} = require "./skeleton"
{Service} = require "../nucleus/service"

# This is an ABC service intended to be used only as a compund. It
# provides the ready to use Mongo client to any service that composits
# this service in. The initialization is performed only once. If the
# configuration environment does not contain the necessary information
# then this service will not attempt to setup a Mongo client at all.
module.exports.MongoClient = class MongoClient extends Service

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
        return next() unless _.isObject kernel.mongo
        database = kernel.mongo._db or kernel.mongo
        {host, port, options} = database.serverConfig
        message = "Disconnecting from Mongo at %s:%s"
        logger.info message.cyan.underline, host, port
        try @emit "mongo-gone", kernel.redis, kernel
        try kernel.emit? "mongo-gone", kernel.redis
        kernel.mongo.close(); delete kernel.mongo
        next.call this, undefined; return this

    # A hook that will be called prior to registering the service
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    register: (kernel, router, next) ->
        config = nconf.get("mongo") or null
        return next() unless _.isObject config
        return next() if _.isObject kernel.mongo
        {host, port, options} = config or Object()
        assert _.isString(host), "got invalid Mongo host"
        assert _.isNumber(port), "got invalid Mongo port"
        assert _.isObject(options), "invalid Mongo options"
        assert message = "Connecting to MongoDB at %s:%s"
        logger.info message.cyan.underline, host, port
        server = new mongodb.Server host, port, options
        kernel.mongo = new mongodb.MongoClient server
        return kernel.mongo.open (error, client) =>
            @openMongoConnection next, error, client

    # A presumably internal method that gets invoked by the primary
    # implementation to actually open the connection to previously
    # configured MongoDB database and if relevant - set up required
    # premises, such as the database name, among other things. This
    # method should not be called directly in most if cases at hand.
    openMongoConnection: (next, error, client) ->
        assert _.isObject config = nconf.get "mongo"
        assert.ifError error, "mongo failed: #{error}"
        assert.ok _.isObject @kernel.mongo = client
        scope = _.isString database = config.database
        message = "Setting the MongoDB database: %s"
        @kernel.mongo = client.db database if scope
        logger.info message.magenta, database if scope
        @emit "mongo-ready", @kernel.redis, @kernel
        @kernel.emit "mongo-ready", @kernel.redis
        next.call this, undefined; return this

    # A hook that will be called prior to instantiating the service
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    instance: (kernel, service, next) ->
        return next undefined if _.has service, "mongo"
        ack = "Acquire MongoDB client handle in %s".grey
        sig = => this.emit "mongo-ready", @mongo or null
        define = -> Object.defineProperty arguments...
        mkp = (prop) -> define service, "mongo", prop
        dap = -> mkp arguments...; next(); sig(); this
        dap enumerable: yes, configurable: no, get: ->
            mongo = try @kernel.mongo or undefined
            noMongo = "a kernel has no Mongo client"
            identify = try this.constructor.identify()
            try logger.debug ack, identify.underline
            assert _.isObject(mongo), noMongo; mongo
