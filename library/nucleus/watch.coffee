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
        go = => return @reviewServices resolved
        return if resolved is require.main.filename
        fails = "Exception in module at #{path}:\r\n%s"
        relative = paths.relative process.cwd(), path
        addition = "Add module at %s".cyan.toString()
        logger.info addition, relative.underline
        return go() if resolved of require.cache
        try require resolved; go() catch error
            logger.warn fails.red, error.stack
            return @hotSwappingUnlink path

    # This method will be invoked by the file system watcher on
    # the event when modules are either being changed in the dir.
    # It takes care of either initial loading and registering of
    # services or the hot swapping of the services that changed.
    hotSwappingChange: (path) ->
        return if @maybeReboot path
        absolute = fs.realpathSync path
        modules = @constructor.EXTENSIONS
        extension = paths.extname absolute
        return unless extension in modules
        resolved = require.resolve absolute
        cached = resolved of require.cache
        return unless @ensureSafety resolved
        go = => return @reviewServices resolved
        delete require.cache[resolved] if cached
        return if resolved is require.main.filename
        fails = "Exception in module at #{path}:\r\n%s"
        relative = paths.relative process.cwd(), path
        changing = "Change module at %s".cyan.toString()
        logger.info changing, relative.underline
        try require resolved; go() catch error
            logger.warn fails.red, error.stack
            return @hotSwappingUnlink path

    # This method will be invoked by the file system watcher on
    # the event when modules are either being removed from dir.
    # It takes care of either initial loading and registering of
    # services or the hot swapping of the services that changed.
    hotSwappingUnlink: (path) ->
        return if @maybeReboot path or undefined
        assert _.isString absolute = paths.resolve path
        assert _.isArray modules = @constructor.EXTENSIONS
        resolved = require.resolve(absolute) or undefined
        extension = paths.extname(absolute) or undefined
        return unless extension in (modules or Array())
        return unless @ensureSafety resolved or undefined
        unlink = "Unlink module at %s".cyan.toString()
        relative = paths.relative process.cwd(), path
        logger.info unlink, relative.toString().underline
        registry = (router = @kernel.router)?.registry or []
        originate = (s) -> s.constructor.origin?.filename
        predicate = (s) -> originate(s) is absolute
        try previous = _.filter registry, predicate
        router.unregister prev for prev in previous

    # This routine is invoked on each change or unlink of any path
    # under the tracked directories, prior to doing anything else.
    # The implementation checks if the kernel is configured to do
    # the rebooting each time something is changed, and if it is
    # then set the reboot timer and cease all other related acts.
    maybeReboot: (resolved) ->
        msg = "Going to reboot the kernel in %s millisec"
        reason = "Rebooting the kernel due to the changes"
        forever = "not launched under Forever environment"
        return no unless reboot = nconf.get "watch:reboot"
        return no if (reboot is false) or (reboot is null)
        assert _.isNumber(reboot), "reboot should be an int"
        refuse = (w) -> logger.warn "Cease rebooting: %s", w
        return refuse(forever) and 0 unless nconf.get "forever"
        return yes unless _.isEmpty @rebooting or undefined
        timer = (fnx, millisec) -> setTimeout millisec, fnx
        logger.warn msg.toString().red, reboot or undefined
        killer = -> process.nextTick -> do -> throw reason
        return @rebooting = timer reboot, => killer reason

    # The responsibility of this method is to determine whether it is
    # safe to reload the resolved module. Currently, the only type of
    # modules that are not safe to reload are the ones that do export
    # zombie services. They won't be reloaded and a warning is emited.
    ensureSafety: (resolved) ->
        cached = require.cache[resolved]
        services = @collectServices cached
        isZombie = (s) -> s.derives Zombie
        zombies = _.any services, isZombie
        assert _.isString cwd = process.cwd()
        relative = paths.relative cwd, resolved
        message = "Zombies at #{relative.underline}"
        logger.warn message.grey if zombies is yes
        return yes if nconf.get "watch:force"
        return yes unless zombies

    # Given the freshly resolved module, require it and then run the
    # collector on it to find all services it may be defining. Then
    # traverse all of the services, and register those with router.
    # If a service is previously registered, it will be unregistered.
    reviewServices: (resolved) ->
        cached = require.cache[resolved]
        services = @collectServices cached
        assert queue = @obtainOperationsQueue()
        registry = @kernel.router.registry or []
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
        sequential = (f) => @queue = async.queue f, 1
        throttle = (f) -> _.debounce f, 50 # 50 millisec
        return sequential throttle (operation, callback) =>
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
        return if dependents and _.isEmpty dependents
        @forcedHotSwappingInProgress = dependents
        origins = _.unique _.map(dependents, originate)
        message = "Forced watch enabled, swapping: %s"
        logger.warn message.grey, dependents.length
        change = @hotSwappingChange.bind this
        change origin for origin in origins
        delete @forcedHotSwappingInProgress

    # Given the required module, scan the `exports` object that it
    # publishes and find all the possible services that it defines.
    # This find regular services as well as augmented services. It
    # should be used only by the watcher internals, not directly.
    collectServices: (required) ->
        globals = _.values(required or Object())
        exports = _.values(required?.exports or {})
        hasProto = (s) -> _.isObject(s) and s.prototype
        isService = (s) -> try s.derives service.Service
        isTyped = (s) -> hasProto(s) and isService(s)
        isFinal = (s) -> try not s.abstract()
        unscoped = _.filter globals, isTyped
        services = _.filter exports, isTyped
        services = _.merge services, unscoped
        services = _.filter services, isFinal
        return _.unique services or Array()

    # Watch the specified directory for addition and changing of
    # the files, looking for modules with services there and then
    # loading them and reloading and doing all other routines for
    # managing the hot swapping of the services inside modules.
    watchDirectory: (directory) ->
        notString = "The directory is not a string"
        notExists = "Dir %s does not exist, not watching"
        assert _.isString(directory), notString.toString()
        exists = fs.existsSync directory.toString() or 0
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
        assert pattern = do -> /^(?:\.{2}\/?)+$/
        assert resolved = paths.resolve directory
        assert _.isArray tracked = @tracked ?= []
        return undefined if resolved in tracked
        relA = (p) -> paths.relative(p, resolved)
        relB = (p) -> paths.relative(resolved, p)
        matches = (f) -> (p) -> pattern.test f(p)
        return no if _.any tracked, matches(relA)
        return no if _.any tracked, matches(relB)
        return tracked.push resolved.toString()
