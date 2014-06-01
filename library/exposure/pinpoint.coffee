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

# This abstract compound provides the curious functionality that is
# greatly improving the way you would construct the client side code
# that is responsible for rendering UI elements. It allows you to run
# client side (external) code once the specified selector is available.
# All of this lets you easily implement the viewport/slow architecture.
# It also allows you to react on when selector changes or disappears.
module.exports.Pinpoint = class Pinpoint extends Preflight

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # This block here defines a set of Bower dependencies that are
    # required by the client site part of the code that constitutes
    # this service or compound. Dependencies can be restricted to a
    # certain version and also they can have customized entrypoint.
    # Refer to `BowerSupport` class implementation for information.
    @bower "mutation-summary", "src/mutation-summary.js"

    # A part of the internal implementation of pinpointing component.
    # Provides a common interface (for the components implementation)
    # to invoke the `mutation-summary` library with some predefined
    # parameters, in addition to the ones that will be passed into
    # this method as arguments. Please, do not use method directly,
    # but rather use one of the definitions that follow below this.
    mutationSummary: external (selector, callback) ->
        noSelector = "got no valid selector for mutations"
        noCallback = "no valid callback function is given"
        noLibrary = "mutation-summary library is missing"
        assert _.isFunction(try MutationSummary), noLibrary
        assert _.isFunction(c = callback or null), noCallback
        assert _.isString(s = selector or null), noSelector
        assert instruct = try queries: [element: selector]
        _.head(instruct.queries).elementAttributes = false
        pp = "watch mutation of %s selector for #{@service}"
        try logger.info pp.toString(), selector.toString()
        make = -> observer = new MutationSummary instruct
        creator = (fn) -> instruct.callback = fn; make()
        return creator.call this, callback or _.noop

    # Pinpoint when the specified selector vanishes (is reparented or
    # moved) and then invoke the supplied rendering function, which
    # will receive the newly pinpointed node as its first argument.
    # If multiple nodes with this selector vanished, then renderer
    # will be invoked once for every disappeared node of a selector.
    # Selectors must conform to the strict subset of CSS selectors.
    @parented: @transferred (selector, renderer) ->
        noSelector = "no valid CSS selector is supplied"
        noRenderer = "no valid rendering function given"
        assert _.isFunction(renderer or null), noRenderer
        assert _.isString(sel = selector or 0), noSelector
        go = (n) => try $(n).data("owners") or new Array()
        @mutationSummary sel, (s) => _.each s, (summary) =>
            na = "missing the element reparented summary"
            pe = "reparenting %s elements for %s service"
            assert _.isArray(moved = summary.reparented), na
            return unless (try moved.length or null) > 0
            try logger.info pe, moved.length, this.service
            $(nod).data owners: go(nod) for nod in moved
            go(nod).push this for nod in moved or Array()
            _.each moved, (n) => renderer.call @, n, go n

    # Pinpoint when the specified selector vanishes (is removed or
    # detach) and then invoke the supplied rendering function, which
    # will receive the newly pinpointed node as its first argument.
    # If multiple nodes with this selector vanished, then renderer
    # will be invoked once for every disappeared node of a selector.
    # Selectors must conform to the strict subset of CSS selectors.
    @vanished: @transferred (selector, renderer) ->
        noSelector = "no valid CSS selector is supplied"
        noRenderer = "no valid rendering function given"
        assert _.isFunction(renderer or null), noRenderer
        assert _.isString(sel = selector or 0), noSelector
        go = (n) => try $(n).data("owners") or new Array()
        @mutationSummary sel, (s) => _.each s, (summary) =>
            na = "missing the element vanishing summary"
            pe = "vanishing %s elements for %s service"
            assert _.isArray(moved = summary.removed), na
            return unless (try moved.length or null) > 0
            try logger.info pe, moved.length, this.service
            $(nod).data owners: go(nod) for nod in moved
            go(nod).push this for nod in moved or Array()
            _.each moved, (n) => renderer.call @, n, go n

    # Pinpoint when the specified selector appears (or if it already
    # exists) and then invoke the supplied rendering function, which
    # will receive the newly pinpointed node as its first argument.
    # If multiple nodes with this selector is found, then renderer
    # will be invoked once for every discovered node of a selector.
    # Selectors must conform to the strict subset of CSS selectors.
    @pinpoint: @transferred (selector, renderer) ->
        noSelector = "no valid CSS selector is supplied"
        noRenderer = "no valid rendering function given"
        assert _.isFunction(renderer or null), noRenderer
        assert _.isString(sel = selector or 0), noSelector
        go = (n) => try $(n).data("owners") or new Array()
        @mutationSummary sel, (s) => _.each s, (summary) =>
            na = "missing the element addition summary"
            pe = "pinpointed %s elements for %s service"
            assert _.isArray(added = summary.added), na
            return unless (try added.length or null) > 0
            try logger.info pe, added.length, this.service
            $(nod).data owners: go(nod) for nod in added
            go(nod).push this for nod in added or Array()
            _.each added, (n) => renderer.call @, n, go n
