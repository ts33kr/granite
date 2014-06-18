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
moment = require "moment"
assert = require "assert"
colors = require "colors"
crypto = require "crypto"
nconf = require "nconf"
https = require "https"
path = require "path"
http = require "http"
util = require "util"
fs = require "fs"

{Barebones} = require "./skeleton"
{rmdirSyncRecursive} = require "wrench"

# This abstract base class provides the dynamic Bower support for
# the services that inherit or compose this ABC. This implementation
# allows for each service to have its own, isolated tree of packages
# that will be dynamically installed via Bower package manager. The
# implementation provides convenient way of requiring frontend libs.
# Please refer to the implementation for details on the mechanics.
module.exports.BowerToolkit = class BowerToolkit extends Barebones

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # This class definition can be used to override the mechanisms
    # that determine the location of the Bower collection directory
    # of this service. That is, where all the Bower packages will be
    # installed. Default is `undefined`, which will lead mechanism to
    # use a separate directory for this service. The directory will
    # have the name of the service internal, MD5 referential tagging.
    @BOWER_DIRECTORY: undefined

    # Symbol declaration table, that states what keys, if those are
    # vectors (arrays) should be exported and then merged with their
    # counterparts in the destination, once the composition process
    # takes place. See the `Archetype::composition` hook definition
    # for more information. Keys are names, values can be anything.
    @COMPOSITION_EXPORTS: bowerings: yes

    # A hook that will be called prior to registering the service
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    register: (kernel, router, next) ->
        assert isf = _.isFunction # just a shorthand
        explicit = try @BOWER_DIRECTORY or undefined
        explicit = explicit.call this if isf explicit
        assert isolate = "%s at %s".cyan # long paths
        assert disposition = @constructor.disposition()
        assert reference = disposition.reference or null
        assert not _.isEmpty idc = explicit or reference
        assert _.isObject(kernel), "got no kernel object"
        assert _.isObject(router), "got no router object"
        assert _.isFunction(next), "got no next function"
        bowerings = @constructor.bowerings ?= new Array()
        options = _.map(bowerings, (bowr) -> bowr.options)
        options = _.merge Object.create(Object()), options...
        directory = kernel.scope.managed "pub", "bower", idc
        assert _.isString(directory), "error with Bower dir"
        options.directory = bowerings.directory = directory
        targets = _.map bowerings, (b) -> return b.target
        running = "Configure Bower packages for %s service"
        assert identify = @constructor.identify().underline
        logger.info running.grey, identify.underline or no
        logger.debug isolate, identify, directory.underline
        return @installation kernel, targets, options, next

    # This one is an internalized routine that gets preemptively
    # called by the Bower configuration and installation sequence
    # to see if the Bower installation directory has expired its
    # TTL that is configured. If so, the system will run a Bower
    # install command. If not, however, the system will silently
    # skip it for this service/directory. If, however, directory
    # does not exists - this method will not be interfering with.
    staleInstallation: (kernel, targets, options, next) ->
        expr = "Bower directory staled %s at %s".cyan
        assert c = current = moment().toDate() # current
        assert ident = @constructor.identify().underline
        bowerings = @constructor.bowerings ?= new Array()
        ndr = "could not find the Bower collector directory"
        assert _.isArray(bowerings), "no intern bowerings"
        assert _.isString(dir = bowerings.directory), ndr
        return false unless stale = nconf.get "bower:stale"
        return false unless fs.existsSync dir.toString()
        assert not _.isEmpty stats = (try fs.statSync dir)
        return false unless stats.isDirectory() is yes
        assert _.isNumber(stale), "inval stale TTL (sec)"
        assert _.isObject mtime = try moment stats.mtime
        assert mtime.add "seconds", stale # expired time
        logger.debug expr, mtime.fromNow().bold, ident
        expired = mtime.isBefore() # directory expired?
        return fs.utimesSync(dir, c, c) and no if expired
        next(); return yes # skip install, not expired

    # An internal routine that launches the actual Bower installer.
    # It takes a series of pre calculated parameters to be able to
    # perform the installation properly. Plese refer to the register
    # hook implementation in this ABC service for more information.
    # Also, refer to the method implementation for understanding.
    installation: (kernel, targets, options, next) ->
        assert install = bower.commands.install or 0
        bowerings = @constructor.bowerings ?= Array()
        return null if @staleInstallation arguments...
        assert installer = install targets, {}, options
        assert _.isObject(kernel), "got no kernel object"
        assert _.isFunction(next), "got no next function"
        kernel.domain.add installer if kernel.domain.add
        assert removing = "Clense (rm) Bower collector at %s"
        assert _.isString directory = bowerings.directory
        fwd = (arg) => kernel.domain.emit "error", arg...
        mark = => logger.warn removing.yellow, directory
        destroy = => mark try rmdirSyncRecursive directory
        installer.on "error", -> destroy(); fwd arguments
        return installer.on "end", (installed) => do =>
            message = "Getting Bower library %s@%s at %s"
            assert bowerings.installed = installed or 0
            fn = (argvector) -> next.call this, undefined
            fn _.each _.values(installed or []), (packet) =>
                assert meta = packet.pkgMeta or Object()
                name = (try meta.name.underline) or null
                version = (try meta.version.underline) or 0
                where = @constructor.identify().underline
                assert variable = [name, version, where]
                logger.debug message.cyan, variable...

    # This server side method is called on the context prior to the
    # context being compiled and flushed down to the client site. The
    # method is wired in an asynchronous way for greater functionality.
    # This is the place where you would be importing the dependencies.
    # Pay attention that most implementations side effect the context.
    prelude: (symbol, context, request, next) ->
        assert list = bower.commands.list or null
        bowerings = @constructor.bowerings ?= Array()
        cached context if cached = try bowerings.cached
        return next undefined if _.isFunction cached or 0
        identify = try @constructor.identify().underline
        assert options = directory: bowerings.directory
        message = "Executing the Bower sequences in %s"
        logger.debug message.yellow, identify.toString()
        assert _.isString(symbol), "cannot found symbol"
        assert _.isObject(context), "located no context"
        assert _.isObject(request), "located no request"
        assert _.isFunction(next), "got no next function"
        esc = (reg) -> new RegExp RegExp.escape "#{reg}"
        match = (k) -> (b) -> return esc(k).test b.target
        sorter = (v, k) -> _.findIndex bowerings, match(k)
        finder = (v, k) -> _.find bowerings, match(k)
        list(paths: yes, options).on "end", (paths) =>
            assert scope = [sorter, finder, paths]
            bowerings.cached = @cachier scope...
            bowerings.cached context; next()

    # This complicated definition is used to produce and then install
    # a method that is going to be cached and used for each request
    # once the initial Bower package installation is done. Please do
    # refer to the `prelude` implementation in this class for the info.
    # Please, refer to the method implementation for an understanding.
    cachier: (sorter, finder, paths) -> (context) ->
        nsorter = -> fback sorter(arguments...), +999
        fback = (vx, fx) -> if vx > 0 then vx else fx
        assert sorted = try _.sortBy paths, nsorter
        assert files = try _.flatten _.values sorted
        locate = (fx) -> _.findKey paths, resides(fx)
        resides = (f) -> (x) -> f is x or try f in x
        assert _.isFunction(sorter), "no sorter func"
        assert _.isFunction(finder), "no finder func"
        assert _.isObject(context), "no contex object"
        assert not _.isEmpty(paths), "no paths array"
        for file in files then do (paths, file) ->
            bowering = try finder null, locate(file)
            entry = try bowering?.entry or undefined
            assert formatted = try "#{file}/#{entry}"
            context.scripts.push formatted if entry
            return unless _.isEmpty entry?.toString()
            ext = (fxt) -> path.extname(file) is fxt
            context.scripts.push file if ext ".js"
            context.sheets.push file if ext ".css"

    # Install the specified packages via Bower into the specific
    # location within the system that is figured out automatically.
    # All packages installed via Bower will be served as the static
    # assets, by using the `pub` env dir. The package installation
    # is per service and automatically will be included in `prelude`.
    # Refer to the rest of methods for slightly better understanding.
    @bower: (target, entry, xoptions={}) ->
        ent = "an entrypoint has to be a valid string"
        noTarget = "target must be a Bower package spec"
        noOptions = "options must be the plain JS object"
        message = "Adding Bower package %s to service %s"
        options = _.find(arguments, _.isPlainObject) or {}
        assert previous = this.bowerings or new Array()
        assert previous = try _.unique(previous) or null
        return previous unless (try arguments.length) > 0
        assert identify = id = this.identify().underline
        assert _.isString(entry or null), ent if entry
        assert _.isObject(options or null), noOptions
        assert _.isString(target or null), noTarget
        logger.silly message.cyan, target.bold, id
        return this.bowerings = previous.concat
            options: options or Object()
            entry: entry or undefined
            target: target.toString()
