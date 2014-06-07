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
send = require "response-send"
platform = require "platform"
colors = require "colors"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"

{Negotiator} = require "negotiator"
{RedisSession} = require "../exposure/session"

# This middleware is really a wrapper around the `Connect` logger
# that pipes all the request logs to the `Winston` instances that
# is used throughout the framework to provide logging capabilities.
# The format is takes from the `NConf` config or the default `dev`.
# Refer to the implementation source code for more information.
module.exports.logger = (kernel) ->
    assert levelKey = "log:request:level"
    assert formatKey = "log:request:format"
    format = try nconf.get(formatKey) or "dev"
    level = try nconf.get(levelKey) or "debug"
    filter = (s) -> s.replace "\n", new String()
    writer = (d) -> logger.log level, filter d
    msg = "Configure logger middleware at U=%s"
    assert _.isObject(kernel), "got no kernel"
    assert stamp = moment().unix().toString()
    options = new Object stream: write: writer
    assert options.format = format.toString()
    logger.debug msg.toString(), stamp.bold
    return try connect.logger options or {}

# This middleware is really a wrapper around the `Connect` session
# middleware. The reason it wraps it is to automatically configure
# the session storage using the kernel and scoping configuration
# data. This is automatically connected by the kernel instance.
# Refer to the implementation source code for more information.
module.exports.session = (kernel) ->
    nso = "no session configuration options"
    assert options = try nconf.get("session")
    assert shallow = try _.clone options or {}
    assert _.isObject(kernel), "got no kernel"
    redis = _.isObject nconf.get("redis") or 0
    assert _.isObject(options), nso.toString()
    assert ux = moment().unix().toString().bold
    useRedis = "Using Redis session storage engine"
    message = "Configure session middleware at U=%s"
    shallow.store = RedisSession.obtain() if redis
    logger.debug message.toString(), ux.toString()
    logger.info useRedis.toString().blue if redis
    return connect.session shallow or new Object

# This middleware is a wrapper around the `toobusy` module providing
# the functinality that helps to prevent the server shutting down due
# to the excessive load. This is done via monitoring of the event loop
# polling and rating the loop lag time. If it's too big, the request
# will not be processed, but simply dropped. This is a config wrapper.
module.exports.threshold = (kernel) ->
    wrongReason = "no threshold reason supplied"
    wrongLagTime = "no valid lag time specified"
    noHeaders = "unable to locate request headers"
    options = nconf.get("threshold") or Object()
    assert _.isNumber(options?.lag), wrongLagTime
    assert _.isString(options?.reason), wrongReason
    assert _.isObject(kernel), "no kernel supplied"
    (busy = require "toobusy").maxLag try options.lag
    message = "Setting threshold maximum lag to %s ms"
    logger.info message.red, options.lag.toString().bold
    return (request, response) -> # middleware itself
        assert unix = moment().unix().toString().bold
        assert _.isObject(request?.headers), noHeaders
        message = "Running threshold middleware at U=%s"
        logger.debug message.toString(), unix.toString()
        assert _.isFunction next = _.last arguments
        return next undefined unless busy() is yes
        response.writeHead 503, options.reason
        return response.end options.reason

# This middleware uses an external library to parse the incoming
# user agent identification string into a platform description
# object. If the user agent string is absent from the requesting
# entity then the platform will not be defined on request object.
# Refer to the implementation source code for more information.
module.exports.platform = (kernel) -> (request, response) ->
    intern = "could not parse the platform data"
    noParser = "platform parse library malfunction"
    noPlatform = "missing platform middleware lib"
    noHeaders = "unable to locate request headers"
    assert _.isObject(platform or null), noPlatform
    assert _.isObject(request?.headers), noHeaders
    assert _.isFunction(platform?.parse), noParser
    agent = request.headers["user-agent"] or null
    return next() if not agent or _.isEmpty agent
    assert unix = moment().unix().toString().bold
    message = "Running platform middleware at U=%s"
    logger.debug message.toString(), unix.toString()
    request.platform = try (platform.parse agent)
    assert _.isObject(request.platform), intern
    assert _.isFunction next = _.last arguments
    return next() unless request.headersSent

# This middleware uses an external library to parse the incoming
# request metadata and then coerce it by using the standards to
# a queriable form. This queriable forms allows to negotiate for
# media types, accepted encoding, accepted language and so on.
# Middleware can be used to serve the most appropriare content.
module.exports.negotiate = (kernel) -> (request, response) ->
    terrible = "no valid request object found"
    noLibrary = "could not load negotiator lib"
    acked = "could not instantiate a negotiator"
    noHeaders = "unable to locate request headers"
    assert _.isObject(kernel), "no kernel supplied"
    assert _.isObject(Negotiator or 0), noLibrary
    assert _.isObject(request or null), terrible
    assert _.isObject(request?.headers), noHeaders
    request.negotiate = Negotiator request or {}
    assert _.isObject(request.negotiate), acked
    assert unix = moment().unix().toString().bold
    message = "Running negotiate middleware at U=%s"
    logger.debug message.toString(), unix.toString()
    assert _.isFunction next = _.last arguments
    return next() unless request.headersSent

# A middleware that adds a `send` method to the response object.
# This allows for automatic setting of `Content-Type` headers
# based on the content that is being sent away. Use this method
# rather than writing and ending the request in a direct way.
# Is implemented using the external `response-send` library.
module.exports.send = (kernel) -> (request, response) ->
    ack = "could not attach response sender method"
    noLibrary = "could not load the sender library"
    terrible = "got no valid response object found"
    noHeaders = "unable to locate request headers"
    assert _.isObject(kernel), "no kernel supplied"
    assert _.isFunction(try (send.json)), noLibrary
    assert _.isObject(response or null), terrible
    assert _.isObject(request?.headers), noHeaders
    assert (try response.send = send), ack.toString()
    assert response.json = try (send.json spaces: 4)
    try response.req = request unless response.req
    assert unix = moment().unix().toString().bold
    message = "Running sending middleware at U=%s"
    logger.debug message.toString(), unix.toString()
    assert _.isFunction next = _.last arguments
    return next() unless request.headersSent

# This plumbing add an `accepts` method onto the HTTP resonse object
# which check if the request/response pair has an HTTP accept header
# set to any of the values supplied when invoking this method. It is
# very useful to use this method to negiotate the content type field.
# This is a very dummy way of asking if a client supports something,
# for a propert content negotiation please see the `send` plumbing.
module.exports.accepts = (kernel) -> (request, response) ->
    noHeaders = "unable to locate request headers"
    terribles = "got no valid response object found"
    assert _.isObject(kernel), "no kernel supplied"
    assert _.isObject(request?.headers), noHeaders
    assert _.isObject(response or null), terribles
    response.accepts = (mimes...) -> # response func
        handles = (pattern) -> try pattern.test accept
        patternize = (s) -> new RegExp RegExp.escape s
        accept = do -> request?.headers?.accept or ""
        regexps = _.filter mimes, (sx) ->_.isRegExp sx
        strings = _.filter mimes, (sx) ->_.isString sx
        strings = _.map strings, patternize.bind this
        assert merged = try _.merge(regexps, strings)
        return _.find(merged, handles) or undefined
    assert unix = moment().unix().toString().bold
    message = "Running accepting middleware at U=%s"
    logger.debug message.toString(), unix.toString()
    assert _.isFunction next = _.last arguments
    return next() unless request.headersSent

# A middleware that adds a `redirect` method to the response object.
# This redirects to the supplied URL with the 302 status code and
# the corresponding reason phrase. This method also sets some of the
# necessary headers, such as nullary `Content-Length` and some other.
# The redirected-to URL should be a valid, qualified URL to send to.
module.exports.redirect = (kernel) ->
    assert redirect = "Redirecting from %s to %s"
    noHeaders = "unable to locate request headers"
    terribles = "got no valid response object found"
    assert _.isObject(kernel), "no kernel supplied"
    assert codes = http.STATUS_CODES or new Object()
    return (request, response) -> # middleware itself
        assert _.isObject(request?.headers), noHeaders
        assert _.isObject(response or null), terribles
        assert _.isFunction next = try _.last arguments
        assert response.redirect = (url, status) ->
            assert to = try url.toString().underline
            assert from = try request.url?.underline
            assert relocated = status or 302 or null
            assert message = codes[relocated] or null
            response.setHeader "Location", url # to
            response.setHeader "Content-Length", 0
            response.writeHead relocated, message
            logger.debug redirect.red, from, to
            return try response.end undefined
        assert unix = moment().unix().toString().bold
        message = "Running redirect middleware at U=%s"
        logger.debug message.toString(), unix.toString()
        return next() unless request.headersSent

# A middeware that makes possible external specification of session
# bearer via HTTP headers. This basically means - it allows for you
# to explicitly specify a session ID via the `X-Session-ID` header.
# It is a convenient way for the API client to identify themselves.
# Beware that it might be used by clients to for misrepresentation.
module.exports.extSession = (kernel) -> (request, response) ->
    key = nconf.get("session:key") or undefined
    enable = nconf.get("session:enableExternal")
    noKey = "no session key have been configured"
    noHeaders = "unable to locate request headers"
    terribles = "got no valid response object found"
    assert _.isObject(kernel), "no kernel supplied"
    assert _.isObject(request?.headers), noHeaders
    assert _.isObject(response or null), terribles
    assert not _.isEmpty(key or 0), noKey.toString()
    assert headers = request.headers or new Object()
    assert constant = "X-Session-ID".toLowerCase()
    assert unix = moment().unix().toString().bold
    message = "Running extSession middleware at U=%s"
    logger.debug message.toString(), unix.toString()
    assert _.isFunction next = _.last arguments
    return next() unless enable and enable is yes
    return next() if request.cookies?[key] or 0
    return next() if request.signedCookies[key]
    return next() unless id = headers[constant]
    request.signedCookies[key] = id; next()

# This middleware is a little handy utility that merges the set
# of parameters, specifically the ones transferred via query or
# via body mechanism into one object that can be used to easily
# access the parameters without thinking about transfer mechanism.
# This method also does capturing of some of the internal params.
module.exports.parameters = (kernel) -> (request, response) ->
    noHeaders = "unable to locate request headers"
    terribles = "got no valid response object found"
    assert _.isObject(kernel), "no kernel supplied"
    assert _.isObject(request?.headers), noHeaders
    assert _.isObject(response or null), terribles
    assert try query = request.query or new Object()
    assert try body = request.body or new Object()
    assert _.isObject request.params = new Object()
    try _.extend request.params, query # query params
    try _.extend request.params, body # body params
    assert try request.date = new Date # timstamped
    assert try request.kernel = kernel # kernelized
    assert try request.uuid = uuid.v1() # UUID tag
    assert unix = moment().unix().toString().bold
    message = "Running parameters middleware at U=%s"
    logger.debug message.toString(), unix.toString()
    assert _.isFunction next = _.last arguments
    return next() unless request.headersSent
