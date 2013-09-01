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
        previous = @bowerings or []
        noTarget = "target must be a string"
        noOptions = "options must be an object"
        assert _.isObject(options), noOptions
        assert _.isString(target), noTarget
        return @bowerings = previous.concat
            options: options
            target: target
            entry: entry

    # A hook that will be called prior to registering the service
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    register: (kernel, router, next) ->
        hash = crypto.createHash "md5"
        hash.update @constructor.identify()
        id = hash.digest("hex").toString()
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
        install = bower.commands.install
        bowerings = @constructor.bowerings ?= []
        installer = install targets, {}, options
        installer.on "error", (error) ->
            reason = "failed Bower package installation"
            logger.error error.message.toString().red, error
            kernel.shutdownKernel reason.toString()
        installer.on "end", (installed) =>
            bowerings.installed = installed
            message = "Get Bower lib %s@%s at %s"
            for packet in _.values(installed or {})
                name = packet.pkgMeta?.name.underline
                version = packet.pkgMeta?.version.underline
                where = @constructor.identify().underline
                logger.debug message.cyan, name, version, where
            return next()

    # This server side method is called on the context prior to the
    # context being compiled and flushed down to the client site. The
    # method is wired in an asynchronous way for greater functionality.
    # This is the place where you would be importing the dependencies.
    prelude: (context, request, next) ->
        list = bower.commands.list
        bowerings = @constructor.bowerings ?= []
        cached context if cached = bowerings.cached
        return next() if _.isFunction cached
        options = directory: bowerings.directory
        esc = (p) -> new RegExp RegExp.escape "#{p}"
        match = (k) -> (b) -> esc(k).test b.target
        sorter = (v, k) -> _.findIndex bowerings, match(k)
        finder = (v, k) -> _.find bowerings, match(k)
        list(paths: yes, options).on "end", (paths) ->
            locate = (f) -> _.findKey paths, resides(f)
            resides = (f) -> (x) -> f is x or try f in x
            bowerings.cached = (context) ->
                sorted = _.sortBy paths, sorter
                files = _.flatten _.values sorted
                for file in files then do (file) ->
                    ext = (e) -> path.extname(file) is e
                    context.scripts.push file if ext ".js"
                    context.sheets.push file if ext ".css"
                    bowering = finder null, locate(file)
                    entry = bowering?.entry or new String
                    return if _.isEmpty entry.toString()
                    context.scripts.push "#{file}/#{entry}"
            bowerings.cached context; next()
