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
assert module.exports.EmailClient = class EmailClient extends Service

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # These defintions are the presets available for configuring
    # the email envelope getting functions. Please set the special
    # class value `EMAIL_ENVELOPE` to either one of these values or
    # to a custom function that will generate/retrieve the mailer
    # envelope, when necessary. Depending on this, the system will
    # generate a new connection on the container, if it does not
    # contain an opened connection yet. The default container is
    # the kernel preset using the `EMAIL_ENVELOPE_KERNEL` value.
    @EMAIL_ENVELOPE_KERNEL = -> return @kernel
    @EMAIL_ENVELOPE_SERVICE = -> @$email ?= {}

    # A hook that will be called prior to unregistering the service
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    # This implementation correctly ends email connection, if any.
    unregister: (kernel, router, next) ->
        @constructor.EMAIL_ENVELOPE ?= -> kernel
        envelope = this.constructor.EMAIL_ENVELOPE
        envelope = try envelope.apply this, arguments
        config = try nconf.get("emailer") or undefined
        return next() unless _.isObject config or null
        return next() unless _.isObject kernel.emailer
        noConfig = "missing the emailer configuration"
        {transport, configure} = config or new Object()
        msg = "Disconnecting mail client of %s transport"
        logger.info msg.underline.magenta, transport.bold
        try @emit "no-emailer", envelope.emailer, envelope
        try kernel.emit "no-emailer", envelope.emailer
        envelope.emailer.close (-> return) # empty CB
        delete envelope.emailer if envelope.emailer?
        next.call this, undefined; return this

    # A hook that will be called prior to registering the service
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    # This implementation open a new mailer connection, if configed.
    register: (kernel, router, next) ->
        @constructor.EMAIL_ENVELOPE ?= -> kernel
        envelope = this.constructor.EMAIL_ENVELOPE
        envelope = envelope.apply this, arguments
        config = nconf.get("emailer") or undefined
        return next() unless _.isObject config or 0
        return next() if _.isObject envelope.emailer
        {transport, configure} = config or Object()
        noTransport = "transport has to be as a string"
        noConfigure = "configure has to be as a object"
        msg = "Connecting mail client via %s transport"
        internal = "fail to initialize email transport"
        fx = (a...) -> nodemailer.createTransport a...
        assert _.isString(transport or 0), noTransport
        assert _.isObject(configure or 0), noConfigure
        logger.info msg.underline.magenta, transport.bold
        envelope.emailer = try fx transport, configure
        assert _.isObject(envelope.emailer), internal
        @emit "email-ok", envelope, envelope.emailer
        kernel.emit "email-ok", envelope.emailer
        next.call this, undefined; return this

    # A hook that will be called prior to instantiating the service
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    # This implementation sets the mailer connection access handle.
    instance: (kernel, service, next) ->
        @constructor.EMAIL_ENVELOPE ?= -> kernel
        envelope = this.constructor.EMAIL_ENVELOPE
        envelope = try envelope.apply this, arguments
        identify = try @constructor.identify().underline
        sending = "Sending an email off %s service".yellow
        return next undefined if _.has service, "emailer"
        @on "emailing", -> logger.warn sending, identify
        @email = -> notify arguments; sender arguments...
        ack = "Acquire e-mail client handle in %s".grey
        sig = => this.emit "email-ok", @emailer or null
        notify = (seq) -> service.emit "emailing", seq...
        define = -> try Object.defineProperty arguments...
        sender = -> service.emailer.sendMail arguments...
        mkp = (prop) -> define service, "emailer", prop
        dap = -> mkp arguments...; next(); sig(); this
        dap enumerable: yes, configurable: no, get: ->
            emailer = try envelope.emailer or undefined
            missing = "an envelope has no e-mail client"
            try logger.debug ack, try identify.underline
            assert _.isObject(emailer), missing; emailer
