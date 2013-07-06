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
events = require "events"
colors = require "colors"
nconf = require "nconf"
paths = require "path"
https = require "https"
http = require "http"
util = require "util"
fs = require "fs"

_ = require "lodash"
routing = require "./routing"
service = require "./service"
augment = require "./augment"

# Watcher is responsible for automatic discovery and hot loading of
# the modules that contain services. It can be configured to watch
# only specific directories. It also features automatic reloading
# that takes care of unregistering and registering the services.
module.exports.Watcher = class Watcher extends events.EventEmitter

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
        return if resolved is entrypoint
        return if resolved of require.cache
        go = => @reviewServices resolved
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
        delete require.cache[resolved] if cached
        go = => @reviewServices resolved
        try require resolved; go() catch error
            message = "Exception in module at #{path}:\r\n%s"
            logger.warn message.red, error.stack
            @hotSwappingUnlink path

    # This method will be invoked by the file system watcher on
    # the event when modules are either being removed from dir.
    # It takes care of either initial loading and registering of
    # services or the hot swapping of the services that changed.
    hotSwappingUnlink: (path) ->
        absolute = fs.realpathSync path
        modules = @constructor.EXTENSIONS
        extension = paths.extname absolute
        return unless extension in modules
        registry = @kernel.router?.registry or []
        originate = (s) -> s.constructor.origin?.filename
        predicate = (s) -> originate(s) is absolute
        previous = _.filter registry, predicate
        prev.unregister() for prev in previous

    # Given the freshly resolved module, require it and then run the
    # collector on it to find all services it may be defining. Then
    # traverse all of the services, and register those with router.
    # If a service is previously registered, it will be unregistered.
    reviewServices: (resolved) ->
        cached = require.cache[resolved]
        services = @collectServices cached
        registry = @kernel.router?.registry or []
        originate = (s) -> s.constructor.origin?.id
        predicate = (s) -> originate(s) is resolved
        previous = _.filter registry, predicate
        prev.unregister() for prev in previous
        srv.origin = cached for srv in services
        register = @kernel.router.registerRoutable
        register = register.bind @kernel.router
        spawn = (s) => register new s @kernel
        distincted = _.unique services
        spawn s for s in distincted

    # Given the required module, scan the `exports` object that it
    # publishes and find all the possible services that it defines.
    # This find regular services as well as augmented services. It
    # should be used only by the watcher internals, not directly.
    collectServices: (required) ->
        exports = _.values (required.exports or [])
        isService = (s) -> s instanceof service.Service
        isAugment = (s) -> s.augment instanceof augment.Augment
        augments = _.filter exports, isAugment
        augments = augments.map (a) -> a.service
        services = _.filter exports, isService
        services = _.merge services, augments

    # Watch the specified directory for addition and changing of
    # the files, looking for modules with services there and then
    # loading them and reloading and doing all other routines for
    # managing the hot swapping of the services inside modules.
    watchDirectory: (directory) ->
        notString = "The directory is not a string"
        notExists = "Dir %s does not exist, not watching"
        exists = fs.existsSync directory.toString()
        throw new Error(notString) unless _.isString directory
        logger.warn notExists.red, directory unless exists
        logger.info "Watching %s dir for modules".blue, directory
        watcher = chokidar.watch directory.toString()
        watcher.on "unlink", @hotSwappingUnlink.bind @
        watcher.on "change", @hotSwappingChange.bind @
        watcher.on "add", @hotSwappingAdd.bind @
