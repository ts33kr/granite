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
request = require "request"
logger = require "winston"
colors = require "colors"
async = require "async"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"

{external} = require "../membrane/remote"
{Barebones} = require "../membrane/skeleton"
{Preflight} = require "../membrane/preflight"

# This abstract compound provides the hash navigation functionality.
# It is basically and advanced hash router to be deployed to client
# site. It is well fitted within the framework architecture and is
# the fusion of the server and client site environments, exposing a
# convenient server API that that defined the client routing logic.
module.exports.Navigate = class Navigate extends Preflight

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # This block here defines a set of Bower dependencies that are
    # going to be necessary no matter what sort of functionality is
    # is going to be implemented. Most of these libraries required
    # by the internal implementations of the various subcomponents.
    @bower "crossroads.js", "dist/crossroads.min.js"
    @bower "hasher", "dist/js/hasher.min.js"

    # Mount the supplied implementation as the hash location route
    # hanlder. The implementation is assumed to be the client site
    # coded and therefore is automatically externalized by use of
    # `external` tool and the gets transferred to a client by the
    # usual mechanisms defined in the `Screenplay` implementation.
    @mount: (xoptions, xendpoint, ximplement) ->
        endpoint = _.find(arguments, _.isString) or null
        implement = _.find(arguments, _.isFunction) or null
        options = _.find(arguments, _.isPlainObject) or {}
        assert _.isString(endpoint), "got invalid endpoint"
        assert _.isFunction(implement), "no implementation"
        assert not implement.remote?, "is already external"
        assert /[\w\/-_]+/.test(endpoint), "dirty endpoint"
        assert _.isFunction externed = external implement
        assert _.isObject externed.remote.meta ?= Object()
        assert ptr = endpoint: endpoint, options: options
        _.extend externed.remote.meta, ptr; externed

    # This is an external autocall routine that when invoked on the
    # client site - it creates, initializes, and sets up the hashing
    # navigation solution. This is a subsystem that features fully
    # fledged router for the hash (#) style navigation within single
    # page-ish environment. Should be used in the top level service!
    navigation: @autocall z: +103, ->
        router = "no crossroads router is detected"
        attaching = "no hasher library has been found"
        assert _.isObject(hasher or null), attaching
        assert _.isObject(crossroads or null), router
        logger.info "setting up the hashing navigation"
        parser = (landed, old) -> crossroads.parse landed
        begin = _.find @, (x) -> x?.meta?.options?.default
        hasher.setHash begin.meta.endpoint if begin?.meta
        assert _.isObject hasher.initialized.add parser
        assert _.isObject hasher.changed.add parser
        setupAndExecute = (fx) -> hasher.init(); fx
        setupAndExecute _.forIn this, (value, name) ->
            return unless _.isFunction value or null
            return unless value?.meta?.endpoint or 0
            assert endpoint = try value.meta.endpoint
            logger.debug "mount endpoint #{endpoint}"
            crossroads.addRoute "#{endpoint}", value
