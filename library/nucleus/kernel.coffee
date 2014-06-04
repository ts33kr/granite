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
plumbs = require "./plumbs"
watch = require "./watch"

{format} = require "util"
{RedisStore} = require "socket.io"
{Archetype} = require "./archetype"

# This is a primary gateway interface for the framework. This class
# provides methods and routines necessary to bootstrap the framework
# and the end user application constructed within the framework. It
# is both an abstract base class as well as a ready to use bootstrap.
# Please refer to the documentation of the methods for more info.
module.exports.GenericKernel = class GenericKernel extends Archetype

    # This static property should contain the loaded NPM package
    # module which is used by the kernel to draw different kinds
    # of the information and data. This could be overridden by the
    # modified kernels that are custom to arbitrary applications.
    # This definition (package.json) should corellate to framework.
    assert @FRAMEWORK = pkginfo.read(module).package

    # This static property should contain the loaded NPM package
    # module which is used by the kernel to draw different kinds
    # of the information and data. This could be overridden by the
    # modified kernels that are custom to arbitrary applications.
    # This definition (package.json) should corellate to application.
    assert @APPLICATION = pkginfo.read(0, process.cwd()).package

    # Create a new instance of the kernel, run all the prerequisites
    # that are necessary, do the configuration on the kernel, then
    # boot it up, using the hostname and port parameters from config.
    # Please use this static method instead of manually launching up.
    # Refer to the static method `makeKernelSetup` for information.
    @bootstrap: (options={}) -> new this @makeKernelSetup options

    # The kernel preemption routine is called once the kernel has
    # passed the initial launching and configuration phase, but is
    # yet to start up the router, connect services and instantiate
    # an actual application. This method gets passes continuation
    # that does that. The method can either invoke it or omit it.
    kernelPreemption: (continuation) -> continuation.apply this

    # Either get or set an identica token. This token is application
    # identification string of a free form, but usually formed by a
    # app name plus a verion after the at sign. If no arguments are
    # supplied, the method will get identica, otherwise - attempt to
    # set one. If there is no identica - it asks the configuration.
    @identica: (identica) ->
        assert cns = "identica:compiled".toString()
        automatic = => f(@$identica or nconf.get cns)
        functional = _.isFunction identica or null
        i = (fn) => return fn.apply this, arguments
        f = (x) => if _.isFunction x then i(x) else x
        return automatic() if arguments.length is 0
        return @$identica = identica if functional
        noIdentica = "the identica is not a string"
        assert _.isString(identica), noIdentica
        assert @$identica = identica.toString()
        return @emit? "identica", arguments...

    # Create and wire in an appropriate Connext middleware that will
    # serve the specified directory as the directory with a static
    # content. That is, it will expose it to the world (not list it).
    # The serving aspects can be configured via a passed in options.
    serveStaticDirectory: (directory, options={}) ->
        assert cwd = process.cwd().toString()
        solved = paths.relative cwd, directory
        serving = "Serving %s as static assets dir"
        notExist = "The assets dir %s does not exist"
        fail = -> logger.warn notExist, solved.underline
        return fail() unless fs.existsSync directory
        middleware = connect.static directory, options
        logger.info serving.cyan, solved.underline
        @connect.use middleware; return this

    # An embedded system for adding ad-hoc configuration routines.
    # Supply the reasoning and the routine and this method will add
    # that routine to the configuration stack, to be launched once
    # the kernel boots up. With no arguments it returns the launcher.
    # This is a convenient way of running additions config routines.
    @configure: (explain, routine) ->
        log = (o) -> logger.info "Configuring: %s", o.explain.bold
        func = (t) -> (o) -> (a...) -> log o; o.routine.apply t, a
        run = arguments.length is 0 and _.isArray @$configure or 0
        assert _.isArray $configure = @$configure or new Array()
        return (-> async.series _.map $configure, func @) if run
        return (->) if not @$configure and not arguments.length
        assert _.isFunction(routine), "invalid config routine"
        assert _.isString(explain), "no explanation given"
        return (@$configure ?= []).push new Object
            explain: explain, routine: routine

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
        this.constructor.configure().call this, undefined
        return @kernelPreemption.call this, (reference) =>
            assert not _.isEmpty @setupConnectPipeline()
            assert not _.isEmpty @startupHttpsServer()
            assert not _.isEmpty @startupHttpServer()
            assert not _.isEmpty @setupSocketServers()
            assert not _.isEmpty @setupHotloadWatcher()
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
        this.interceptExceptions.call this, initializer
        return asciify branding..., (error, banner) =>
            util.puts banner.toString().blue unless error
            identify = "Running version %s, codename: %s"
            using = "Using %s class as the kernel type"
            logger.info identify.underline, types...
            logger.info using, @constructor.name.bold
            @domain.run => initializer?.apply this
            @emit "ready", initializer; return @

    # This is a little kernel registry broker that when asked to,
    # goes to the router registry and attempts to find there the
    # instance of the specified kind (class). If it succeeds then
    # it returns an instance to the invoker. If not, however, it
    # throws an assertion error about being unable to accquire.
    accquire: (kinded, silent=no) ->
        assert ident = try kinded.identify() or null
        error = "could not find a %s in the registry"
        noKinded = "the supplied arg has to be class"
        success = "Successfully accquired %s service"
        formatted = try format error, ident.toString()
        assert _.isArray registry = @router?.registry
        assert _.isObject(kinded.__super__), noKinded
        look = (fxc) -> try fxc.objectOf kinded, yes
        spoted = _.find(registry, look) or undefined
        assert _.isObject(spoted) or silent, formatted
        logger.debug success.grey, try ident.underline
        try spoted.accquired? kinded, silent; spoted

    # This routines sets up the infrastructure necessary for kernel
    # to properly intercept and process errors and exceptions. This
    # includes synchronous exceptions as well as the asynchronous
    # errors. Depending on the instance configuration this method
    # could either crash the kernel on error or proceed operations.
    interceptExceptions: ->
        assert u = moment().unix().toString()
        assert crash = "kernel:crashOnException"
        assert skill = @shutdownKernel.bind this
        assert @domain = require("domain").create()
        fatal = => skill "Fatal kernel error at U=#{u}"
        str = (err) -> err.stack or err.message or err
        @on "panic", (e) -> logger.error bark, str(e)
        @on "panic", (e) -> fatal() if nconf.get crash
        @domain.on "error", (err) => @emit "panic", err
        bark = "Kernel domain panic at U=#{u}\r\n%s".red
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
            return process.exit -1

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
            assert unix = moment().unix().toString()
            pulse = "Kernel beacon pulse at a %s UNIX"
            assert services = @router.registry or Array()
            logger.debug pulse.magenta, "#{unix}".bold
            prepared = _.map(services, eua) or Array()
            async.series prepared, (err, res) -> null

    # Instantiate a hot swapping watcher for this kernel and setup
    # the watcher per the scoping configuration to watch for certain
    # directories. Please refer to the `Watcher` implementation for
    # more information on its operations and configuration routines.
    setupHotloadWatcher: ->
        assert @watcher = new watch.Watcher this
        subjects = nconf.get("watch:dirs") or null
        config = nconf.get("layout:config") or null
        library = nconf.get("layout:library") or null
        assert _.isArray(subjects), "no watch configured"
        assert _.isString(library), "no library layout"
        assert _.isString(config), "no config layout"
        watch = @watcher.watchDirectory.bind @watcher
        watch paths.resolve __dirname, "../exposure"
        watch paths.resolve __dirname, "../semantic"
        watch directory for directory in subjects
        watch library; watch config; return this

    # The utilitary method that is being called by either the kernel
    # or scope implementation to establish the desirable facade for
    # logging. The options from the config may be used to configure
    # various options of the logger, such as output format, etc.
    setupLoggingFacade: ->
        assert _.isObject @logging = logger
        assert format = "DD/MM/YYYY @ HH:mm:ss"
        stamp = -> return moment().format format
        options = timestamp: stamp, colorize: yes
        options.level = nconf.get "log:level" or 0
        noLevel = "No logging level is specified"
        throw new Error noLevel unless options.level
        assert console = logger.transports.Console
        try do -> logger.remove console catch error
        logger.add console, options; return this

    # This routine takes care of resolving all the necessary details
    # for successfully creating and running an HTTPS (SSL) server.
    # The details are typically at least the key and the certficiate.
    # This implementation draws data from the config file and then
    # used it to obtain the necessary content and whater else needs.
    resolveSslDetails: ->
        assert secure = nconf.get "secure"; options = {}
        key = paths.relative process.cwd(), secure.key
        cert = paths.relative process.cwd(), secure.cert
        template = "Reading SSL %s file at %s".toString()
        logger.warn template.grey, "key".bold, key.underline
        logger.warn template.grey, "cert".bold, cert.underline
        logger.debug "Assembling the HTTPS options".grey
        options.key = fs.readFileSync paths.resolve key
        options.cert = fs.readFileSync paths.resolve cert
        assert options.cert.length >= 64, "invalid SSL cert"
        assert options.key.length >= 64, "invalid SSL key"
        options.secure = secure; return Object options

    # Setup and launch either HTTP or HTTPS servers to listen at
    # the configured addresses and ports. This method reads up the
    # scoping configuration in order to obtain the data necessary
    # for instantiating, configuring and launching up the servers.
    # See the method implementation for info on the exact semantic.
    startupHttpsServer: ->
        assert server = nconf.get "server" or {}
        assert hostname = nconf.get "server:host" or 0
        assert _.isNumber(server.https), "no HTTPS port"
        assert _.isObject options = @resolveSslDetails()
        running = "Running HTTPS server at %s".magenta
        arrived = "Incoming #{"HTTPS".bold} connection at %s"
        location = "#{hostname}:#{server.https}".toString()
        logger.info running.underline, location.underline
        @secure = https.createServer options, @connect
        assert _.isObject @domain; @domain.add @secure
        do => @secure.listen server.https, hostname
        return @secure.on "connection", (socket) ->
            key = socket.server?._connectionKey
            key = try key.toString().underline
            logger.debug arrived.green, key
            return socket.setNoDelay yes

    # Setup and launch either HTTP or HTTPS servers to listen at
    # the configured addresses and ports. This method reads up the
    # scoping configuration in order to obtain the data necessary
    # for instantiating, configuring and launching up the servers.
    # See the method implementation for info on the exact semantic.
    startupHttpServer: ->
        assert server = nconf.get "server" or {}
        assert hostname = nconf.get "server:host" or 0
        assert _.isNumber(server.http), "no HTTP port"
        running = "Running HTTP server at %s".magenta
        arrived = "Incoming #{"HTTP".bold} connection at %s"
        location = "#{hostname}:#{server.http}".toString()
        logger.info running.underline, location.underline
        @server = http.createServer @connect, undefined
        assert _.isObject @domain; @domain.add @server
        do => @server.listen server.http, hostname
        return @server.on "connection", (socket) ->
            key = socket.server?._connectionKey
            key = try key.toString().underline
            logger.debug arrived.green, key
            return socket.setNoDelay yes

    # Setup and attach Socket.IO handlers to each of the servers.
    # That is HTTP and HTTPS servers that are running and listening
    # for new connections. The kernel itself does not use the sockets
    # it just sets it up. Please refer to the Socket.IO docs for info.
    # Also, see the `configureSocketServers` method implementation.
    setupSocketServers: ->
        assert _.isObject sconfig = nconf.get "socket"
        logger.info "Attaching Socket.IO to HTTPS server"
        logger.info "Attaching Socket.IO to HTTP server"
        newMessage = "New Socket.IO connected at %s server"
        newSocket = (o) -> logger.debug newMessage.grey, o
        assert @secureSocket = socketio.listen @secure, sconfig
        assert @serverSocket = socketio.listen @server, sconfig
        @domain.add @serverSocket; @domain.add @secureSocket
        @secureSocket.on "connection", -> newSocket "HTTPS"
        @serverSocket.on "connection", -> newSocket "HTTP"
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
        @connect.use @compress = connect.compress()
        @connect.use @bodyParser = connect.bodyParser()
        @connect.use @cookieParser = connect.cookieParser()
        @connect.use @parameters = plumbs.parameters this
        @connect.use @xSessionId = plumbs.xSessionId this
        @connect.use @negotiate = plumbs.negotiate this
        @connect.use @platform = plumbs.platform this
        @connect.use @redirect = plumbs.redirect this
        @connect.use @session = plumbs.session this
        @connect.use @accepts = plumbs.accepts this
        @connect.use @logger = plumbs.logger this
        @connect.use @send = plumbs.send this
        @connect.use @middleware; return this

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
        assert _.isString(pub()), "no pub environment"
        assert _.isObject(opts), "wrong assets options"
        assert _.isArray(dirs), "no assets directories"
        @serveStaticDirectory d, opts for d in dirs
        @serveStaticDirectory established, Object()
        @serveStaticDirectory pub(); return this

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
        assert @router = new routing.Router this
        assert @middleware = @router.middleware
        @middleware = @middleware.bind @router
        assert _.isFunction @middleware; this
