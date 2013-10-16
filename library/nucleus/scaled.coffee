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
logger = require "winston"
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

{Generic} = require "./kernel"

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

    # Setup and launch either HTTP or HTTPS servers to listen at
    # the configured addresses and ports. This method reads up the
    # scoping configuration in order to obtain the data necessary
    # for instantiating, configuring and launching up the servers.
    # This version goes to the Seaport hub to obtain the options!
    startupHttpServer: ->
        assert _.isObject config = nconf.get()
        assert _.isObject(@seaport), "no seaport"
        msg = "Got HTTP port from the Seaport: %s"
        assert identica = @constructor.identica()
        cfg = config: config, identica: identica
        record = @seaport.register identica, cfg
        assert _.isNumber(record), "got mistaken"
        logger.info msg.green, "#{record}".bold
        assert config?.server?.http = record
        nconf.set config; super; return @

    # Setup and launch either HTTP or HTTPS servers to listen at
    # the configured addresses and ports. This method reads up the
    # scoping configuration in order to obtain the data necessary
    # for instantiating, configuring and launching up the servers.
    # This version goes to the Seaport hub to obtain the options!
    startupHttpsServer: ->
        assert _.isObject config = nconf.get()
        assert _.isObject(@seaport), "no seaport"
        msg = "Got HTTPS port from the Seaport: %s"
        assert identica = @constructor.identica()
        cfg = config: config, identica: identica
        record = @seaport.register identica, cfg
        assert _.isNumber(record), "got mistaken"
        logger.info msg.green, "#{record}".bold
        assert config?.server?.https = record
        nconf.set config; super; return @

    # A configuration routine that ensures the scope config has the
    # Seaport hub related configuration data. If so, it proceeds to
    # retrieving that info and using it to locate and connect to a
    # Seaport hub, which is then installed as the kernel instance
    # variable, so that it can be accessed by the other routines.
    @configure "the service discovery hub", (next) ->
        assert _.isString host = nconf.get "hub:host"
        assert _.isNumber port = nconf.get "hub:port"
        assert _.isObject opts = nconf.get "hub:opts"
        @seaport = seaport.connect host, port, opts
        assert _.isObject(@seaport), "seaport failed"
        assert @seaport.register?, "a broken seaport"
        shl = "#{host}:#{port}".toString().underline
        msg = "Locate a Seaport hub at #{shl}".blue
        logger.info msg; return next undefined
