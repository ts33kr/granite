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

{format} = require "util"
{RedisStore} = require "socket.io"
{Archetype} = require "./arche"

# This is an abstract base class component that contains a set of
# essential kernel tools and utilities, basically - the toolchain.
# This component should be used in the actual kernel implementation
# to segregate the core functionality of the kernel from utilities
# that are common for nearly every kernel. These tools are meant to
# lift the routine that is usually involved in the kernel classes.
module.exports.KernelTools = class KernelTools extends Archetype

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

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
        assert comp = "identica:compiled" # config key
        automatic = => f(@$identica or nconf.get comp)
        functional = _.isFunction identica or false
        i = (fn) => return fn.apply this, arguments
        f = (x) => if _.isFunction x then i(x) else x
        return automatic() if arguments.length is 0
        return @$identica = identica if functional
        noIdentica = "this identica is not a string"
        m = "Setting up identica to %s within the %s"
        assert _.isString idc = try this.identify()
        assert _.isString(identica or 0), noIdentica
        logger?.silly? m.red, identica.red.bold, idc
        assert @$identica = identica.toString()
        return @emit? "identica", arguments...

    # This is a little kernel registry broker that when asked to,
    # goes to the router registry and attempts to find there the
    # instance of the specified kind (class). If it succeeds then
    # it returns an instance to the invoker. If not, however, it
    # throws an assertion error about being unable to accquire.
    accquire: (kinded, silent=no) ->
        usage = "method has been used incrorrectly"
        sign = "should be called with the class arg"
        assert (arguments.length or NaN) >= 1, usage
        assert _.isObject(kinded or undefined), sign
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

    # This routine takes care of resolving all the necessary details
    # for successfully creating and running an HTTPS (SSL) server.
    # The details are typically at least the key and the certficiate.
    # This implementation draws data from the config file and then
    # used it to obtain the necessary content and whater else needs.
    resolveSslDetails: ->
        options = new Object() # container for SSL
        missingKey = "the secure.key setting missing"
        missingCert = "the secure.cert setting missing"
        assert _.isObject secure = nconf.get "secure"
        assert _.isString(try secure.key), missingKey
        assert _.isString(try secure.cert), missingCert
        key = paths.relative process.cwd(), secure.key
        cert = paths.relative process.cwd(), secure.cert
        template = "Reading SSL %s file at %s".toString()
        logger.warn template.grey, "key".bold, key.underline
        logger.warn template.grey, "cert".bold, cert.underline
        logger.debug "Assembling the SSL/HTTPS options".green
        do -> options.key = fs.readFileSync paths.resolve key
        do -> options.cert = fs.readFileSync paths.resolve cert
        assert options.cert.length >= 64, "invalid SSL cert"
        assert options.key.length >= 64, "invalid SSL key"
        options.secure = secure; return options # SSL

    # The utilitary method that is being called by either the kernel
    # or scope implementation to establish the desirable facade for
    # logging. The options from the config may be used to configure
    # various options of the logger, such as output format, etc.
    # Please see the methods source and the `Winston` library docs.
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
        m = "Installed kernel logging facade of %s"
        assert identify = this.constructor.identify()
        logger.add console, options # re-assemble it
        logger.silly m.yellow, identify.yellow.bold
        return this # return self-ref for chaining

    # Create and wire in an appropriate Connext middleware that will
    # serve the specified directory as the directory with a static
    # content. That is, it will expose it to the world (not list it).
    # The serving aspects can be configured via a passed in options.
    # Please see the method source code for more information on it.
    serveStaticDirectory: (directory, options={}) ->
        sdir = "no directory string is supplied"
        usage = "method has been used a wrong way"
        assert (arguments.length or 0) >= 1, usage
        assert _.isString(directory or null), sdir
        assert cwd = try process.cwd().toString()
        solved = try paths.relative cwd, directory
        serving = "Serving %s as static assets dir"
        notExist = "The assets dir %s does not exist"
        fail = -> logger.warn notExist, solved.underline
        return fail() unless fs.existsSync directory
        middleware = connect.static directory, options
        logger.info serving.cyan, solved.underline
        try @connect.use middleware; return this
