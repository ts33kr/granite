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

# A complementary part of the preflight procedures that provides the
# ability to create and emit arbitrary linkage in the contexts that
# are going to be assembled within the current preflight hierarchy.
# The facilities of this toolkit should typically be used when you
# need to link to a static asset file, within any domain or path.
module.exports.LinksToolkit = class LinksToolkit extends Barebones

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
    @COMPOSITION_EXPORTS: jscripts: 1, stsheets: 1, metatags: 1

    # This server side method is called on the context prior to the
    # context being compiled and flushed down to the client site. The
    # method is wired in an asynchronous way for greater functionality.
    # This is the place where you would be importing the dependencies.
    # Pay attention that most implementations side effect the context.
    prelude: (symbol, context, request, next) ->
        identify = try @constructor.identify().underline
        message = "Flushing out the JS/CSS linkage in %s"
        assert _.isString(symbol), "cannot found symbol"
        assert _.isObject(context), "located no context"
        assert _.isObject(request), "located no request"
        assert _.isFunction(next), "got no next function"
        logger.debug message.yellow, identify.toString()
        gx = (key) => this.constructor[key] or Array()
        sx = (key, s) => context[key].push v for v in s
        fx = (inp, out) => try sx out, _.unique(gx(inp))
        ax = (mapping) => fx(k, v) for k, v of mapping
        ax metatags: "metatag" # map metatags to context
        ax jscripts: "scripts" # map scripts to context
        ax stsheets: "sheets" # map styles to context
        return do => next.call this # asynchronous

    # This is a preflight directive that can be used to generate and
    # emit meta tags for the client browser. The directive expects a
    # aggregate definition (an object) whose key/value pairs will be
    # diretly corellated as parameter name and value for a meta tag
    # definition. Any number of pairs (parameters) may be supplied.
    @metatag: (aggregate) ->
        assert identify = this.identify().toString()
        failed = "argument has to be the plain object"
        message = "Setting metatags information in %s"
        noPrevious = "found invalid previous metatags"
        assert _.all(_.values(aggregate), _.isString)
        assert previous = this.metatags or new Array()
        assert _.isEmpty a = accumulate = new Array()
        assert _.isArray(previous or null), noPrevious
        assert _.isPlainObject(aggregate or 0), failed
        format = (val, key) -> "#{key}=\x22#{val}\x22"
        _.map aggregate, (v, k) -> a.push format(v, k)
        assert _.isString joined = accumulate.join " "
        @metatags = previous.concat joined.toString()
        logger.debug message.grey, identify.underline
        return aggregate # return the object back

    # This is a preflight directive that can be used to link any
    # arbitrary JavaScript file source. Is important do understand
    # that this directive only compiles the appropriate statement
    # to be transferred to the server and it is up to you to ensure
    # the existence of that file and its ability to be downloaded.
    @javascript: (xparameter, xdirection) ->
        assert previous = this.jscripts or Array()
        assert identify = this.identify().toString()
        parameter = _.find arguments or [], _.isObject
        direction = _.find arguments or [], _.isString
        message = "Adding JavaScript information in %s"
        indirect = "an inalid direction have supplied"
        noPrevious = "found invalid previous jscripts"
        assert _.isEmpty a = accumulate = new Array()
        assert _.isArray(previous or null), noPrevious
        assert _.isString(direction or null), indirect
        format = (val, key) -> return "#{key}=#{val}"
        _.map parameter, (v, k) -> a.push format(v, k)
        assert _.isString joined = accumulate.join "&"
        logger.debug message.grey, identify.underline
        direction += "?#{joined}" unless _.isEmpty a
        assert @jscripts = previous.concat direction
        assert @jscripts = _.unique this.jscripts

    # This is a preflight directive that can be used to link any
    # arbitrary CSS style file source. Is important do understand
    # that this directive only compiles the appropriate statement
    # to be transferred to the server and it is up to you to ensure
    # the existence of that file and its ability to be downloaded.
    @stylesheet: (xoptions, xdirection) ->
        assert previous = this.stsheets or Array()
        assert identify = this.identify().toString()
        parameter = _.find arguments or [], _.isObject
        direction = _.find arguments or [], _.isString
        message = "Adding Stylesheet information in %s"
        indirect = "an inalid direction have supplied"
        noPrevious = "found invalid previous stsheets"
        assert _.isEmpty a = accumulate = new Array()
        assert _.isArray(previous or null), noPrevious
        assert _.isString(direction or null), indirect
        format = (val, key) -> return "#{key}=#{val}"
        _.map parameter, (v, k) -> a.push format(v, k)
        assert _.isString joined = accumulate.join "&"
        logger.debug message.grey, identify.underline
        direction += "?#{joined}" unless _.isEmpty a
        assert @stsheets = previous.concat direction
        assert @stsheets = _.unique this.stsheets
