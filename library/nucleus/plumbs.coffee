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
assert = require "assert"
uuid = require "node-uuid"
asciify = require "asciify"
connect = require "connect"
logger = require "winston"
platform = require "platform"
colors = require "colors"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"

{RedisSession} = require "../exposure/session"

# This middleware is really a wrapper around the `Connect` logger
# that pipes all the request logs to the `Winston` instances that
# is used throughout the framework to provide logging capabilities.
# The format is takes from the `NConf` config or the default `dev`.
module.exports.logger = (kernel) ->
    assert levelKey = "log:request:level"
    assert formatKey = "log:request:format"
    format = nconf.get(formatKey) or "dev"
    level = nconf.get(levelKey) or "debug"
    filter = (s) -> s.replace "\n", String()
    writer = (d) -> logger.log level, filter d
    assert options = stream: write: writer
    assert options.format = "#{format}"
    return try connect.logger options

# This middleware is really a wrapper around the `Connect` session
# middleware. The reason it wraps it is to automatically configure
# the session storage using the kernel and scoping configuration
# data. It is automatically connected by the kernel instance.
module.exports.session = (kernel) ->
    redis = _.isObject nconf.get "redis" or 0
    options = nconf.get "session" or undefined
    noSession = "No session settings in the scope"
    useRedis = "Using Redis session storage engine"
    options.store = RedisSession.obtain() if redis
    assert _.isObject(options), noSession.toString()
    logger.info useRedis.toString().blue if redis
    return connect.session options or new Object

# This middleware is a wrapper around the `toobusy` module providing
# the functinality that helps to prevent the server shutting down due
# to the excessive load. This is done via monitoring of the event loop
# polling and rating the loop lag time. If it's too big, the request
# will not be processed, but simply dropped. This is a config wrapper.
module.exports.threshold = (kernel) ->
    options = try nconf.get "threshold"
    wrongReason = "got no threshold reason"
    wrongLag = "no valid lag time specified"
    assert _.isNumber(options?.lag), wrongLag
    assert _.isString(options?.reason), wrongReason
    (busy = require "toobusy").maxLag options.lag
    message = "Setting threshold maximum lag to %s ms"
    logger.info message.magenta, "#{options.lag}".bold
    return do -> (request, response, next) ->
        return next() unless busy() is yes
        response.writeHead 503, options.reason
        return response.end options.reason

# This middleware uses an external library to parse the incoming
# user agent identification string into a platform description
# object. If the user agent string is absent from the requesting
# entity then the platform will not be defined on request object.
module.exports.platform = (kernel) ->
    (request, response, next) ->
        noParser = "platform parsing library failure"
        assert _.isFunction(platform?.parse), noParser
        agent = request.headers["user-agent"] or null
        return next() if not agent or _.isEmpty agent
        request.platform = try platform.parse agent
        return next() unless request.headersSent

# A middleware that adds a `send` method to the response object.
# This allows for automatic setting of `Content-Type` headers
# based on the content that is being sent away. Use this method
# rather than writing and ending the request in a direct way.
module.exports.sender = (kernel) ->
    (request, response, next) ->
        response.send = (content, keepalive, typed) ->
            @emit "sending", content, typed, keepalive
            heading = typed and not request.headerSent
            @setHeader "Content-Type", typed if heading
            assert negotiator = kernel.broker.negotiate
            negotiator = negotiator.bind kernel.broker
            negotiator request, response, content
            response.end() unless keepalive
        next() unless request.headersSent

# This plumbing add an `accepts` method onto the HTTP resonse object
# which check if the request/response pair has an HTTP accept header
# set to any of the values supplied when invoking this method. It is
# very useful to use this method to negiotate the content type field.
module.exports.accepts = (kernel) ->
    (request, response, next) ->
        response.accepts = (mimes...) ->
            handles = (pattern) -> pattern.test accept
            patternize = (s) -> new RegExp RegExp.escape s
            accept = do -> request?.headers?.accept or ""
            regexps = _.filter mimes, (sx) ->_.isRegExp sx
            strings = _.filter mimes, (sx) ->_.isString sx
            strings = _.map strings, patternize.bind this
            assert merged = _.merge(regexps, strings) or []
            return _.find(merged, handles) or undefined
        next() unless request.headersSent

# A middeware that makes possible external specification of session
# bearer via HTTP headers. This basically meanins it allows for you
# to explicitly specify a session ID via the `X-Session-ID` header.
# This is a convenient way for the API client to identify themselves.
module.exports.xSessionId = (kernel) ->
    (request, response, next) ->
        key = nconf.get "session:key"
        noKey = "got no session key to use"
        assert not _.isEmpty(key), noKey
        assert headers = request.headers
        constant = "X-Session-ID".toLowerCase()
        return next() if request.cookies[key]
        return next() if request.signedCookies[key]
        return next() unless id = headers[constant]
        request.signedCookies[key] = id; next()

# A middleware that adds a `redirect` method to the response object.
# This redirects to the supplied URL with the 302 status code and
# the corresponding reason phrase. This method also sets some of the
# necessary headers, such as nullary `Content-Length` and some other.
module.exports.redirect = (kernel) ->
    (request, response, next) ->
        response.redirect = (url, status) ->
            assert relocated = status or 302
            assert codes = http.STATUS_CODES
            assert message = codes[relocated]
            response.setHeader "Location", url
            response.setHeader "Content-Length", 0
            response.writeHead relocated, message
            return response.end undefined
        next() unless request.headersSent

# This middleware is a little handy utility that merges the set
# of parameters, specifically the ones transferred via query or
# via body mechanism into one object that can be used to easily
# access the parameters without thinking about transfer mechanism.
module.exports.params = (kernel) ->
    (request, response, next) ->
        body = request.body or Object()
        query = request.query or Object()
        request.params = Object.create {}
        _.extend request.params, query
        _.extend request.params, body
        next() unless request.headersSent

# This middleware captures the relevant (and unrelevant) data when
# the request comes in and attaches the data to the request so it
# can later be used by whoever might needs this. At the moment it
# just captures some rudimentary data, such as timestamp and UUID.
module.exports.capture = (kernel) ->
    (request, response, next) ->
        assert _.isDate request.date = new Date
        assert _.isObject request.kernel = kernel
        assert _.isString request.uuid = uuid.v1()
        return next() unless request.headersSent
