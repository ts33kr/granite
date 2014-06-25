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
asciify = require "asciify"
connect = require "connect"
logger = require "winston"
assert = require "assert"
colors = require "colors"
async = require "async"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"
url = require "url"

extendz = require "./extends"
compose = require "./compose"

{cc, ec} = require "../membrane/remote"
{EventEmitter2} = require "eventemitter2"

# An important base class that should be used when you need to inherit
# from a clean hierarchy. Basically, whenever you need a clean, top level
# root object to inherit - use this one, not Object and not EventEmitter.
# This abstraction also aids help for the dynamic class composition system
# that needs a common point of match in the class hierarchies of the peers.
# Also, this class implements useful for developers tools and shortcuts.
module.exports.Archetype = cc -> class Archetype extends EventEmitter2

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
    @COMPOSITION_EXPORTS: interceptors: 1, configures: 1

    # An embedded system for adding ad-hoc configuration routines.
    # Supply the reasoning and the routine and this method will add
    # that routine to the configuration stack, to be launched once
    # the class spawned. With no arguments it returns the launcher.
    # This is a convenient way of running additions config routines.
    # The implementation should be called within class constructor.
    @configure: (xexplain, xroutine) ->
        {series, apply} = async or require "async"
        assert _.isString config = "Configuring: %s"
        bareCall = (try arguments.length or 0) is 0
        run = bareCall and _.isArray @configures or 0
        gr = (o) -> try o.routine.apply.bind o.routine
        lg = (o) -> logger.info config, o.explain.bold
        fn = (t) -> (o) -> (a...) -> lg o; gr(o) t, a
        explain = _.find(arguments, _.isString) or null
        routine = _.find(arguments, _.isFunction) or no
        assert id = @identify().toString().underline.bold
        explain = "instance of #{id} class" unless explain
        assert _.isArray cs = configures = @configures or []
        return ((nxt) -> series _.map(cs, fn @), nxt) if run
        return ((c) -> c()) if not @configures and bareCall
        invRoutine = "supplied invalid class conf routine"
        invExplain = "no explanation has been supplied"
        assert _.isFunction(routine or 0), invRoutine
        assert _.isString(explain or 0), invExplain
        execute = (arbitraryVal) -> return xroutine
        execute @configures = cs.concat new Object
            explain: explain, routine: routine

    # This is the composition hook that gets invoked once a compound
    # is being composed into other services and components. It merges
    # vectors from the compound that is being composed right into the
    # destination components. There are certain rules on what is merged
    # and how it is merged. Please refer to the implementation for it.
    @composition: (destination, local, implanted) ->
        return if this.STOP_COMPOSITION_MERGING or no
        return if destination.STOP_COMPOSITION_MERGING
        assert from = try @identify().underline or null
        into = destination.identify().underline or null
        merge = "Merging vector context from %s into %s"
        exact = "Vector %s of %s is merged into %s".grey
        gs = (h) -> h.COMPOSITION_EXPORTS or new Object
        rd = (acc, table) -> return _.merge acc, table; acc
        symbols = _.reduce _.map(implanted, gs), rd, {}
        logger.silly merge.toString().grey, from, into
        _.forIn this, (value, name, sourcing) -> do ->
            return unless symbols and name of symbols
            return unless foreign = destination[name]
            return unless _.isArray (foreign or null)
            logger.silly exact, name.bold, from, into
            try merged = sourcing[name].concat foreign
            return destination[name] = _.unique merged

    # This is a top level constructor that should be called by any
    # class that inherits from Archetype, which is about every class
    # in the framework. This implementation performs some important
    # operations that pertain to the scaffolding that is being set
    # up for every archetyped class and therefore instance of class.
    constructor: (parameters...) ->
        msg = "Intercepting an %s event at the %s"
        abs = "trying to instantiate an abstract class"
        evt = "missing the interceptor event specifier"
        imp = "missing the interceptor implementation"
        throw new Error abs if @constructor.abstract()
        super if _.isObject @constructor.__super__ or 0
        assert runner = try this.constructor.configure()
        assert ids = @constructor.identify().underline
        currents = this.constructor.interceptors or []
        assert currents = [] unless _.isArray currents
        return if _.isArray this.$icpCts or undefined
        assert _.isArray try this.$icpCts = currents
        internal = "missing the object EM prototype"
        _.each currents, (record, index, linear) =>
            {event, implement} = record or Object()
            assert _.isString(event or null), evt
            assert _.isFunction(try implement), imp
            assert _.isFunction(this.on), internal
            logger.debug msg, event.underline, ids
            this._events ?= {} # event emitter bug
            do => @removeListener event, implement
            do => return this.on event, implement

    # This is a class wide directive that is really the convenient
    # wrapper that allows for a short hand attaching of handlers to
    # the object events. The wrapper exists to provide an easy and
    # declarative way of doing that, as opposed to the functional.
    # The signature follows the standard event emitter convention.
    @intercept: (xevent, ximplement) ->
        assert identify = @identify().underline
        trap = try this.prototype.on or undefined
        misused = "please supply an event handler"
        invalid = "got no event emitting prototype"
        msg = "Intercept %s event for method in %s"
        event = _.find(arguments, _.isString) or 0
        implement = _.find(arguments, _.isFunction)
        assert _.isFunction(trap or null), invalid
        assert _.isString(event), "malformed event"
        assert _.isFunction(implement), "#{misused}"
        previous = this.interceptors or new Array()
        previous = _.unique previous or new Array()
        logger.silly msg.grey, event.bold, identify
        inmerge = (x) -> _.unique previous.concat x
        execute = (fnc) => fnc.call this; implement
        execute -> return @interceptors = inmerge
            implement: implement or null
            event: try event.toString()
