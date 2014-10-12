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

async = require "async"
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
{Archetype} = require "./arche"

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
    process: (request, response, next) -> next undefined

    # An important method whose responsibility is to create a new
    # instance of the service, which is later will be registered in
    # the router. This is invoked by the kernel when it discovering
    # new suitable services to register. This works asynchronously!
    # You need to take this into account, when overriding this one.
    @spawn: (kernel, c, a) -> super kernel, c, => @obtain kernel

    # Obtain an instance of this zombie services. This method does
    # implement the singleton behavior pattern. Beware however that
    # although you will always get an instance handle from this method
    # there is no any sort guarantee that this handle is initialized!
    # Please use this method, rather than trying to do it via `new`.
    this.obtain = this.zombieInstance = (kernel, callback) ->
        {apply, series} = async or require "async"
        assert identify = try @identify().underline
        {GraniteKernel} = require "./kernel" # cycle
        kernel = GraniteKernel.instance unless kernel
        nc = "the supplied callback is not a function"
        internalErr = "internal zombie spawning error"
        dstreamError = "something wrong at downstream"
        instantiated = => return _.has this, "instance"
        define = -> Object.defineProperty arguments...
        makeProp = (pp) => define this, "instance", pp
        return this.instance if instantiated() is yes
        assert makeProp value: new this(arguments...)
        assert (try instantiated()) is yes, internalErr
        notify = "Spawned a zombie instance of the %s"
        logger.debug notify.yellow, identify.toString()
        assert downstream = this.instance.downstream
        assert downstream = downstream.bind @instance
        assert _.isFunction(downstream), dstreamError
        assert _.isFunction(callback), nc if callback
        @instance.emit "mk-zombie", @instance, kernel
        f = apply callback or (->), @instance, kernel
        assert singleton = downstream singleton: f
        singleton kernel, @instance; @instance
