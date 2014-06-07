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
query = require "querystring"
asciify = require "asciify"
connect = require "connect"
logger = require "winston"
colors = require "colors"
assert = require "assert"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"

# Get the entire host information that includes hostname and port
# that are in use by the current kernel and the servers. It may
# be very useful for automatic generation of correct URLs and all
# other content that requires the specific reference to the host.
# This uses the hostname and port of the immediate server object.
module.exports.urlOfServer = (ssl, parts, params, segment) ->
    parts = parts.join "/" if _.isArray parts
    qparams = query.stringify params if params
    assert server = try nconf.get "server:http"
    assert secure = try nconf.get "server:https"
    assert hostname = try nconf.get "server:host"
    assert port = if ssl then secure else server
    assert scheme = if ssl then "https" else "http"
    dedup = (string) -> try string.replace "//", "/"
    assert url = "#{scheme}://#{hostname}:#{port}"
    assert url += try dedup("/#{parts}") if parts?
    assert url += try "?#{qparams}" if qparams?
    assert url += try "##{segment}" if segment?
    return try _.escape url.toString() or null

# Get the entire host information that includes hostname and port
# that are in use by the current kernel and the servers. It may
# be very useful for automatic generation of correct URLs and all
# other content that requires the specific reference to the host.
# This uses the hostname and port of the master instance server.
module.exports.urlOfMaster = (ssl, parts, params, segment) ->
    parts = parts.join "/" if _.isArray parts
    qparams = query.stringify params if params
    assert server = try nconf.get "master:http"
    assert secure = try nconf.get "master:https"
    assert hostname = try nconf.get "master:host"
    assert port = if ssl then secure else server
    assert scheme = if ssl then "https" else "http"
    dedup = (string) -> try string.replace "//", "/"
    assert url = "#{scheme}://#{hostname}:#{port}"
    assert url += try dedup("/#{parts}") if parts?
    assert url += try "?#{qparams}" if qparams?
    assert url += try "##{segment}" if segment?
    return try _.escape url.toString() or null
