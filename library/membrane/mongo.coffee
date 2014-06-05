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
assert module.exports.MongoClient = class MongoClient extends Service

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # Allows to configure custom connection options for Mongo DB.
    # This is making sense if you want to have a service-isolated
    # Mongo connection, using `MONGO_ENVELOPE_SERVICE` and this
    # connection is supposed to be wired into a different Mongo
    # server or database. This variable is used to supply that.
    # It should be a function, returning a Mongo config object.
    @MONGO_CONFIG = undefined

    # These defintions are the presets available for configuring
    # the Mongo envelope getting functions. Please set the special
    # class value `MONGO_ENVELOPE` to either one of these values or
    # to a custom function that will generate/retrieve the Mongo
    # envelope, when necessary. Depending on this, the system will
    # generate a new connection on the container, if it does not
    # contain an opened connection yet. The default container is
    # the kernel preset using the `MONGO_ENVELOPE_KERNEL` value.
    @MONGO_ENVELOPE_KERNEL = -> return @kernel
    @MONGO_ENVELOPE_SERVICE = -> @$mongo ?= {}

    # A hook that will be called prior to unregistering the service
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    # This implementation correctly ends Mongo connection, if any.
    unregister: (kernel, router, next) ->
        @constructor.MONGO_ENVELOPE ?= -> kernel
        envelope = this.constructor.MONGO_ENVELOPE
        envelope = try envelope.apply this, arguments
        return next() unless _.isObject envelope.mongo
        database = envelope.mongo._db or envelope.mongo
        assert _.isObject(database), "invalid DB present"
        {host, port, options} = try database.serverConfig
        message = "Disconnecting from the Mongo at %s:%s"
        warning = "Latest Mongo envelope was not a kernel"
        logger.info message.underline.magenta, host, port
        logger.debug warning.grey unless envelope is kernel
        try @emit "mongo-gone", envelope.mongo, envelope
        try kernel.emit? "mongo-gone", envelope.mongo, @
        envelope.mongo.close(); delete envelope.mongo
        next.call this, undefined; return this

    # A hook that will be called prior to registering the service
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    # This implementation open a new Mongo connection, if configed.
    register: (kernel, router, next) ->
        @constructor.MONGO_ENVELOPE ?= -> kernel
        envelope = this.constructor.MONGO_ENVELOPE
        envelope = envelope.apply this, arguments
        amc = @constructor.MONGO_CONFIG or -> null
        assert config = nconf.get("mongo") or amc()
        return next() unless _.isObject config or null
        return next() if _.isObject try envelope.mongo
        {host, port, options} = config or new Object()
        assert _.isString(host), "got invalid Mongo host"
        assert _.isNumber(port), "got invalid Mongo port"
        assert _.isObject(options), "invalid Mongo options"
        assert message = "Connecting to MongoDB at %s:%s"
        warning = "Latest Mongo envelope was not a kernel"
        logger.info message.underline.magenta, host, port
        logger.debug warning.grey unless envelope is kernel
        server = new mongodb.Server host, port, options
        envelope.mongo = new mongodb.MongoClient server
        return envelope.mongo.open (error, client) =>
            @openMongoConnection next, error, client

    # A presumably internal method that gets invoked by the primary
    # implementation to actually open the connection to previously
    # configured MongoDB database and if relevant - set up required
    # premises, such as the database name, among other things. This
    # method should not be called directly in most if cases at hand.
    # Please refer to `MongoClient#register` method implementation.
    openMongoConnection: (next, error, client) ->
        @constructor.MONGO_ENVELOPE ?= -> kernel
        envelope = this.constructor.MONGO_ENVELOPE
        envelope = try envelope.apply this, arguments
        amc = @constructor.MONGO_CONFIG or -> undefined
        assert config = try nconf.get("mongo") or amc()
        assert.ifError error, "mongo failed: #{error}"
        assert.ok _.isObject envelope.mongo = client
        scope = _.isString database = config.database
        message = "Setting the MongoDB database: %s"
        assert message = message.toString().underline
        envelope.mongo = client.db database if scope
        logger.info message.magenta, database if scope
        @emit "mongo-ready", envelope.mongo, envelope
        @kernel.emit "mongo-ready", envelope.mongo, @
        next.call this, undefined; return this

    # A hook that will be called prior to instantiating the service
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    # This implementation sets the Redis connection access handle.
    instance: (kernel, service, next) ->
        @constructor.MONGO_ENVELOPE ?= -> kernel
        envelope = this.constructor.MONGO_ENVELOPE
        envelope = try envelope.apply this, arguments
        return next undefined if _.has service, "mongo"
        ack = "Acquire MongoDB client handle in %s".grey
        sig = => this.emit "mongo-ready", @mongo or null
        define = -> Object.defineProperty arguments...
        mkp = (prop) -> define service, "mongo", prop
        dap = -> mkp arguments...; next(); sig(); this
        dap enumerable: yes, configurable: no, get: ->
            mongo = try envelope.mongo or undefined
            noMongo = "an envelope has no Mongo client"
            identify = try this.constructor.identify()
            try logger.debug ack, identify.underline
            assert _.isObject(mongo), noMongo; mongo
