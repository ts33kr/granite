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
events = require "events"
colors = require "colors"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"

_ = require "lodash"
routing = require "./routing"
service = require "./service"
scoping = require "./scoping"
api = require "./api"

# Install the augmenten driven DSL into all of the specified
# namespace. Use this method, rather than directly invoking
# the corresponding class method of the Augment class object.
# Typical use is to invoke it on `this` object inside module.
module.exports = (namespaces...) ->
    install = Augment.installAugmentMethods
    bounded = install.bind(Augment)
    bounded(n) for n in namespaces

# This class is the internals and the working facade of the DSL for
# shorthand and convenient definition of new REST services. Rather
# than using full blown, class driver creating of services, you are
# provided with a DSL that allows to create services dynamically in
# a very short and convenient form. And automatically register them.
module.exports.Augment = class Augment extends events.EventEmitter

    # A protected constructor that sets in the necessary parameters
    # and then created the respective service, per augment object.
    # The service is then gets registered and published at places
    # where it needs to be wired in. Please do not use it directly.
    constructor: (@resource) ->
        @service = class extends api.Stub
        @emit("construct", @resource, @service)
        @service.publish api.Stub.EVERYWHERE
        @service.domain api.Stub.ANY
        @service.resource @resource

    # The very important routine, that creates a set of proxy methods
    # that, when invoked, will do the necessary magic to replace the
    # corresponding method (HTTP verb) with the supplied implementation.
    # It uses the Api to query for a set of support HTTP methods here.
    @installAugmentMethods: (namespace) ->
        supported = api.Api.SUPPORTED
        _.forEach supported, (method) -> do (method) ->
            msg = "Installing augment proxies for %s"
            logger.debug(msg.grey, method.toUpperCase())
            namespace[method] = (resource, implementation) =>
                augment = Augment.augmentForResource resource
                augment.service::[method] = implementation
                implementation.service = augment.service
                implementation.augment = augment
                implementation

    # Obtain the augment object for the specified resource. If such
    # an object does not exist, it will be automatically created and
    # put in place so that it can later be found. The resource can be
    # either a simple string or a regular expression pattern object.
    @augmentForResource: (resource) ->
        storage = @storage ?= {}
        inspected = util.inspect(resource)
        regexify = (s) -> new RegExp(RegExp.escape(s))
        resource = regexify(resource)  if _.isString(resource)
        notRegexp = "The #{inspected} is not a valid regular expression"
        throw new Error(notRegexp) unless _.isRegExp(resource)
        return augment if augment = storage[resource.source]
        storage[resource.source] = new Augment(resource)
