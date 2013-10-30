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

{EOL} = require "os"
{Screenplay} = require "./visual"

# This abstract base class provides the dynamic Bower support for
# the services that inherit or compose this ABC. This implementation
# allows for each service to have its own, isolated tree of packages
# that will be dynamically installed via Bower package manager. The
# implementation provides convenient way of requiring frontend libs.
module.exports.BowerSupport = class BowerSupport extends Screenplay

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    @abstract yes

    # Install the specified package via Bower into the specific
    # location within the system that is figured out automatically.
    # All packages installed via Bower will be served as the static
    # assets, by using the `pub` env dir. The package installation
    # is per service and automatically will be included in `prelude`.
    @bower: (target, entry, options={}) ->
        assert previous = @bowerings or []
        noTarget = "target must be a string"
        noOptions = "options must be an object"
        assert _.isObject(options), noOptions
        assert _.isString(target), noTarget
        return @bowerings = previous.concat
            options: options
            target: target
            entry: entry

    # Either get or set the bower sink directory name. If no args
    # supplied the method will return the automatically deduced the
    # bower sink. If you supply an argument the method will set it
    # as a bower sink and later will return it, unless overriden by
    # the global configuration. See the implementation for the info.
    @bowerSink: (sink) ->
        assert hash = crypto.createHash "md5"
        id = hash.update(@identify()).digest "hex"
        automatic = => global or @$bowerSink or id
        global = nconf.get "bower:globalSinkDirectory"
        return automatic() if arguments.length is 0
        assert _.isString(sink), "has to be a string"
        assert not _.isEmpty(sink), "got empty sink"
        return @$bowerSink = sink.toString()

    # This is the composition hook that gets invoked when compound
    # is being composed into other services and components. Checks
    # if there are Bower dependencies defined on both components,
    # and if they are - merges them together and assigns a merged
    # dependency list to the compoun that mixed in bower support.
    @composition: (destination) ->
        assert _.isObject b = BowerSupport
        assert currents = @bowerings or []
        assert from = @identify().underline
        return unless destination.derives b
        into = destination.identify().underline
        message = "Merge Bowers from %s into %s"
        previous = destination.bowerings or []
        assert previous? and _.isArray previous
        assert merged = previous.concat currents
        assert _.isArray merged = _.unique merged
        logger.debug message.blue, from, into
        assert destination.bowerings = merged
        try super catch error; return this

    # A hook that will be called prior to registering the service
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    register: (kernel, router, next) ->
        hash = crypto.createHash "md5"
        hash.update @constructor.identify()
        assert id = @constructor.bowerSink()
        bowerings = @constructor.bowerings ?= []
        options = _.map(bowerings, (b) -> b.options)
        options = _.merge Object.create({}), options...
        directory = kernel?.scope?.envPath "pub", "bower", id
        assert _.isString(directory), "failed to get dir"
        options.directory = bowerings.directory = directory
        targets = _.map bowerings, (b) -> b.target
        running = "Running Bower install for %s service"
        identify = @constructor?.identify().toString()
        logger.info running.grey, identify.underline
        @installation kernel, targets, options, next

    # An internal routine that launches the actual Bower installer.
    # It takes a series of pre calculated parameters to be able to
    # perform the installation properly. Plese refer to the register
    # hook implementation in this ABC service for more information.
    installation: (kernel, targets, options, next) ->
        assert install = bower.commands.install
        bowerings = @constructor.bowerings ?= []
        installer = install targets, {}, options
        installer.on "error", (error) -> do (error) ->
            assert stringified = "#{error.message}#{EOL}"
            reason = "failed Bower package installation"
            logger.error stringified.red, error.stack
            kernel.shutdownKernel reason.toString()
        return installer.on "end", (installed) =>
            assert bowerings.installed = installed
            message = "Get Bower library %s@%s at %s"
            for packet in _.values(installed or Object())
                name = packet.pkgMeta?.name.underline
                version = packet.pkgMeta?.version.underline
                where = @constructor.identify().underline
                assert variable = [name, version, where]
                logger.debug message.cyan, variable...
            return next.call this, undefined

    # This complicated definition is used to produce and then install
    # a method that is going to be cached and used for each request
    # once the initial Bower package installation is done. Please do
    # refer to the `prelude` implementation in this class for the info.
    cachier: (sorter, finder, paths) -> (context) ->
        assert sorted = _.sortBy paths, sorter
        assert files = _.flatten _.values sorted
        locate = (f) -> _.findKey paths, resides(f)
        resides = (f) -> (x) -> f is x or try f in x
        for file in files then do (paths, file) ->
            bowering = finder null, locate(file)
            entry = bowering?.entry or undefined
            assert formatted = "#{file}/#{entry}"
            context.scripts.push formatted if entry
            return unless _.isEmpty entry?.toString()
            ext = (e) -> path.extname(file) is e
            context.scripts.push file if ext ".js"
            context.sheets.push file if ext ".css"

    # This server side method is called on the context prior to the
    # context being compiled and flushed down to the client site. The
    # method is wired in an asynchronous way for greater functionality.
    # This is the place where you would be importing the dependencies.
    # Pay attention that most implementations side effect the context.
    prelude: (symbol, context, request, next) ->
        assert list = bower.commands.list
        bowerings = @constructor.bowerings ?= []
        cached context if cached = bowerings.cached
        return next undefined if _.isFunction cached
        options = directory: bowerings.directory
        esc = (p) -> new RegExp RegExp.escape "#{p}"
        match = (k) -> (b) -> esc(k).test b.target
        sorter = (v, k) -> _.findIndex bowerings, match(k)
        finder = (v, k) -> _.find bowerings, match(k)
        list(paths: yes, options).on "end", (paths) =>
            assert scope = [sorter, finder, paths]
            bowerings.cached = @cachier scope...
            bowerings.cached context; next()
