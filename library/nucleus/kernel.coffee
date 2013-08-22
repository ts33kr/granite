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
moment = require "moment"
events = require "events"
colors = require "colors"
assert = require "assert"
async = require "async"
nconf = require "nconf"
https = require "https"
paths = require "path"
http = require "http"
util = require "util"
fs = require "fs"

_ = require "lodash"
extendz = require "./extends"
compose = require "./compose"
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
module.exports.Generic = class Generic extends events.EventEmitter

    # An embedded system for adding ad-hoc configuration routines.
    # Supply the reasoning and the routine and this method will add
    # that routine to the configuration stack, to be launched once
    # the kernel boots up. With no arguments it launches the stack.
    # This is a convenient way of running additions config routines.
    @configure: (explain, routine) ->
        if arguments.length is 0 and _.isArray @$configure
            level = (e) -> logger.info "Configuring: %s", e
            fix = (o) -> (a...) -> level o.explain; o.routine a...
            return async.series _.map(@$configure, fix)
        assert _.isFunction(routine), "invalid config routine"
        assert _.isString(explain), "no explanation given"
        (@$configure ?= []).push
            explain: explain
            routine: routine

    # Create a new instance of the kernel, run all the prerequisites
    # that are necessary, do the configuration on the kernel, then
    # boot it up, using the hostname and port parameters from config.
    # Please use this static method instead of manually launching up.
    @bootstrap: -> new this ->
        @setupRoutableServices()
        @setupConnectPipeline()
        @setupListeningServers()
        @setupHotloadWatcher()
        @broker = new content.Broker
        message = "Booted up the kernel instance"
        sigint = "Received the SIGINT (interrupt signal)"
        sigterm = "Received the SIGTERM (terminate signal)"
        process.on "SIGINT", => @shutdownKernel sigint
        process.on "SIGTERM", => @shutdownKernel sigterm
        @constructor.configure()
        logger.info message.red

    # The public constructor of the kernel instrances. Generally
    # you should neither use it directly, not override. It serves
    # the purpose of setting up the configurations will never be
    # changed, such as the kernel self identification tokens.
    constructor: (initializer) ->
        nconf.env().argv()
        @setupLoggingFacade()
        specification = "#{__dirname}/../../package"
        @package = require specification
        branding = [@package.name, "larry3d"]
        types = [@package.version, @package.codename]
        asciify branding..., (error, banner) =>
            util.puts banner.toString().blue unless error
            identify = "Running kernel %s, codename: %s"
            using = "Using %s class as the kernel type"
            logger.info identify.underline, types...
            logger.info using, @constructor.name.bold
            initializer?.apply this

    # Shutdown the kernel instance. This includes shutting down both
    # HTTP and HTTPS server that may be running, stopping the router
    # and unregistering all the services as a precauting. After that
    # the scope is being dispersed and some events are being emited.
    shutdownKernel: (reason) ->
        util.puts require("os").EOL
        logger.warn reason.toString().red
        try @router.shutdownRouter()
        registry = @router.registry or []
        s.unregister() for s in registry
        try @server.close(); try @secure.close()
        shutdown = "Shutting the kernel instance down".red
        logger.warn shutdown; @emit "shutdown"
        @scope.disperse(); process.exit -1

    # Instantiate a hot swapping watcher for this kernel and setup
    # the watcher per the scoping configuration to watch for certain
    # directories. Please refer to the `Watcher` implementation for
    # more information on its operations and configuration routines.
    setupHotloadWatcher: ->
        @watcher = new watch.Watcher this
        subjects = nconf.get "watch:dirs"
        library = nconf.get "layout:library"
        noDirs = "no watching configuration"
        noLibrary = "no library layout is set"
        assert _.isArray(subjects), noDirs
        assert _.isString(library), noLibrary
        watch = @watcher.watchDirectory.bind @watcher
        watch directory for directory in subjects
        watch paths.resolve __dirname, "../vending"
        watch library.toString(); this

    # The utilitary method that is being called by either the kernel
    # or scope implementation to establish the desirable facade for
    # logging. The options from the config may be used to configure
    # various options of the logger, such as output format, etc.
    setupLoggingFacade: ->
        format = "DD/MM/YYYY @ hh:mm:ss"
        stamp = -> moment().format format
        options = timestamp: stamp, colorize: yes
        options.level = nconf.get "log:level"
        noLevel = "No logging level specified"
        throw new Error noLevel unless options.level
        logger.remove logger.transports.Console
        logger.add logger.transports.Console, options

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
        logger.info "Using SSL key file at %s".grey, key
        logger.info "Using SSL cert file at %s".grey, cert
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
    setupRoutableServices: ->
        tag = nconf.get "NODE_ENV"
        missing = "No NODE_ENV variable found"
        assert _.isString(tag), missing
        @scope = scoping.Scope.lookupOrFail tag
        @scope.incorporate this
        @router = new routing.Router this
        @middleware = @router.middleware
        @middleware = @middleware.bind @router

    # Setup the Connect middleware framework along with the default
    # pipeline of middlewares necessary for the Flames framework to
    # operate correctly. You are encouraged to override this method
    # to provide a Connect setup procedure to your own liking, etc.
    setupConnectPipeline: ->
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
        @connect.use @middleware
