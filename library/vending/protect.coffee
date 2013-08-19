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
http = require "http"
util = require "util"
url = require "url"

_ = require "lodash"
api = require "../nucleus/api"
stubs = require "../nucleus/stubs"
tools = require "../nucleus/tools"
boiler = require "../nucleus/boiler"
service = require "../nucleus/service"
extendz = require "./../nucleus/extends"

# This is an abstract base class API stub service. Its purpose is
# providing the boilerplate for ensuring that the connection is
# going through the HTTPS channel. If a request is not going via
# SSL transport then redirect the current request to such one.
module.exports.SecureStub = class SecureStub extends boiler.Standard

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    @abstract yes

    # A hook that will be called prior to invoking the API method
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. If this returns a
    # truthful boolean, the service will NOT call implementation.
    # Please be sure invoke the super implementation, if override!
    preprocess: (request, response, resource, domain) ->
        preprocess = @upstack SecureStub, "preprocess"
        return yes if preprocess?.apply @, arguments
        connection = request?.connection
        encrypted = connection?.encrypted
        return if _.isObject encrypted
        protectedUrl = tools.urlWithHost yes
        current = url.parse protectedUrl
        current.pathname = request.url
        current.query = request.params
        compiled = url.format current
        response.redirect compiled
        response.headersSent
