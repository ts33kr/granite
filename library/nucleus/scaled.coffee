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
asciify = require "asciify"
connect = require "connect"
seaport = require "seaport"
Keygrip = require "keygrip"
Cookies = require "cookies"
logger = require "winston"
uuid = require "node-uuid"
moment = require "moment"
colors = require "colors"
assert = require "assert"
async = require "async"
nconf = require "nconf"
https = require "https"
paths = require "path"
http = require "http"
util = require "util"
fs = require "fs"

{format} = require "util"
{Generic} = require "./kernel"
{HttpProxy} = require "http-proxy"

# This is the descendant of the generic kernel that implements the
# scaling of the framework across an arbitrary clustered processes
# or even machines. It is built on top of a set of the Node.js based
# technologies, such as service discovery library alongside with a
# library that allows for effective proxying of the HTTP requests.
# Normally this kernel should always be preferred over Generic one!
module.exports.Scaled = class Scaled extends Generic

    # This sets up the default identica for this kernel. It forms
    # an identica of a certain recommended format and populates it
    # with data takes from the `PACKAGE` definition in a `Generic`
    # kernel. Refer to that kernel and to `identica` method there
    # for more information on semantics and the way of working it.
    @identica "#{@PACKAGE.name}@#{@PACKAGE.version}"

    # The kernel preemption routine is called once the kernel has
    # passed the initial launching and configuration phase, but is
    # yet to start up the router, connect services and instantiate
    # an actual application. This method gets passes continuation
    # that does that. The method can either invoke it or omit it.
    kernelPreemption: (continuation) ->
        assert _.isObject(@options), "got no options"
        either = @options.master or @options.instance
        assert either, "no master and no instance mode"
        return continuation() unless @options.master
        logger.warn "The kernel is booting as master"
        assert nconf.get("master"), "no master config"
        assert not _.isEmpty @createSeaportServer()
        assert not _.isEmpty @startupHttpsMaster()
        assert not _.isEmpty @startupHttpMaster()
        continuation.call @ if @options.instance

    # Prepare and setup an HTTPS master server. This server is the
    # proxy server that is going to consume all the HTTPS requests
    # and load balance the request to some of the instances. Please
    # refer to the `node-http-proxy` library for info on the proxy.
    # Also see `makeForward` method for details on load balancing!
    startupHttpsMaster: ->
        assert _.isArray q = @queueOfHttps ?= Array()
        assert _.isObject options = @resolveSslDetails()
        assert _.isString host = nconf.get "master:host"
        assert _.isNumber port = nconf.get "master:https"
        assert registr = @makeRegistrar q, "http", null
        assert selectr = @makeSelectors q, "http", null
        assert forward = @makeForwarder q, "http", selectr
        assert upgrade = @makeUpgraders q, "http", selectr
        remove = (s) -> _.remove q, (x) -> s.uuid is x.uuid
        @secureProxy = https.createServer options, forward
        assert _.isObject @domain; @domain.add @secureProxy
        assert @secureProxy; @secureProxy.listen port, host
        @secureProxy.on "upgrade", -> upgrade arguments...
        running = "Master HTTPS server at %s".bold
        location = "#{host}:#{port}".toString().underline
        logger.info running.underline.magenta, location
        @spserver.on "free", (service) -> remove service
        @spserver.on "register", registr; return this

    # Prepare and setup an HTTP master server. This server is the
    # proxy server that is going to consume all the HTTP requests
    # and load balance the request to some of the instances. Please
    # refer to the `node-http-proxy` library for info on the proxy.
    # Also see `makeForward` method for details on load balancing!
    startupHttpMaster: ->
        assert _.isArray q = @queueOfHttp ?= Array()
        assert _.isString host = nconf.get "master:host"
        assert _.isNumber port = nconf.get "master:http"
        assert registr = @makeRegistrar q, "http", null
        assert selectr = @makeSelectors q, "http", null
        assert forward = @makeForwarder q, "http", selectr
        assert upgrade = @makeUpgraders q, "http", selectr
        remove = (s) -> _.remove q, (x) -> s.uuid is x.uuid
        assert @serverProxy = http.createServer forward
        assert _.isObject @domain; @domain.add @serverProxy
        assert @serverProxy; @serverProxy.listen port, host
        @serverProxy.on "upgrade", -> upgrade arguments...
        running = "Master HTTP server at %s".bold
        location = "#{host}:#{port}".toString().underline
        logger.info running.underline.magenta, location
        @spserver.on "free", (service) -> remove service
        @spserver.on "register", registr; return this

    # This is a factory method that produces handlers invoked on
    # discovering a new service on the Seaport hub. This handler
    # examines the service to decide if it suits the parameters
    # passed to the factory, and if so - add it to the registry
    # of available services that are rotated using round-robin.
    makeRegistrar: (queue, kind) -> (service) =>
        assert ids = @constructor.identica()
        config = Object https: kind is "https"
        compile = (s) -> "#{s.role}@#{s.version}"
        return undefined unless service.kind is kind
        return undefined unless compile(service) is ids
        options = @resolveSslDetails() if config.https
        _.extend config, https: options if config.https
        where = host: service.host, port: service.port
        assert merged = _.extend config, target: where
        merged.target.https = service.kind is "https"
        merged.target.rejectUnauthorized = false
        queue.push proxy = new HttpProxy merged
        assert _.isString proxy.uuid = service.uuid
        proxy.on "proxyError", (err, req, res) =>
            msg = "got an error talking to backend: %s"
            res.writeHead 500, "a proxy backend error"
            res.end format msg, err.toString(); this

    # This is a factory method that produces methods that dispatch
    # requests to the corresponding backend proxied server. It is
    # the direct implementor of the round-robin rotation algorithm.
    # Beware howeber that is also implements the sticky session algo
    # based on setting and getting the correctly signed req cookies.
    makeSelectors: (queue, kind) -> (request, response) =>
        encrypted = request.connection.encrypted
        response.set = yes # a hack for `cookies` module
        response.getHeader = (key) -> [key.toLowerCase()]
        ltp = (u) -> _.find queue, (srv) -> srv.uuid is u
        rrb = -> assert p = queue.shift(); queue.push p; p
        sticky = "Sticky %s request %s of %s".toString()
        assert url = "#{request.url}".underline.yellow
        assert x = (encrypted and "HTTPS" or "HTTP").bold
        assert secret = nconf.get "session:secret" or null
        keygrip = new Keygrip [secret], "sha256", "hex"
        cookies = new Cookies request, response, keygrip
        xbackend = cookies.get "xbackend", signed: yes
        return rrb() unless nconf.get "balancer:sticky"
        assert _.isObject proxy = ltp(xbackend) or rrb()
        configure = signed: yes, overwrite: yes, httpOnly: no
        s = cookies.set "xbackend", proxy.uuid, configure
        a = "#{proxy.target.host}:#{proxy.target.port}"
        assert a = "#{a.toLowerCase().underline.yellow}"
        logger.debug sticky, x.bold, url, a if xbackend
        assert s.response is response; return proxy

    # This is a factory method that produces request forwarders.
    # These are directly responsible for proxying an HTTP request
    # from the master server (frontend) to actual server (backend)
    # that does the job of handling the request. The forwarder is
    # also responsible for rotating (round-robin) servers queue!
    makeForwarder: (queue, kind, select) -> (request, response) =>
        encrypted = request.connection.encrypted
        assert u = "#{request.url}".underline.yellow
        assert x = (encrypted and "HTTPS" or "HTTP").bold
        reason = "no instances found behind a frontend"
        msg = "the frontend has no instances to talk to"
        assert _.isArray(queue), "got invalid proxy queue"
        response.writeHead 504, reason if _.isEmpty queue
        return response.end(msg) and no if _.isEmpty queue
        assert proxy = select.apply this, arguments
        a = "#{proxy.target.host}:#{proxy.target.port}"
        assert a = "#{a.toLowerCase().underline.yellow}"
        logger.debug "Proxy %s request %s to %s", x, u, a
        return proxy.proxyRequest arguments...

    # This is a factory method that that produces the specialized
    # request handler that is fired when an `upgrade` is requested
    # on one of the master servers. This is the functionality that
    # is required for WebSockets and other similar transports to
    # perform its operation correctly in a distributed environment.
    makeUpgraders: (queue, kind, select) -> (request, response) =>
        encrypted = request.connection.encrypted
        assert u = "#{request.url}".underline.yellow
        assert x = (encrypted and "HTTPS" or "HTTP").bold
        reason = "no instances found behind a frontend"
        msg = "the frontend has no instances to talk to"
        assert _.isArray(queue), "got invalid proxy queue"
        response.writeHead 504, reason if _.isEmpty queue
        return response.end(msg) and no if _.isEmpty queue
        assert proxy = select.apply this, arguments
        a = "#{proxy.target.host}:#{proxy.target.port}"
        assert a = "#{a.toLowerCase().underline.yellow}"
        logger.debug "Proxy %s upgrade %s to %s", x, u, a
        return proxy.proxyWebSocketRequest arguments...

    # Create and launch a Seaport server in the current kernel. It
    # draws the configuration from the same key as Seaport client
    # uses. This routine should only be invoked when the kernel is
    # launched in the master mode, generally. The method wires in
    # some handlers into the Seaport to track hosts come and go.
    createSeaportServer: ->
        r = "Discovered service %s at %s".green
        f = "Disconnect service %s at %s".yellow
        create = "Created the Seaport server at %s"
        assert identica = try @constructor.identica()
        assert _.isString host = nconf.get "hub:host"
        assert _.isNumber port = nconf.get "hub:port"
        assert _.isObject opts = nconf.get "hub:opts"
        c = (srv) -> "#{srv.role}@#{srv.version}".bold
        l = (h, p) -> "#{h}:#{p}".toLowerCase().underline
        log = (m, s) -> logger.info m, c(s), l(s.host, s.port)
        match = (s) -> "#{s.role}@#{s.version}" is identica
        assert @spserver = seaport.createServer opts or {}
        assert _.isObject @domain; @domain.add @spserver
        logger.info create.toString().magenta, l(host, port)
        @spserver.on "register", (s) -> log r, s if match s
        @spserver.on "free", (s) -> log f, s if match s
        try @spserver.listen port, host catch error
            message = "Seaport server failed\r\n%s"
            logger.error message.red, error.stack
            return process.exit -1

    # A configuration routine that ensures the scope config has the
    # Seaport hub related configuration data. If so, it proceeds to
    # retrieving that info and using it to locate and connect to a
    # Seaport hub, which is then installed as the kernel instance
    # variable, so that it can be accessed by the other routines.
    @configure "access service Seaport hub", (next) ->
        assert _.isString host = nconf.get "hub:host"
        assert _.isNumber port = nconf.get "hub:port"
        assert _.isObject opts = nconf.get "hub:opts"
        @seaport = seaport.connect host, port, opts
        assert _.isObject(@seaport), "seaport failed"
        assert @seaport.register?, "a broken seaport"
        shl = "#{host}:#{port}".toString().underline
        msg = "Locate a Seaport hub at #{shl}".blue
        logger.info msg; return next undefined

    # Setup and launch either HTTP or HTTPS servers to listen at
    # the configured addresses and ports. This method reads up the
    # scoping configuration in order to obtain the data necessary
    # for instantiating, configuring and launching up the servers.
    # This version goes to the Seaport hub to obtain the options!
    startupHttpsServer: ->
        type = "https".toUpperCase().bold
        assert _.isObject config = nconf.get()
        assert _.isObject(@seaport), "no seaport"
        msg = "Got #{type} port from the Seaport: %s"
        assert identica = @constructor.identica()
        cfg = config: config, identica: identica
        _.extend cfg, uuid: uuid.v4(), kind: "https"
        _.extend cfg, token: @token or undefined
        record = @seaport.register identica, cfg
        assert _.isNumber(record), "got mistaken"
        logger.info msg.green, "#{record}".bold
        assert config?.server?.https = record
        nconf.set config; super; return this

    # Setup and launch either HTTP or HTTPS servers to listen at
    # the configured addresses and ports. This method reads up the
    # scoping configuration in order to obtain the data necessary
    # for instantiating, configuring and launching up the servers.
    # This version goes to the Seaport hub to obtain the options!
    startupHttpServer: ->
        type = "http".toUpperCase().bold
        assert _.isObject config = nconf.get()
        assert _.isObject(@seaport), "no seaport"
        msg = "Got #{type} port from the Seaport: %s"
        assert identica = @constructor.identica()
        cfg = config: config, identica: identica
        _.extend cfg, uuid: uuid.v4(), kind: "http"
        _.extend cfg, token: @token or undefined
        record = @seaport.register identica, cfg
        assert _.isNumber(record), "got mistaken"
        logger.info msg.green, "#{record}".bold
        assert config?.server?.http = record
        nconf.set config; super; return this
