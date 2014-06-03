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
assert = require "assert"
events = require "eventemitter2"
colors = require "colors"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"
url = require "url"

{Barebones} = require "./skeleton"
{RedisClient} = require "./redis"
tools = require "../nucleus/tools"

# This is an abstract base class API stub service. Its purpose is
# providing the boilerplate for ensuring that the connection is
# going through the master server! If a request is not going via
# master server then deny current request with an error code. Be
# aware that this compound will be effective for all HTTP methods.
module.exports.OnlyMaster = class OnlyMaster extends Barebones

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # A hook that will be called prior to firing up the processing
    # of the service. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    ignition: (request, response, next) ->
        str = (addr) -> addr?.address or null
        inbound = request.connection.address()
        assert server = @kernel.server.address()
        assert secure = @kernel.secure.address()
        assert not _.isEmpty "#{str(inbound)}"
        assert master = nconf.get "master:host"
        return next() if str(inbound) is str(server)
        return next() if str(inbound) is str(secure)
        return next() if str(inbound) is master
        content = "please use the master server"
        reason = "an attempt of direct access"
        response.writeHead 401, "#{reason}"
        return response.end content

# This is an abstract base class API stub service. Its purpose is
# providing the boilerplate for ensuring that the connection is
# going through the HTTPS channel. If a request is not going via
# SSL transport then redirect the current request to such one. Be
# aware that this compound will be effective for all HTTP methods.
module.exports.OnlySsl = class OnlySsl extends OnlyMaster

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # A hook that will be called prior to firing up the processing
    # of the service. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    ignition: (request, response, next) ->
        connection = request.connection or {}
        encrypted = connection.encrypted or no
        assert headers = request.headers or {}
        protocol = headers["x-forwarded-proto"]
        return next() if _.isObject encrypted
        return next() if protocol is "https"
        protectedUrl = tools.urlOfMaster yes
        current = try url.parse protectedUrl
        assert current.pathname = request.url
        assert current.query = request.params
        assert compiled = url.format current
        return response.redirect compiled
