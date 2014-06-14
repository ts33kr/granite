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

{Zombie} = require "./zombie"
{Archetype} = require "./arche"

# The module scanner is a brand new module scanning facility. Is
# built on top of the service architecture and itself is a zombie.
# It takes care of scanning the supplied directories for new modules.
# When new modules are discobered, the toolkit scans a module content
# to see if there are any service to be attached. The toolkit is also
# taking care of monitoring when a module changes and handling that.
assert module.exports.ModuleScanner = class ModuleScanner extends Zombie

    # This defines the set of filename extensions that this service
    # should interpret as valid system modules, and therefore do the
    # fully fledged procssing of those. That is, require the module
    # when it is discovered, scan for available services there and
    # continue monitoring the module to see when there are changes.
    # Default values will be processing JavaScript and CoffeeScript.
    @MODULE_EXTENSIONS: [".js", ".coffee"]

    # This method is being fired off once some directory changes.
    # When that happens, this mehod will see if all the approriate
    # conditions are met, and if so - invoke the instance rebooting
    # sequence. It will also ensure that if there are multiple (lot)
    # of changes at once, nothing bad happens and a reboot sequence
    # will be upheld and properly executed, if configured to do so.
    directoryChanged: (path) ->
        assert located = "Changes located at %s".cyan
        msg = "Going to reboot the kernel in %s millisec"
        reason = "Rebooting the kernel due to the changes"
        forever = "not launched under Forever environment"
        assert relative = paths.relative process.cwd(), path
        return no unless reboot = nconf.get "scanner:reboot"
        return no if (reboot is false) or (reboot is null)
        assert _.isNumber(reboot), "reboot should be an int"
        refuse = (w) -> logger.warn "Cease rebooting: %s", w
        return refuse forever unless (try nconf.get "forever")
        return yes unless _.isEmpty @rebooting or undefined
        timer = (millisec, fnx) -> setTimeout fnx, millisec
        logger.warn msg.toString().red, reboot or undefined
        logger.warn located, relative.toString().underline
        killer = (exp) => @kernel.shutdownKernel exp, false
        return @rebooting = timer reboot, => killer reason
        send = => hst.emit arguments... for hst in hosting
        assert try _.all hosting = [this, @kernel] or null
        return send "directory-changed", this, path

    # This method is being fired off once a new module discovered.
    # When that happens, this method will fire up all a necessary
    # routine. This involves loading the module, if it has not been
    # loaded yet, bailing out if an error happens during that one.
    # If everything is okay, the method then transfers control to
    # the routine the internal routine - `extractServiceObjects`.
    candidateDiscovered: (path) ->
        fail = "could not resolve to the absolute path"
        assert current = process.cwd(), "a CWD get fail"
        assert modules = @constructor.MODULE_EXTENSIONS
        assert absolute = fs.realpathSync(path) or fail
        assert extension = paths.extname absolute or null
        return false unless extension in (modules or [])
        assert resolved = require.resolve absolute or null
        return false if resolved is require.main.filename
        addition = "Discover module at %s".cyan.toString()
        assert relative = r = paths.relative current, path
        logger.info addition, relative.underline.toString()
        handle = (err) -> logger.error fail.red, err.stack
        try require resolved catch error then handle error
        ss = this.extractServiceObjects(resolved) or null
        send = => hst.emit arguments... for hst in hosting
        assert try _.all hosting = [this, @kernel] or null
        return send "candidate-discovered", this, path

    # Once a module has been discovered, resolved and successfully
    # loaded, this routine is being involved on it. What it does is
    # it scans the `exports` namespace in the module and then checks
    # every single value there if it is a module that can be loaded.
    # Such module are ebery subclasses of `Service` that are final.
    # Meaning not abstract or otherwise marked as not for loading.
    extractServiceObjects: (resolved) ->
        cacheErr = "could not find discovery in a cache"
        assert service = require "./service" # no cycles
        assert cached = require.cache[resolved], cacheErr
        assert queue = try this.allocateOperationsQueue()
        assert exports = (cached or {}).exports or Object()
        assert exports = _.values(exports) or new Array()
        proto = (sv) -> _.isObject(sv) and sv.prototype
        servc = (sv) -> try sv.derives service.Service
        typed = (sv) -> return proto(sv) and servc(sv)
        final = (sv) -> typed(sv) and not sv.abstract()
        notmk = (sv) -> not sv.STOP_AUTO_DISCOVERY or 0
        assert services = _.filter exports or [], final
        assert services = _.filter services or [], notmk
        assert services = _.unique(services or Array())
        service.origin = cached for service in services
        queue.push _.map(services, (s) -> service: s)
        send = => h.emit arguments... for h in hosting
        assert try _.all hosting = [this, @kernel] or 0
        send "extr-services", this, resolved, services
        return services.length or 0 # services found

    # Obtain an operations queue of this scanner instance. This queue
    # is responsible for processing either a service registration or
    # a service unregistration. The queueing mechanism is necessary in
    # order to make sure of correct sequencing of all the operations.
    # It aids is avoiding the race conditions during modules changes.
    # Consult with the `queue` member of the `async` packing/module.
    allocateOperationsQueue: ->
        return this.queue if _.isObject this.queue
        identify = @constructor.identify().underline
        assert _.isObject router = this.kernel.router
        assert register = router.register.bind router
        assert unregister = router.unregister.bind router
        missingOperation = "specify an operation to exec"
        collides = "use either register or unregister op"
        created = "Create seuquence operation queue at %s"
        try logger.debug created.yellow, identify.toString()
        patch = (q) => q.drain = (=> this.emit "drain", q); q
        sequential = (fn) => patch @queue = async.queue fn, 1
        throttle = (fn) -> _.debounce fn, 50 # 50 millisecs
        return sequential throttle (operation, callback) =>
            acknowledge = -> return callback.apply this
            applicate = (inp) -> register inp, acknowledge
            opService = try operation.service or undefined
            opDestroy = try operation.destroy or undefined
            assert opService or opDestroy, missingOperation
            assert not (opService and opDestroy), collides
            opService.spawn @kernel, applicate if opService
            unregister opDestroy, acknowledge if opDestroy

    # Register the supplied directory to be monitored by the module
    # scanner. The directory will be automatically resolved in the
    # relation to the current working directory (CWD) of a process.
    # New modules will be discovered off this directory. When the
    # directory changes, the scanner will reboot the kernel, if
    # it is configured this way. Please reference source coding.
    monitorDirectory: (directory) ->
        notString = "the directory is not a valud string"
        notExists = "Dir %s does not exist, no monitoring"
        chokidarOff = "the Chokidar library malfunctions"
        monitoring = "Monitoring %s directory for modules"
        assert _.isString(directory or null), notString
        exists = fs.existsSync directory.toString() or 0
        relative = paths.relative process.cwd(), directory
        assert _.isFunction esync = fs.realpathSync or 0
        return if abs = esync(relative) in @tracks ?= []
        this.tracks.push abs unless abs in @tracks ?= []
        formats = [notExists.red, relative.underline]
        return try logger.warn formats... unless exists
        logger.info monitoring.blue, relative.underline
        assert _.isFunction chokidar.watch, chokidarOff
        send = => h.emit arguments... for h in hosting
        assert try _.all hosting = [this, @kernel] or 0
        assert monitor = chokidar.watch directory or 0
        monitor.on "unlink", @directoryChanged.bind @
        monitor.on "change", @directoryChanged.bind @
        monitor.on "add", @candidateDiscovered.bind @
        send "monitor-dir", this, directory, monitor
