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

assert = require "assert"
logger = require "winston"
uuid = require "node-uuid"
colors = require "colors"
util = require "util"
url = require "url"

_ = require "lodash"
extendz = require "./extends"
routing = require "./routing"
scoping = require "./scoping"

{Service} = require "./service"
{Archetype} = require "./archetype"

# This is an abstract base class that represents zombie service. A
# zombie service is a service that does not match any request but
# does live within the service infrastructure. The zombie exhibits
# singleton behavior. Typically zombies are used from outside of the
# service infrastructure, yet zombies service themvselves reside in.
module.exports.Zombie = class Zombie extends Service

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # Either obtain or set the HTTP location of the current service.
    # If not location has been set, but the one is requested then
    # the deduced default is returned. Default location is the first
    # resource regular expression pattern being unescaped to string.
    # Do not confuse it with `qualified` method that deals with URL.
    @location: -> "/#{@reference()}/#{@identify()}"

    # This method determines whether the supplied HTTP request
    # matches this service. This is determined by examining the
    # domain/host and the path, in accordance with the patterns
    # that were used for configuring the class of this service.
    # It is async, so be sure to call the `decide` with boolean!
    matches: (request, response, decide) -> decide no

    # This method should process the already matched HTTP request.
    # But since this is an abstract base class, this implementation
    # only extracts the domain and pathname captured groups, and
    # returns them to the caller. Override it to do some real job.
    # The captured groups may be used by the overrider or ditched.
    process: (request, response, next) -> undefined

    # Obtain an instance of this zombie services. This method does
    # implement the singleton behavior pattern. Beware however that
    # although you will always get an instance handle from this method
    # although there is no guarantee that this handle is initialized!
    @obtain: (kernel, callback) ->
        instantiated = => _.has @, "instance"
        return @instance if (try instantiated())
        internal = "got an internal zombie error"
        assert _.isFunction lazy = try @lazy()
        do -> lazy.call this, kernel, callback
        assert @instance = new this arguments...
        assert instantiated() is yes, internal
        assert downstream = @instance.downstream
        assert downstream = downstream.bind @instance
        assert singleton = downstream singleton: ->
            return unless _.isFunction callback
            callback.call this, @instance, kernel
        singleton kernel, @instance; @instance

    # An important method whose responsibility is to create a new
    # instance of the service, which is later will be registered in
    # the router. This is invoked by the watcher when it discovers
    # new suitable services to register. This works asynchronously!
    @spawn: (kernel, callback) ->
        noKernel = "got no valid kernel"
        assert _.isObject kernel, noKernel
        assert _.isObject service = @obtain()
        constructor = service.constructor or ->
        constructor.apply service, arguments
        assert downstream = service.downstream
        assert downstream = downstream.bind service
        assert instance = downstream instance: ->
            return unless _.isFunction callback
            callback.call this, service, kernel
        instance kernel, service; service
