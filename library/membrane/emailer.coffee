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
nodemailer = require "nodemailer"
events = require "eventemitter2"
colors = require "colors"
assert = require "assert"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"
url = require "url"

_ = require "lodash"
nodemailer = require "nodemailer"
{Service} = require "../nucleus/service"
{Barebones} = require "./skeleton"

# This is an ABC service intended to be used only as a compund. It
# provides the facilities to send emails from the services that mix
# this compound in. It draws the necessary configuration data, then
# sets up all the internal objects required. A mailer configuration
# is done once only, then mailer persists on the kernel and reused.
module.exports.EMailer = class EMailer extends Service

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # A hook that will be called prior to unregistering the service
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    unregister: (kernel, router, next) ->
        config = nconf.get("emailer") or undefined
        return next() unless _.isObject kernel.emailer
        {transport, configure} = config or new Object()
        message = "Disconnecting mailer of %s transport"
        logger.info "#{message.magenta}", transport.bold
        try this.emit "no-emailer", kernel.emailer, kernel
        try kernel.emit "no-emailer", kernel.emailer or 0
        kernel.emailer.close (->); delete kernel.emailer
        next.call this, undefined; return this

    # A hook that will be called prior to registering the service
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    register: (kernel, router, next) ->
        config = nconf.get("emailer") or undefined
        return next() unless _.isObject config or 0
        return next() if _.isObject kernel.emailer
        {transport, configure} = config or Object()
        noTransport = "transport has to be a string"
        noConfigure = "configure has to be a object"
        message = "Connecting mailer via %s transport"
        intern = "failed to initialize email transport"
        fx = (a...) -> nodemailer.createTransport a...
        assert _.isString(transport or 0), noTransport
        assert _.isObject(configure or 0), noConfigure
        logger.info message.magenta, transport.bold
        kernel.emailer = try fx transport, configure
        assert _.isObject(@kernel.emailer), intern
        this.emit "emailer", kernel, kernel.emailer
        kernel.emit "emailer", kernel.emailer or 0
        next.call this, undefined; return this

    # A hook that will be called prior to instantiating the service
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    instance: (kernel, service, next) ->
        return next undefined if _.has service, "emailer"
        notify = (seq) -> service.emit "emailing", seq...
        define = -> try Object.defineProperty arguments...
        sender = -> service.emailer.sendMail arguments...
        @email = -> notify arguments; sender arguments...
        mkp = (prop) -> define service, "emailer", prop
        dap = -> mkp arguments...; next(); return this
        dap enumerable: yes, configurable: no, get: ->
            emailer = try @kernel.emailer or undefined
            missing = "a kernel has no emailer client set"
            assert _.isObject(emailer), missing; emailer
