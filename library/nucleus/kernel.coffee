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

asciify = require "asciify"
connect = require "connect"
logger = require "winston"
events = require "events"
colors = require "colors"
nconf = require "nconf"
https = require "https"
paths = require "path"
http = require "http"
util = require "util"
fs = require "fs"

_ = require "lodash"
extendz = require "./extends"
bundles = require "./bundles"
routing = require "./routing"
service = require "./service"
scoping = require "./scoping"
content = require "./content"
plumbs = require "./plumbs"
watch = require "./watch"

# This is a primary gateway interface for the framework. This class
# provides methods and routines necessary to bootstrap the framework
# and the end user application constructed within the framework. It
# is both an abstract base class as well as a ready to use bootstrap.
# Please refer to the documentation of the methods for more info.
module.exports.Kernel = class Kernel extends events.EventEmitter

    # The public constructor of the kernel instrances. Generally
    # you should neither use it directly, not override. It serves
    # the purpose of setting up the configurations will never be
    # changed, such as the kernel self identification tokens.
    constructor: (initializer) ->
        nconf.env().argv()
        specification = "../../package"
        @package = require specification
        branding = [@package.name, "larry3d"]
        types = [@package.version, @package.codename]
        scoping.Scope.setupLoggingFacade this
        asciify branding..., (error, banner) =>
            util.puts banner.toString().blue unless error
            identify = "Running kernel %s, codename: %s"
            logger.info identify.underline, types...
            initializer?.apply this

    # Shutdown the kernel instance. This includes shutting down both
    # HTTP and HTTPS server that may be running, stopping the router
    # and unregistering all the services as a precauting. After that
    # the scope is being dispersed and some events are being emited.
    shutdownKernel: ->
        util.puts require("os").EOL
        try @router.shutdownRouter()
        s.unregister() for s in @router.registry
        try @server.close(); try @secure.close()
        shutdown = "Shutting the kernel down".red
        logger.info shutdown; @emit "shutdown"
        @scope.disperse(); this

    # Instantiate a hot swapping watcher for this kernel and setup
    # the watcher per the scoping configuration to watch for certain
    # directories. Please refer to the `Watcher` implementation for
    # more information on its operations and configuration routines.
    setupHotloadWatcher: ->
        @watcher = new watch.Watcher this
        subjects = nconf.get "watch:dirs"
        isArray = _.isArray subjects
        noArray = "No watching configuration"
        throw new Error noArray unless isArray
        watch = @watcher.watchDirectory.bind @watcher
        watch directory for directory in subjects; @
        watch paths.resolve __dirname, "../vending"

    # Create a new instance of the kernel, run all the prerequisites
    # that are necessary, do the configuration on the kernel, then
    # boot it up, using the hostname and port parameters from config.
    # Please use this static method instead of manually launching up.
    @bootstrap: -> new Kernel ->
        @setupRoutableServices()
        @setupConnectPipeline()
        @setupListeningServers()
        @setupHotloadWatcher()
        @broker = new content.Broker
        message = "Booted up the kernel instance"
        process.on "SIGINT", => @shutdownKernel()
        logger.info message.red; this

    # Create and configure the HTTP and HTTPS servers to listen at
    # the configured addresses and ports. This method reads up the
    # scoping configuration in order to obtain the data necessary
    # for instantiating, configuring and launching up the servers.
    setupListeningServers: ->
        try @startupHttpsServer() catch error
            message = "Exception while launching HTTPS server:\r\n%s"
            logger.warn message.red, error.stack; process.exit -1
        try @startupHttpServer() catch error
            message = "Exception while launching HTTP server:\r\n%s"
            logger.warn message.red, error.stack; process.exit -1

    # Setup and launch either HTTP or HTTPS servers to listen at
    # the configured addresses and ports. This method reads up the
    # scoping configuration in order to obtain the data necessary
    # for instantiating, configuring and launching up the servers.
    startupHttpsServer: ->
        options = new Object
        secure = nconf.get "secure"
        hostname = nconf.get "server:hostname"
        key = paths.relative process.cwd(), secure.key
        cert = paths.relative process.cwd(), secure.cert
        logger.info "Using SSL key at %s".grey, key
        logger.info "Using SSL cert at %s".grey, cert
        options.key = fs.readFileSync paths.resolve key
        options.cert = fs.readFileSync paths.resolve cert
        rsecure = "Running HTTPS server at %s:%s".magenta
        logger.info rsecure, hostname, secure.port
        @secure = https.createServer options, @connect
        @secure?.listen secure.port, hostname

    # Setup and launch either HTTP or HTTPS servers to listen at
    # the configured addresses and ports. This method reads up the
    # scoping configuration in order to obtain the data necessary
    # for instantiating, configuring and launching up the servers.
    startupHttpServer: ->
        server = nconf.get "server"
        hostname = nconf.get "server:hostname"
        rserver = "Running HTTP server at %s:%s".magenta
        logger.info rserver, hostname, server.port
        @server = http.createServer @connect
        @server?.listen server.port, hostname

    # This method sets up the necessary internal toolkits, such as
    # the determined scope and the router, which is then are wired
    # in with the located and instantiated services. Please refer
    # to the implementation on how and what is being done exactly.
    setupRoutableServices: (services...) ->
        tag = nconf.get "NODE_ENV"
        missing = "No NODE_ENV variable found"
        c = (s) => @router.registerRoutable new s @
        throw new Error missing unless _.isString tag
        @scope = scoping.Scope.lookupOrFail tag
        @scope.incorporate this
        @router = new routing.Router this
        @middleware = @router.lookupMiddleware
        @middleware = @middleware.bind @router
        c(s) for s in (@scope.services or [])
        c(s) for s in (services or [])

    # Setup the Connect middleware framework along with the default
    # pipeline of middlewares necessary for the Flames framework to
    # operate correctly. You are encouraged to override this method
    # to provide a Connect setup procedure to your own liking, etc.
    setupConnectPipeline: (middlewares...) ->
        @connect = connect()
        @connect.use connect.query()
        @connect.use connect.favicon()
        @connect.use connect.bodyParser()
        @connect.use connect.cookieParser()
        @connect.use plumbs.params this
        @connect.use plumbs.redirect this
        @connect.use plumbs.session this
        @connect.use plumbs.accepts this
        @connect.use plumbs.sender this
        @connect.use plumbs.logger this
        @connect.use m for m in middlewares
        @connect.use(@middleware)
