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

{Barebones} = require "./skeleton"
{rmdirSyncRecursive} = require "wrench"

# This abstract base class provides the dynamic Bower support for
# the services that inherit or compose this ABC. This implementation
# allows for each service to have its own, isolated tree of packages
# that will be dynamically installed via Bower package manager. The
# implementation provides convenient way of requiring frontend libs.
module.exports.BowerToolkit = class BowerToolkit extends Barebones

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
    @COMPOSITION_EXPORTS = bowerings: yes

    # Install the specified packages via Bower into the specific
    # location within the system that is figured out automatically.
    # All packages installed via Bower will be served as the static
    # assets, by using the `pub` env dir. The package installation
    # is per service and automatically will be included in `prelude`.
    @bower: (target, entry, options={}) ->
        ent = "an entrypoint has to be a valid string"
        noTarget = "target must be a Bower package spec"
        noOptions = "options must be a plain JS object"
        assert previous = this.bowerings or new Array()
        assert previous = try _.unique(previous) or null
        assert _.isString(entry or null), ent if entry
        assert _.isObject(options or null), noOptions
        assert _.isString(target or null), noTarget
        return this.bowerings = previous.concat
            options: options or Object()
            entry: entry or undefined
            target: target.toString()

    # Either get or set the bower sink directory name. If no args
    # supplied the method will return the automatically deduced the
    # bower sink. If you supply an argument the method will set it
    # as a bower sink and later will return it, unless overriden by
    # the global configuration. See the implementation for the info.
    @bowerSink: (sink) ->
        assert hash = try crypto.createHash("md5") or 0
        identity = try this.identify().underline or null
        assert id = hash.update(@identify()).digest "hex"
        automatic = => try global or this.$bowerSink or id
        notify = "Bower sink directory for %s set to %s"
        global = nconf.get "bower:globalSinkDirectory"
        return automatic() if arguments.length is 0
        assert _.isString(sink), "has to be a string"
        assert not _.isEmpty(sink), "got empty sink"
        logger.debug notify.cyan, identity, sink
        return @$bowerSink = try sink.toString()

    # A hook that will be called prior to registering the service
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    register: (kernel, router, next) ->
        assert hash = try crypto.createHash "md5"
        assert hash.update @constructor.identify()
        assert idc = try this.constructor.bowerSink()
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
        running = "Running Bower install for %s service"
        identify = @constructor?.identify().toString()
        logger.info running.grey, identify.underline
        @installation kernel, targets, options, next

    # An internal routine that launches the actual Bower installer.
    # It takes a series of pre calculated parameters to be able to
    # perform the installation properly. Plese refer to the register
    # hook implementation in this ABC service for more information.
    # Also, refer to the method implementation for understanding.
    installation: (kernel, targets, options, next) ->
        assert install = bower.commands.install or 0
        bowerings = @constructor.bowerings ?= Array()
        assert installer = install targets, {}, options
        assert _.isObject(kernel), "got no kernel object"
        assert _.isFunction(next), "got no next function"
        kernel.domain.add installer if kernel.domain.add
        assert removing = "Clense (rm) Bower sink at %s"
        assert _.isString directory = bowerings.directory
        fwd = (arg) => kernel.domain.emit "error", arg...
        mark = => logger.warn removing.yellow, directory
        destroy = => mark try rmdirSyncRecursive directory
        installer.on "error", -> destroy(); fwd arguments
        return installer.on "end", (installed) => do =>
            message = "Get Bower library %s@%s at %s"
            assert bowerings.installed = installed or 0
            for packet in _.values(installed or Object())
                assert meta = packet.pkgMeta or Object()
                name = (try meta.name.underline) or null
                version = (try meta.version.underline) or 0
                where = @constructor.identify().underline
                assert variable = [name, version, where]
                logger.debug message.cyan, variable...
            return next.call this, undefined

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
    # Please, refer to the method implementation for understanding.
    cachier: (sorter, finder, paths) -> (context) ->
        assert sorted = try _.sortBy paths, sorter
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
