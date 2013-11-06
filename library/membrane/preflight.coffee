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
bower = require "bower"
asciify = require "asciify"
connect = require "connect"
logger = require "winston"
events = require "eventemitter2"
assert = require "assert"
colors = require "colors"
crypto = require "crypto"
nconf = require "nconf"
https = require "https"
path = require "path"
http = require "http"
util = require "util"

{Marshal} = require "./marshal"
{BowerSupport} = require "./bower"

{Extending} = require "../nucleus/extends"
{Composition} = require "../nucleus/compose"
{Archetype} = require "../nucleus/archetype"

# This abstract base class service is an extension of the Screenplay
# family that provides some tools for further initialization and set
# up. These preparations will be nececessary no matter what sort of
# Screenplay functionality you are going to implement. Currently the
# purpose of preflight is drawing in the remoted and Bower packages.
module.exports.RToolkit = class RToolkit extends BowerSupport

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # A directive to mark the certain remote class or object to be
    # included in the `Screenplay` context that is going to be emited
    # and deployed on the client site. Basically, use this to bring
    # in all the remote classes that you need to the remote call site.
    @remote: (subject) ->
        assert previous = @remotes or Array()
        qualify = try subject.remote.compile
        noRemote = "the subject is not remote"
        noPrevious = "invalid previous remotes"
        assert _.isArray(previous), noPrevious
        assert _.isFunction(qualify), noRemote
        @remotes = previous.concat subject

    # This server side method is called on the context prior to the
    # context being compiled and flushed down to the client site. The
    # method is wired in an asynchronous way for greater functionality.
    # This is the place where you would be importing the dependencies.
    # Pay attention that most implementations side effect the context.
    prelude: (symbol, context, request, next) ->
        context.inline -> `assert = chai.assert`
        context.inline -> `assert(logger = log)`
        context.inline -> try logger.enableAll()
        assert remotes = @constructor.remotes or []
        assert uniques = _.unique remotes or Array()
        @inject context, blob for blob in uniques
        return next.call this, undefined

# This abstract base class service is an extension of the Screenplay
# family that does some further environment initialization and set
# up. These preparations will be nececessary no matter what sort of
# Screenplay functionality you are going to implement. Currently the
# purpose of preflight is drawing in the remoted and Bower packages.
module.exports.Preflight = class Preflight extends RToolkit

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
    @bower "platform", "platform.js"
    @bower "async", "lib/async.js"
    @bower "eventemitter2"
    @bower "js-signals"
    @bower "loglevel"
    @bower "lodash"
    @bower "jquery"
    @bower "chai"

    # This block here defines a set of remote dependencies that are
    # going to be necessary no matter what sort of functionality is
    # is going to be implemented. Most of these libraries required
    # by the internal implementations of the various subcomponents.
    @remote Composition
    @remote Extending
    @remote Archetype
    @remote Marshal
