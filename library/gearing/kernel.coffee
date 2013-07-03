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
http = require "http"
util = require "util"

_ = require "lodash"
bundles = require "./bundles"
routing = require "./routing"
service = require "./service"
scoping = require "./scoping"

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
        specification = "../../package"
        @package = require specification
        branding = [@package.name, "larry3d"]
        types = [@package.version, @package.codename]
        asciify branding..., (error, banner) =>
            util.puts banner.toString().blue unless error
            identify = "Running kernel %s, codename: %s"
            logger.info(identify.underline, types...)
            initializer?.apply(this)

    # Create a new instance of the kernel, run all the prerequisites
    # that are necessary, do the configuration on the kernel, then
    # boot it up, using the hostname and port parameters from config.
    # Please use this static method instead of manually launching up.
    @bootstrap: -> new Kernel ->
        nconf.env().argv()
        @setupRoutableServices()
        @setupConnectPipeline()
        port = nconf.get("server:port")
        hostname = nconf.get("server:hostname")
        message = "Booted up the kernel instance".red
        running = "Running HTTP server at %s:%s".magenta
        logger.info(running, hostname, port)
        @server.listen(port, hostname)
        logger.info(message); this

    # This method sets up the necessary internal toolkits, such as
    # the determined scope and the router, which is then are wired
    # in with the located and instantiated services. Please refer
    # to the implementation on how and what is being done exactly.
    setupRoutableServices: ->
        tag = nconf.get("NODE_ENV")
        passes = _.isString(tag)
        c = (s) => @router.registerRoutable new s
        noTag = "No NODE_ENV variable found"
        throw new Error(noTag) unless passes
        @scope = scoping.Scope.lookupOrFail tag
        @scope.incorporate this
        @router = new routing.Router(this)
        @middleware = @router.lookupMiddleware
        @middleware = @middleware.bind(@router)
        c(s) for s in @scope.services or []

    # Setup the Connect middleware framework along with the default
    # pipeline of middlewares necessary for the Flames framework to
    # operate correctly. You are encouraged to override this method
    # to provide a Connect setup procedure to your own liking, etc.
    setupConnectPipeline: (middlewares...) ->
        @connect = connect()
        @connect.use(connect.query())
        @connect.use(connect.favicon())
        @connect.use(connect.bodyParser())
        @connect.use(connect.cookieParser())
        @connect.use m for m in middlewares
        @server = http.createServer(@connect)
        @connect.use(@middleware)
