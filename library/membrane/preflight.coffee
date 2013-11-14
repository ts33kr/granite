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

    # This is the composition hook that gets invoked when compound
    # is being composed into other services and components. Merges
    # together added jscripts found in both hierarchies, the current
    # one and the foreign (the one that is beign merged in). Exists
    # for backing up the consistent behavior when using composition.
    @composition: (destination) ->
        assert currents = this.remotes or Array()
        previous = destination.remotes or Array()
        return unless destination.derives RToolkit
        assert previous? and try _.isArray previous
        assert merged = previous.concat currents
        assert merged = _.toArray _.unique merged
        assert try destination.remotes = merged
        try super catch error; return this

    # A directive to mark the certain remote class or object to be
    # included in the `Screenplay` context that is going to be emited
    # and deployed on the client site. Basically, use this to bring
    # in all the remote classes that you need to the remote call site.
    # Refer to the remote compilation procedures for more information.
    @remote: (subject) ->
        assert previous = @remotes or Array()
        qualify = try subject.remote.compile
        noRemote = "the subject is not remote"
        noPrevious = "invalid previous remotes"
        assert _.isArray(previous), noPrevious
        assert _.isFunction(qualify), noRemote
        this.remotes = previous.concat subject
        this.remotes = _.unique @remotes or []

    # This server side method is called on the context prior to the
    # context being compiled and flushed down to the client site. The
    # method is wired in an asynchronous way for greater functionality.
    # This is the place where you would be importing the dependencies.
    # Pay attention that most implementations side effect the context.
    prelude: (symbol, context, request, next) ->
        context.inline -> `assert = chai.assert`
        context.inline -> `assert(logger = log)`
        context.inline -> try logger.enableAll()
        context.inline -> $(document).ready =>
            this.emit "document", document, this
        assert remotes = @constructor.remotes or []
        assert uniques = _.unique remotes or Array()
        @inject context, blob for blob in uniques
        return do => next.call this, undefined

# A complementary part of the preflight procedures that provides the
# ability to create and emit arbitrary linkage in the contexts that
# are going to be assembled within the current preflight hierarchy.
# The facilities of this toolkit should typically be used when you
# need to link to a static asset file, within any domain or path.
module.exports.LToolkit = class LToolkit extends RToolkit

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # This server side method is called on the context prior to the
    # context being compiled and flushed down to the client site. The
    # method is wired in an asynchronous way for greater functionality.
    # This is the place where you would be importing the dependencies.
    # Pay attention that most implementations side effect the context.
    prelude: (symbol, context, request, next) ->
        assert jscripts = @constructor.jscripts or []
        assert stsheets = @constructor.stsheets or []
        assert metatags = @constructor.metatags or []
        assert jscripts = _.unique jscripts or Array()
        assert stsheets = _.unique stsheets or Array()
        assert metatags = _.unique metatags or Array()
        assert _.isFunction context.sheets.push or null
        assert _.isFunction context.scripts.push or null
        assert _.isFunction context.metatag.push or null
        context.metatag.push mettag for mettag in metatags
        context.scripts.push script for script in jscripts
        context.sheets.push sheet for sheet in stsheets
        return do => next.call this, undefined

    # This is a preflight directive that can be used to generate and
    # emit meta tags for the client browser. The directive expects a
    # aggregate definition (an object) whose key/value pairs will be
    # diretly corellated as parameter name and value for a meta tag
    # definition. Any number of pairs (parameters) may be supplied.
    @metatag: (aggregate) ->
        failed = "param has to be the plain object"
        noPrevious = "got invalid previous metatags"
        assert previous = @metatags or new Array()
        assert _.isEmpty a = accumulate = new Array
        assert _.isArray(previous or 0), noPrevious
        assert _.isPlainObject(aggregate), failed
        f = (val, key) -> "#{key}=\x22#{val}\x22"
        _.map aggregate, (v, k) -> a.push f(v, k)
        assert _.isString j = accumulate.join " "
        @metatags = previous.concat j.toString()

    # This is a preflight directive that can be used to link any
    # arbitrary JavaScript file source. Is important do understand
    # that this directive only compiles the appropriate statement
    # to be transferred to the server and it is up to you to ensure
    # the existence of that file and its ability to be downloaded.
    @javascript: (xoptions, xdirection) ->
        assert previous = @jscripts or Array()
        options = _.find arguments, _.isObject
        direction = _.find arguments, _.isString
        indirect = "an inalid direction supplied"
        noPrevious = "invalid previous jscripts"
        assert _.isArray(previous), noPrevious
        assert _.isString(direction), indirect
        @jscripts = previous.concat direction
        assert @jscripts = _.unique @jscripts

    # This is a preflight directive that can be used to link any
    # arbitrary CSS style file source. Is important do understand
    # that this directive only compiles the appropriate statement
    # to be transferred to the server and it is up to you to ensure
    # the existence of that file and its ability to be downloaded.
    @stylesheet: (xoptions, xdirection) ->
        assert previous = @stsheets or Array()
        options = _.find arguments, _.isObject
        direction = _.find arguments, _.isString
        indirect = "an inalid direction supplied"
        noPrevious = "invalid previous stsheets"
        assert _.isArray(previous), noPrevious
        assert _.isString(direction), indirect
        @stsheets = previous.concat direction
        assert @stsheets = _.unique @stsheets

# This abstract base class service is an extension of the Screenplay
# family that does some further environment initialization and set
# up. These preparations will be nececessary no matter what sort of
# Screenplay functionality you are going to implement. Currently the
# purpose of preflight is drawing in the remoted and Bower packages.
module.exports.Preflight = class Preflight extends LToolkit

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
    # Refer to `BowerSupport` class implementation for information.
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
    # Refer to `RToolkit` class implementation for the information.
    @remote Composition
    @remote Extending
    @remote Archetype
    @remote Marshal
