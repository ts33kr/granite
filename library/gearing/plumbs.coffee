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
events = require "events"
colors = require "colors"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"

# A middleware that adds a `send` method to the response object.
# This allows for automatic setting of `Content-Type` headers
# based on the content that is being sent away. Use this method
# rather than writing and ending the request in a direct way.
module.exports.sender = (kernel) ->
    (request, response, next) ->
        response.send = (content, typed, keepAlive) ->
            @setHeader "Content-Type", typed if typed?
            return @write content.toString() if typed?
            negotiator = kernel.broker.negotiate
            negotiator = negotiator.bind kernel.broker
            negotiator request, response, content
            response.end() unless keepAlive
        next() unless request.headersSent

# This plumbing add an `accepts` method onto the HTTP resonse object
# which check if the request/response pair has an HTTP accept header
# set to any of the values supplied when invoking this method. It is
# very useful to use this method to negiotate the content type field.
module.exports.accepts = (kernel) ->
    (request, response, next) ->
        response.accepts = (mimes...) ->
            accept = request?.headers?.accept or ""
            handles = (pattern) -> pattern.test accept
            patternize = (s) -> new RegExp RegExp.escape s
            regexps = _.filter mimes, (x) ->_.isRegExp x
            strings = _.filter mimes, (x) ->_.isString x
            strings = _.map strings, patternize
            merged = _.merge regexps, strings
            _.find merged, handles
        next() unless request.headersSent

# This middleware is really a wrapper around the `Connect` logger
# that pipes all the request logs to the `Winston` instances that
# is used throughout the framework to provide logging capabilities.
# The format is takes from the `NConf` config or the default `dev`.
module.exports.logger = (kernel) ->
    levelKey = "log:request:level"
    formatKey = "log:request:format"
    format = nconf.get(formatKey) or "dev"
    level = nconf.get(levelKey) or "debug"
    filter = (string) -> string.replace "\n", ""
    writer = (data) -> logger.log level, filter data
    options = stream: write: writer
    options.format = format
    connect.logger options
