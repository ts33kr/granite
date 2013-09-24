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

chokidar = require "chokidar"
asciify = require "asciify"
connect = require "connect"
logger = require "winston"
colors = require "colors"
assert = require "assert"
async = require "async"
nconf = require "nconf"
paths = require "path"
https = require "https"
http = require "http"
util = require "util"
fs = require "fs"

_ = require "lodash"
extendz = require "./extends"
routing = require "./routing"
service = require "./service"

{Zombie} = require "./zombie"
{Archetype} = require "./archetype"

# Watcher is responsible for automatic discovery and hot loading of
# the modules that contain services. It can be configured to watch
# only specific directories. It also features automatic reloading
# that takes care of unregistering and registering the services.
module.exports.Watcher = class Watcher extends Archetype

    # This defines the set of filename extensions that will be
    # interpreted by the watcher as valid modules and therefore
    # process by the watching. Meaning adding it to the watch
    # list and enabling the hot swapping of modules and services.
    @EXTENSIONS = [".js", ".coffee"]

    # The public constructor for the watcher. It should never be
    # used directly. The watcher is entirely operated by kernel
    # and therefore its the responsibility of the kernel to do
    # the management of the lifecyle of the watcher and others.
    constructor: (@kernel) ->

    # This method will be invoked by the file system watcher on
    # the event when modules are either being added to the dir.
    # It takes care of either initial loading and registering of
    # services or the hot swapping of the services that changed.
    hotSwappingAdd: (path) ->
        absolute = fs.realpathSync path
        modules = @constructor.EXTENSIONS
        extension = paths.extname absolute
        return unless extension in modules
        resolved = require.resolve absolute
        entrypoint = require.main.filename
        go = => @reviewServices resolved
        return if resolved is entrypoint
        relative = paths.relative process.cwd(), path
        logger.info "Addition at %s".cyan, relative.underline
        return go() if resolved of require.cache
        try require resolved; go() catch error
            message = "Exception in module at #{path}:\r\n%s"
            logger.warn message.red, error.stack
            @hotSwappingUnlink path

    # This method will be invoked by the file system watcher on
    # the event when modules are either being changed in the dir.
    # It takes care of either initial loading and registering of
    # services or the hot swapping of the services that changed.
    hotSwappingChange: (path) ->
        absolute = fs.realpathSync path
        modules = @constructor.EXTENSIONS
        extension = paths.extname absolute
        return unless extension in modules
        resolved = require.resolve absolute
        cached = resolved of require.cache
        entrypoint = require.main.filename
        return if resolved is entrypoint
        return unless @ensureSafety resolved
        delete require.cache[resolved] if cached
        go = => @reviewServices resolved
        relative = paths.relative process.cwd(), path
        logger.info "Changing at %s".cyan, relative.underline
        try require resolved; go() catch error
            message = "Exception in module at #{path}:\r\n%s"
            logger.warn message.red, error.stack
            @hotSwappingUnlink path

    # This method will be invoked by the file system watcher on
    # the event when modules are either being removed from dir.
    # It takes care of either initial loading and registering of
    # services or the hot swapping of the services that changed.
    hotSwappingUnlink: (path) ->
        absolute = paths.resolve path
        modules = @constructor.EXTENSIONS
        extension = paths.extname absolute
        return unless extension in modules
        relative = paths.relative process.cwd(), path
        logger.info "Unlinking at %s".cyan, relative.underline
        registry = (router = @kernel.router)?.registry or []
        originate = (s) -> s.constructor.origin?.filename
        predicate = (s) -> originate(s) is absolute
        previous = _.filter registry, predicate
        router.unregister prev for prev in previous

    # The responsibility of this method is to determine whether it is
    # safe to reload the resolved module. Currently, the only type of
    # modules that are not safe to reload are the ones that do export
    # zombie services. They won't be reloaded and a warning is emited.
    ensureSafety: (resolved) ->
        cached = require.cache[resolved]
        services = @collectServices cached
        isZombie = (s) -> s.inherits Zombie
        zombies = _.any services, isZombie
        assert _.isString cwd = process.cwd()
        relative = paths.relative cwd, resolved
        message = "Zombies at #{relative.underline}"
        logger.warn message.grey if zombies
        return yes unless zombies

    # Given the freshly resolved module, require it and then run the
    # collector on it to find all services it may be defining. Then
    # traverse all of the services, and register those with router.
    # If a service is previously registered, it will be unregistered.
    reviewServices: (resolved) ->
        cached = require.cache[resolved]
        services = @collectServices cached
        assert queue = @obtainOperationsQueue()
        registry = (router = @kernel.router)?.registry or []
        originate = (s) -> s.constructor.origin?.id
        predicate = (s) -> originate(s) is resolved
        previous = _.filter registry, predicate
        _.each services, (s) -> s.origin = cached
        queue.push _.map(previous, (s) -> instance: s)
        queue.push _.map(services, (s) -> service: s)
        @attemptForceHotswap cached; return this

    # Obtain an operations queue of this watcher instance. This queue
    # is responsible for processing either a service registration or
    # a service unregistration. The queueing mechanism is necessary in
    # order to make sure of correct sequencing of all the operations.
    # It aids is avoiding the race conditions during modules changes.
    obtainOperationsQueue: ->
        assert router = @kernel.router
        return @queue if _.isObject @queue
        register = router.register.bind router
        unregister = router.unregister.bind router
        collides = "use either register or unregister"
        missingOperation = "specify an operation to do"
        @queue = async.queue (operation, callback) =>
            acknowledge = -> callback.apply this
            applicate = (i) -> register i, acknowledge
            opService = operation.service or undefined
            opInstance = operation.instance or undefined
            assert opService or opInstance, missingOperation
            assert not (opService and opInstance), collides
            unregister opInstance, acknowledge if opInstance
            opService.spawn @kernel, applicate if opService

    # If enabled by the scoping configuration, this method will try
    # to hotswap and reload all modules and services that have been
    # loaded by the watcher. This is useful to reload modules and
    # services when other modules (possible dependencies) change.
    attemptForceHotswap: (cached) ->
        return unless nconf.get "watch:force"
        return if @forcedHotSwappingInProgress
        registry = @kernel.router?.registry or []
        originate = (s) -> s.constructor.origin?.id
        predicate = (s) -> originate(s) isnt cached.id
        dependents = _.filter registry, predicate
        dependents = _.filter dependents, originate
        return unless dependents.length > 0
        @forcedHotSwappingInProgress = dependents
        message = "Forced watch enabled, swapping services: %s"
        logger.warn message.grey, dependents.length
        change = @hotSwappingChange.bind this
        change originate dep for dep in dependents
        delete @forcedHotSwappingInProgress

    # Given the required module, scan the `exports` object that it
    # publishes and find all the possible services that it defines.
    # This find regular services as well as augmented services. It
    # should be used only by the watcher internals, not directly.
    collectServices: (required) ->
        globals = _.values(required or {})
        exports = _.values(required.exports or {})
        hasProto = (s) -> _.isObject(s) and s.prototype
        isService = (s) -> try s.inherits service.Service
        isTyped = (s) -> hasProto(s) and isService(s)
        isFinal = (s) -> not s.abstract()
        unscoped = _.filter globals, isTyped
        services = _.filter exports, isTyped
        services = _.merge services, unscoped
        services = _.filter services, isFinal
        return _.unique services

    # Watch the specified directory for addition and changing of
    # the files, looking for modules with services there and then
    # loading them and reloading and doing all other routines for
    # managing the hot swapping of the services inside modules.
    watchDirectory: (directory) ->
        notString = "The directory is not a string"
        notExists = "Dir %s does not exist, not watching"
        assert _.isString(directory), notString
        exists = fs.existsSync directory.toString()
        relative = paths.relative process.cwd(), directory
        formats = [notExists.grey, relative.underline]
        return unless @directoryTracking directory
        return logger.warn formats... unless exists
        watching = "Watching %s directory for modules"
        logger.info watching.blue, relative.underline
        watcher = chokidar.watch directory.toString()
        watcher.on "unlink", @hotSwappingUnlink.bind @
        watcher.on "change", @hotSwappingChange.bind @
        watcher.on "add", @hotSwappingAdd.bind @

    # Directory tracking routine keeps inventory of all directories
    # that have been added to the watcher. Besides that it is called
    # upon an addition of a new directory to ensure that the directory
    # does not intersect with any directories that already present.
    directoryTracking: (directory) ->
        tracked = @tracked ?= []
        pattern = /^(?:\.{2}\/?)+$/
        resolved = paths.resolve directory
        return undefined if resolved in tracked
        relA = (p) -> paths.relative(p, resolved)
        relB = (p) -> paths.relative(resolved, p)
        matches = (f) -> (p) -> pattern.test f(p)
        return no if _.any tracked, matches(relA)
        return no if _.any tracked, matches(relB)
        tracked.push resolved.toString()
