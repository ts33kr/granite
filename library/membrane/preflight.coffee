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

{Barebones} = require "./skeleton"
{Screenplay} = require "./visual"
{Extending} = require "../nucleus/extends"
{Composition} = require "../nucleus/compose"
{Archetype} = require "../nucleus/arche"

# This abstract base class service is an extension of the Screenplay
# family that does some further environment initialization and set
# up. These preparations will be nececessary no matter what sort of
# Screenplay functionality you are going to implement. Currently the
# purpose of preflight is drawing in the remotes and Bower packages.
module.exports.Preflight = class Preflight extends Screenplay

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # This block define a set of meta tags that specify or tweak
    # the way a client browser treats the content that it has got
    # from the server site. Please refer to the HTML5 specification
    # for more information on the exact semantics of any meta tag.
    # Reference the `Preflight` for the implementation guidance.
    @metatag generator: "github.com/ts33kr/granite"

    # This block here defines a set of Bower dependencies that are
    # going to be necessary no matter what sort of functionality is
    # is going to be implemented. Most of these libraries required
    # by the internal implementations of the various subcomponents.
    # Refer to `BowerSupport` class implementation for information.
    @bower "eventemitter2"
    @bower "js-signals"
    @bower "platform"
    @bower "loglevel"
    @bower "lodash"
    @bower "jquery"
    @bower "jwerty"
    @bower "chai"

    # This block here defines a set of Bower dependencies that are
    # going to be necessary no matter what sort of functionality is
    # is going to be implemented. Most of these libraries required
    # by the internal implementations of the various subcomponents.
    # This blocks defines the directory-scopes deps, not bare ones.
    @bower "underscore.string", "dist/underscore.string.min.js"
    @bower "async", "lib/async.js"
    @bower "node-uuid", "uuid.js"

    # This block here defines a set of remote dependencies that are
    # going to be necessary no matter what sort of functionality is
    # is going to be implemented. Most of these libraries required
    # by the internal implementations of the various subcomponents.
    # Refer to `RToolkit` class implementation for the information.
    @transfer Composition
    @transfer Extending
    @transfer Archetype
