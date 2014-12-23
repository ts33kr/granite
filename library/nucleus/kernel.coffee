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
pkginfo = require "pkginfo"
socketio = require "socket.io"
uuid = require "node-uuid"
colors = require "colors"
assert = require "assert"
redisio = require "redis"
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
scanner = require "./scanner"
plumbs = require "./plumbs"

{format} = require "util"
{KernelTools} = require "./ktools"
{RedisStore} = require "socket.io"
{Archetype} = require "./arche"

# This is a primary gateway interface for the framework. This class
# provides methods and routines necessary to bootstrap the framework
# and the end user application constructed within the framework. It
# is both an abstract base class as well as a ready to use bootstrap.
# Please refer to the documentation of the methods for more info. It
# also is the main entrypoint to pretty much the entire application.
module.exports.GraniteKernel = class GraniteKernel extends Archetype

    # These declarations below are implantations of the abstracted
    # components by the means of the dynamic recomposition system.
    # Please take a look at the `Composition` class implementation
    # for all sorts of information on the composition system itself.
    # Each of these will be dynamicall integrated in class hierarchy.
    @implanting KernelTools

    # This sets up the default identica for this kernel. It forms
    # an identica of a certain recommended format and populates it
    # with data takes from the `FRAMEWORK` definition in `Generic`
    # kernel. Refer to that kernel and to `identica` method there
    # for more information on semantics and the way of working it.
    @identica -> "#{@APPLICATION.name}@#{@APPLICATION.version}"

    # The complementary part of the kernel launching protocol. It is
    # invoked by the bootstrapping routine to do the actual kernel
    # launch. If you are going to override the bootstrap procedures
    # then override this static method, rather than the `bootstrap`.
    # Be careful about the relations between methods when overriding.
    @makeKernelSetup: (options) -> ->
        assert @options = _.cloneDeep options
        assert _.isObject(@options), "no options"
        manifest = "Using %s as instance identica"
        message = "Booted up framework kernel instance"
        sigint = "Received the SIGINT (interrupt signal)"
        sigterm = "Received the SIGTERM (terminate signal)"
        process.on "SIGINT", => @shutdownKernel sigint
        process.on "SIGTERM", => @shutdownKernel sigterm
        assert not _.isEmpty @setupScaffolding.call this
        assert not _.isEmpty @setupKernelBeacon.call this
        this.constructor.configure().call this, (results) =>
            return @kernelPreemption.call this, (reference) =>
                assert not _.isEmpty @setupConnectPipeline()
                assert not _.isEmpty @startupHttpsServer()
                assert not _.isEmpty @startupHttpServer()
                assert not _.isEmpty @setupSocketServers()
                assert not _.isEmpty @setupModuleScanner()
                assert identica = @constructor.identica()
                logger.info manifest, identica.bold
                logger.info message.red; return @

    # The public constructor of the kernel instrances. Generally
    # you should neither use it directly, not override. It serves
    # the purpose of setting up the configurations will never be
    # changed, such as the kernel self identification tokens.
    constructor: (initializer) ->
        try super if @constructor.__super__
        assert not _.isEmpty @token = uuid.v4()
        nconf.env().argv(); @setupLoggingFacade()
        assert @framework = @constructor.FRAMEWORK
        assert @application = @constructor.APPLICATION
        assert branding = [@framework.name, "smisome1"]
        types = [@framework.version, @framework.codename]
        comp = "Framework kernel boot sequence is completed!"
        GraniteKernel.instance = this # only kernel allowed
        assert global.GRANITE_KERNEL = this # global kernel
        this.interceptExceptions.call this, initializer
        @once "completed", => @emit "bootloaded", this
        @once "completed", => logger.info comp.rainbow
        return asciify branding..., (error, banner) =>
            visible = ["info", "debug", "warn", "silly"]
            show = try nconf.get("log:level") in visible
            util.puts banner.blue if (not error) and show
            identify = "Running version %s, codename: %s"
            using = "Using %s class as the kernel type"
            types = _.map types, (type) -> type.bold
            logger.info identify.underline, types...
            logger.info using, @constructor.name.bold
            @domain.run => initializer?.apply this
            @emit "ready", initializer; return @

    # This routine sets up the infrastructure necessary for kernel
    # to properly intercept and process errors and exceptions. This
    # includes synchronous exceptions as well as the asynchronous
    # errors. Depending on the instance configuration this method
    # could either crash the kernel on error or proceed operations.
    interceptExceptions: ->
        assert u = moment().unix().toString()
        assert crash = "kernel:crashOnException"
        assert skill = @shutdownKernel.bind this
        assert @domain = require("domain").create()
        m = "Install exception handling mechanisms of %s"
        fatal = => skill "Fatal kernel error at U=#{u}"
        str = (err) -> err.stack or err.message or err
        @on "panic", (e) -> logger.error bark, str(e)
        @on "panic", (e) -> fatal() if nconf.get crash
        @domain.on "error", (err) => @emit "panic", err
        bark = "Kernel domain panic at U=#{u}\r\n%s".red
        assert identify = try this.constructor.identify()
        logger.silly m.red, identify.toString().red.bold
        process.removeAllListeners "uncaughtException"
        process.on "uncaughtException", (error, arg) =>
            return no if str(error) is "socket end"
            return @emit.call this, "panic", error

    # Shutdown the kernel instance. This includes shutting down both
    # HTTP and HTTPS server that may be running, stopping the router
    # and unregistering all the services as a precauting. After that
    # the scope is being dispersed and some events are being emited.
    shutdownKernel: (reason, eol=yes) ->
        g = "Kernel has requested to be shutted down"
        util.puts require("os").EOL.toString() if eol
        logger.warn (reason or g or 0).toString().red
        try @router.shutdownRouter?() catch error then
        snapshot = _.clone @router?.registry or Array()
        assert unreg = @router.unregister.bind @router
        xkill = (s, next) -> return unreg s, (-> next())
        fns = _.map snapshot, (s) -> (n) -> xkill s, n
        return async.series fns, (error, results) =>
            try @server.close(); try @secure.close()
            try @secureSocket.close() if @secureSocket?
            try @serverSocket.close() if @serverSocket?
            shutdown = "Shutting the kernel instance down"
            logger.warn shutdown.red; this.emit "shutdown"
            @scope?.disintegrate(); @domain?.dispose()
            return process.exit -1 # crash process

    # The important internal routine that sets up and configures a
    # kernel beacon that gets fired once at each configured interval.
    # The beacon, once fired, gets propagated to all services that
    # implement the appropriate asynchronous hook. This mechanism is
    # intended as a heartbeat that can be leveraged by each service.
    setupKernelBeacon: ->
        assert _.isFunction u = -> try moment.unix()
        msg = "Setting up the kernel beacon at %s ms"
        interval = nconf.get("beacon:interval") or null
        noInterval = "no beacon interval has been given"
        eua = (s) => (n) => s.downstream(beacon: n)(@, u())
        assert _.isNumber(interval), noInterval.toString()
        logger.info msg.magenta, interval.toString().bold
        timer = (millisec, fn) -> setInterval fn, millisec
        return @beacon = timer interval, (parameters) =>
            assert _.isNumber(unix = moment().unix())
            pulse = "Kernel beacon pulse at a %s UNIX"
            assert services = @router.registry or Array()
            logger.debug pulse.magenta, "#{unix}".bold
            srv.emit "beacon", this for srv in services
            prepared = _.map(services, eua) or Array()
            async.series prepared, (err, res) -> null

    # Allocate a module scanner insrance for this kernel and setup
    # the scanner per the scoping configuration to monitor certain
    # directories. Please reference the `ModuleScanner` comppnent
    # implementation for more information on its operations and a
    # configuration routines and facilities. The scanner itself is
    # is a zombie services, therefore is instantuated accordingly.
    setupModuleScanner: ->
        makeFailed = "failed to make module scanner"
        message = "Allocate %s service as dir monitor"
        @scanner = scanner.ModuleScanner.obtain this
        @scanner.on "drain", => this.emit "completed"
        assert _.isObject(scanner or null), makeFailed
        identify = @scanner.constructor.identify().bold
        logger.info message.yellow, identify.toString()
        configs = try nconf.get("layout:config") or null
        subjects = try nconf.get("scanner:dirs") or null
        library = try nconf.get("layout:library") or null
        assert _.isArray(subjects), "scanner not configed"
        assert _.isString(configs), "no configure layout"
        assert _.isString(library), "no library layouts"
        monitor = @scanner.monitorDirectory.bind @scanner
        monitor paths.resolve __dirname, "../shipped"
        monitor paths.resolve __dirname, "../semantic"
        monitor directory for directory in subjects
        monitor library; monitor configs; this

    # Setup and launch either HTTP or HTTPS servers to listen at
    # the configured addresses and ports. This method reads up the
    # scoping configuration in order to obtain the data necessary
    # for instantiating, configuring and launching up the servers.
    # See the method implementation for info on the exact semantic.
    startupHttpsServer: ->
        completed = 0 # initial kernel state
        @once "completed", => completed = yes
        assert server = nconf.get "server" or {}
        assert hostname = nconf.get "server:host" or 0
        assert _.isNumber(server.https), "no HTTPS port"
        assert _.isObject options = @resolveSslDetails()
        running = "Running HTTPS server at %s".magenta
        rearly = "HTTPS request %s came early, killing".red
        arrived = "Incoming #{"HTTPS".bold} connection at %s"
        location = "#{hostname}:#{server.https}".toString()
        logger.info running.underline, location.underline
        @secure = https.createServer options, @connect
        assert _.isObject @domain; @domain.add @secure
        do => @secure.listen server.https, hostname
        return @secure.on "connection", (socket) ->
            key = try socket?.server?._connectionKey
            key = si = try key?.toString().underline
            logger.debug rearly, si unless completed
            return socket.destroy() unless completed
            logger.debug arrived.green, si.underline
            return socket.setNoDelay yes # setsock

    # Setup and launch either HTTP or HTTPS servers to listen at
    # the configured addresses and ports. This method reads up the
    # scoping configuration in order to obtain the data necessary
    # for instantiating, configuring and launching up the servers.
    # See the method implementation for info on the exact semantic.
    startupHttpServer: ->
        completed = 0 # initial kernel state
        @once "completed", => completed = yes
        assert server = nconf.get "server" or {}
        assert hostname = nconf.get "server:host" or 0
        assert _.isNumber(server.http), "no HTTP port"
        running = "Running HTTP server at %s".magenta
        rearly = "HTTP request %s came early, killing".red
        arrived = "Incoming #{"HTTP".bold} connection at %s"
        location = "#{hostname}:#{server.http}".toString()
        logger.info running.underline, location.underline
        @server = http.createServer @connect, undefined
        assert _.isObject @domain; @domain.add @server
        do => @server.listen server.http, hostname
        return @server.on "connection", (socket) ->
            key = try socket?.server?._connectionKey
            key = si = try key?.toString().underline
            logger.debug rearly, si unless completed
            return socket.destroy() unless completed
            logger.debug arrived.green, si.underline
            return socket.setNoDelay yes # setsock

    # Setup and attach Socket.IO handlers to each of the servers.
    # That is HTTP and HTTPS servers that are running and listening
    # for new connections. The kernel itself does not use the sockets
    # it just sets it up. Please refer to the Socket.IO docs for info.
    # Also, see the `configureSocketServers` method implementation.
    setupSocketServers: ->
        killed = "Killed %s as orphaned socket".red
        assert _.isObject sconfig = nconf.get "socket"
        assert txf = (fn) -> return setTimeout fn, 1000
        logger.info "Attaching Socket.IO to HTTPS server"
        logger.info "Attaching Socket.IO to HTTP server"
        newMessage = "New Socket.IO connected at %s server"
        k = (so) -> so.disconnect new Error "killed orphan"
        logging = (st) -> logger.debug newMessage.grey, st
        defects = (so) -> logger.debug killed, so.id.bold
        discont = (so) -> so.emit "orphan"; defects so; k so
        timeout = (so) -> -> try discont so unless so.owned
        newSock = (st) -> (so) -> logging st; txf timeout(so)
        assert @secureSocket = socketio.listen @secure, sconfig
        assert @serverSocket = socketio.listen @server, sconfig
        @configureSocketServers @serverSocket, @secureSocket
        this.secureSocket.on "connection", newSock "HTTPS"
        this.serverSocket.on "connection", newSock "HTTP"

    # This configuration utility sets up the environment for the
    # Socket.IO server in the current kernel. Basically, this does
    # the socket server configuration using the Socket.IO configure
    # API to set the necessary options to opimize the performance.
    # Please refer to the implementation for more info on options.
    configureSocketServers: ->
        assert not _.isEmpty servers = _.toArray arguments
        @domain.add server for own server, index of servers
        logger.info "Configuring the Socket.IO servers".cyan
        assert @serverSocket in servers, "missing HTTP socket"
        assert @secureSocket in servers, "missing HTTPS socket"
        return @on "redis-ready", (redis) => do (redis) =>
            message = "Attaching Redis storage to sockets"
            logger.debug message.toString().cyan if logger
            assert readapter = require "socket.io-redis"
            assert _.isNumber port = try redis.port or null
            assert _.isString host = try redis.host or null
            assert _.isObject opts = try redis.options or 0
            pubCon = redisio.createClient port, host, opts
            subCon = redisio.createClient port, host, opts
            ready = pubClient: pubCon, subClient: subCon
            this.secureSocket.adapter readapter ready
            this.serverSocket.adapter readapter ready

    # Setup the Connect middleware framework along with the default
    # pipeline of middlewares necessary for the Granite framework to
    # operate correctly. You are encouraged to override this method
    # to provide a Connect setup procedure to your own liking, etc.
    # Each middleware instance is stored in the kernel as variable.
    setupConnectPipeline: ->
        assert @connect = connect()
        assert @connectStaticAssets()
        threshold = plumbs.threshold this
        @connect.use @threshold = threshold
        @connect.use @query = connect.query()
        @connect.use @jsonParser = connect.json()
        @connect.use @compress = connect.compress()
        @connect.use @urlencoded = connect.urlencoded()
        @connect.use @cookieParser = connect.cookieParser()
        @connect.use @parameters = plumbs.parameters this
        @connect.use @extSession = plumbs.extSession this
        @connect.use @negotiate = plumbs.negotiate this
        @connect.use @platform = plumbs.platform this
        @connect.use @redirect = plumbs.redirect this
        @connect.use @session = plumbs.session this
        @connect.use @accepts = plumbs.accepts this
        @connect.use @logger = plumbs.logger this
        @connect.use @send = plumbs.send this
        @connect.use @dispatching; this

    # This method sets up the necessary internal toolkits, such as
    # the determined scope and the router, which is then are wired
    # in with the located and instantiated services. Please refer
    # to the implementation on how and what is being done exactly.
    # Also, it looks up and initialized the requested env scope.
    setupScaffolding: ->
        tag = try nconf.get "NODE_ENV" or undefined
        mode = try nconf.get "forever" or undefined
        missing = "no valid NODE_ENV variable found"
        mode = mode.toUpperCase().underline if mode
        bare = "Running without Forever supervision"
        supd = "Running using %s mode within Forever"
        assert not _.isEmpty(tag), missing.toString()
        assert @tag = @env = @environment = tag or null
        assert @scope = try scoping.Scope.lookup tag
        assert this.scope.incorporate this, undefined
        logger.warn bare.toString().red unless mode
        logger.warn supd.toString().red, mode if mode
        assert @router = new routing.ServiceRouter @
        assert @dispatching = @router.dispatching
        @dispatching = @dispatching.bind @router
        assert _.isFunction @dispatching; this

    # Setup a set of appropriate Connect middlewares that will take
    # care of serving static directory content for all configured
    # assets directory, using the options drawed from configuration.
    # You should override the method to tweak the creation process.
    # Please see the `serveStaticDirectory` method implementation.
    connectStaticAssets: ->
        envs = nconf.get "env:dirs" or Array()
        dirs = nconf.get "assets:dirs" or Array()
        opts = nconf.get "assets:opts" or Object()
        pub = -> _.find envs, (dir) -> dir is "pub"
        established = try "#{__dirname}/../../public"
        stringOptions = (try JSON.stringify opts) or 0
        assert _.isString(pub()), "no pub environment"
        assert _.isObject(opts), "wrong assets options"
        assert _.isArray(dirs), "no assets directories"
        m = "Connecting the endpoints for static assets"
        o = "Setting static directory server options: %s"
        logger.info m.toString().magenta # notification
        logger.debug o.toString().grey, stringOptions
        @serveStaticDirectory d, opts for d in dirs
        @serveStaticDirectory established, Object()
        @serveStaticDirectory pub(); return this
