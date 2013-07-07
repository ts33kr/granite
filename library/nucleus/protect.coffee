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
tools = require "../nucleus/tools"
service = require "../nucleus/service"

# This is an abstract base class API stub service. Its purpose is
# providing the boilerplate for ensuring that the connection is
# going through the HTTPS channel. If a request is not going via
# SSL transport then redirect the current request to such one.
module.exports.StubWithSsl = class StubWithSsl extends api.Stub

    # A hook that will be called prior to invoking the API method
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. If this returns a
    # truthful boolean, the service will NOT call implementation.
    # Please be sure invoke the super implementation, if override!
    preprocess: (request, response, resource, domain) ->
        protectedUrl = tools.urlWithHost yes
        return if super request, response, resource, domain
        return if encrypted = request?.connection?.encrypted
        current = pathname: request.url, query: request.params
        current.host = protectedUrl;  current.protocol = "https"
        response.redirect url.format current; response.headersSent
