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

{BowerSupport} = require "./bower"
{Barebones} = require "./skeleton"
{Extending} = require "../nucleus/extends"
{Composition} = require "../nucleus/compose"
{Archetype} = require "../nucleus/arche"

# This is an internal abstract base class that is not intended for
# being used directly. This class holds a set definitions intended
# for developers. They consist the backbone of the visual core that
# allow to transfer the remotes (captured classes, function) to the
# client site environment. Please refer to the class implementation
# for more information on the details and the usage information also.
module.exports.TransferToolkit = class TransferToolkit extends Barebones

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # Symbol declaration table, that states what keys, if those are
    # vectors (arrays) should be exported and then merged with their
    # counterparts in the destination, once the composition process
    # takes place. See the `Archetype::composition` hook definition
    # for more information. Keys are names, values can be anything.
    @COMPOSITION_EXPORTS = remotes: yes

    # A directive to mark the certain remote class or object to be
    # included in the `Screenplay` context that is going to be emited
    # and deployed on the client site. Basically, use this to bring
    # in all the remote classes that you need to the remote call site.
    # Refer to the remote compilation procedures for more information.
    @transfer: (xsubject) ->
        subject = try _.find arguments, _.isObject
        assert identify = try @identify().underline
        missing = "missing the supplied subject obj"
        noRemote = "a supplied subject is not remote"
        noPrevious = "found invalid previous remotes"
        message = "Transferring sequence invoke in %s"
        assert previous = this.remotes or new Array()
        assert _.isObject(subject or null), missing
        qualify = try subject.remote.compile or null
        assert _.isArray(previous or 0), noPrevious
        assert _.isFunction(qualify or 0), noRemote
        logger.debug message.grey, identify or null
        assert @remotes = previous.concat subject
        assert @remotes = _.unique @remotes or []
        return subject # return a subject object

    # Use this method in the `prelude` scope to bring dependencies into
    # the scope. This method supports JavaScript scripts as a link or
    # JavaScript sources passed in as the remote objects. Please refer
    # to the implementation and the class for more information on it.
    # An internal implementations in the framework might be using it.
    inject: (context, subject, symbol) ->
        invalidCache = "an invalid context caching"
        invalid = "not the remote and not a JS link"
        assert caching = ccg = context?.caching ?= {}
        assert _.isObject(caching or 0), invalidCache
        assert _.isObject(context or 0), "not context"
        assert not _.isEmpty(subject), "empty subject"
        scripts = -> try context.scripts.push subject
        sources = -> try context.sources.push compile()
        compile = -> subject.remote.compile ccg, symbol
        assert _.isObject(context), "got invalid context"
        compilable = _.isFunction subject.remote?.compile
        return scripts.call this if _.isString subject
        return sources.call this if compilable or null
        throw new Error invalid # nothing valid found

    # This server side method is called on the context prior to the
    # context being compiled and flushed down to the client site. The
    # method is wired in an asynchronous way for greater functionality.
    # This is the place where you would be importing the dependencies.
    # Pay attention that most implementations side effect the context.
    prelude: (symbol, context, request, next) ->
        quiet = nconf.get("visual:logging") is false
        assert _.isObject(context or 0), "not context"
        assert _.isObject(request or 0), "not request"
        assert _.isString(symbol or null), "not symbol"
        assert context.inline -> `assert = chai.assert`
        assert context.inline -> `assert(logger = log)`
        assert context.inline -> `assert($logger = log)`
        assert context.inline -> try logger.enableAll()
        (context.inline -> logger.disableAll()) if quiet
        context.inline -> try _.mixin _.string.exports()
        context.inline -> assert $(document).ready =>
            try this.emit "document", document, this
        assert remotes = this.constructor.remotes or []
        assert uniques = _.unique remotes or new Array()
        @inject context, rem, null for rem in uniques
        return do => next.call this, undefined
