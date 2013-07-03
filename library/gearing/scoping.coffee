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
connect = require "connect"
logger = require "winston"
events = require "events"
colors = require "colors"
nconf = require "nconf"
util = require "util"
fs = require "fs"

# This is a primary gateway interface for the framework. This class
# provides methods and routines necessary to bootstrap the framework
# and the end user application constructed within the framework. It
# is both an abstract base class as well as a ready to use bootstrap.
# Please refer to the documentation of the methods for more info.
module.exports.Scope = class Scope extends events.EventEmitter

    # Construct a new scope, using the supplied tag (a short name)
    # and a synopsis (short description of the scope) parameters.
    # The constructor of the scope should only associate the data.
    # The scope startup logic should be implemented in the method.
    constructor: (tag, synopsis) ->
        @tag = tag if _.isString(tag)
        @synopsis = synopsis if _.isString(synopsis)
        @directory = @::DIRECTORY or __dirname
        initializer = find(arguments, _.isFunction)
        initializer?.call(@, tag, synopsis)

    # Push the current scope instance into the global registry
    # of scopes, unless this instance already exists there. This
    # registry exists for easing looking up the scope by its tag.
    # You may provide a number of aliaes for this scope instance.
    pushToRegistry: (override, aliases...) ->
        registry = @constructor.REGISTRY ?= {}
        existent = (tag) -> tag of registry and not override
        valids = _.filter(aliases, (a) -> not existent(a))
        registry[@tag] = this unless existent(@tag)
        registry[alias] = this for alias in valids

    # Lookup the possibly existent scope with one of the following
    # alises as a tag. If no matching candidates exist, the method
    # will fail with en error, since this is considered a critical
    # error. You should always use this method instead of manual.
    @lookupOrFail: (aliases...) ->
        registry = @REGISTRY ?= {}; joined = aliases.join(", ")
        notFound = "Could not found any of #{joined} scoped"
        logger.info("Looking up any of #{joined} scopes".grey)
        found = (v for own k, v of registry when k in aliases)
        throw new Error(notFound) unless found.length > 0
        _.head(found)

    # This method is responsible for starting up the scope object.
    # This means initialization of all its necessary routines and
    # setting up whatever this scope needs to set. The default
    # implementation takes care only of loading the proper config.
    incorporate: (kernel) ->
        fpath = "#{@directory}/#{@tag}.json"
        nconf.defaults(@defaults or @::DEFAULTS or {})
        nconf.overrides(@overrides or @::OVERRIDES or {})
        logger.info("Starting up the #{tag} scope".cyan)
        logger.info("Loading the #{fpath} config".cyan)
        exists = fs.existsSync fpath
        nconf.file fpath if exists

    # This method is responsible for shutting down the scope object.
    # This means stripping down all the necessary routines and other
    # resources that are mandated by this this scope object. Default
    # implementation does not do almost anything, so it is up to you.
    disperse: (kernel) ->
        fpath = "#{@directory}/#{@tag}.json"
        logger.info("Dissipating the #{@tag} scope".grey)
        logger.info("Scope used #{fpath} for config".grey)
