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
# configuration environment does not contains the necessary information
# then this service will not attempt to setup a Mongo client at all.
module.exports.MongoClient = class MongoClient extends Service

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
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
        kernel.mongo.close(); delete kernel.mongo
        return next undefined

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
        assert _.isString(host), "invalid Mongo host"
        assert _.isNumber(port), "invalid Mongo port"
        assert _.isObject(options), "invalid Mongo options"
        message = "Connecting to MongoDB at %s:%s"
        logger.info message.cyan.underline, host, port
        server = new mongodb.Server host, port, options
        kernel.mongo = new mongodb.MongoClient server
        return kernel.mongo.open (error, client) ->
            assert.ifError error, "failed to connect: #{error}"
            assert.ok _.isObject kernel.mongo = client
            scope = _.isString database = config.database
            message = "Setting the MongoDB database: %s"
            kernel.mongo = client.db database if scope
            logger.info message.magenta, database if scope
            return next undefined

    # A hook that will be called prior to instantiating the service
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    instance: (kernel, service, next) ->
        return next undefined if _.has service, "mongo"
        define = -> Object.defineProperty arguments...
        mkp = (prop) -> define service, "mongo", prop
        mkp enumerable: yes, configurable: no, get: ->
            mongo = @kernel.mongo or undefined
            noMongo = "a kernel has no Mongo client"
            assert _.isObject(mongo), noMongo; mongo
        return next undefined
