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
yaml = require "js-yaml"
assert = require "assert"
asciify = require "asciify"
connect = require "connect"
request = require "request"
logger = require "winston"
colors = require "colors"
async = require "async"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"

{external} = require "../membrane/remote"
{Barebones} = require "../membrane/skeleton"
{Preflight} = require "../membrane/preflight"
{DuplexCore} = require "../membrane/duplex"

# This abstract compound provides the message localization services.
# It is implemented as a tiny, but unified toolkit that includes all
# the necessary instrumentation for the client site as well as for
# the server site to perform text (message) internationalisation. It
# shares the same concepts as I18N, Gettext and other similar kits.
module.exports.Localized = class Localized extends DuplexCore

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # This class-defined constant is intended to be used within
    # the framework itself. It points to the directory that has
    # all the embedded translation table files. These file are
    # used only by the services and components that are shipped
    # with the framework. The ones that actually constitute it.
    @EMBEDDED_LOCALE: "#{__dirname}/../../locale"

    # Define a set of considerations used by this service. An every
    # consideration is one key/value pair. Where the key corresponds
    # to the type name (also known as token) and the value is holding
    # either an implementation function or a remotable type (an alias).
    # This allows you to override type definitions that may be used in
    # a parent classes, without having to replace implementation code.
    # Allows to inject arbitrary lexical-local values to external fns.
    @considering i18tt: external inline: yes, -> this.tt
    @considering i18th: external inline: yes, -> this.th
    @considering i18tn: external inline: yes, -> this.t

    # An implementation of the standard, system hook in order for
    # providing a static boilerplate that is used to bring up the
    # localization toolkit prior to the internal machinery coming
    # up. This is necessary to provide the ability to translating
    # certain services that are booted well before all the wiring.
    # A bit of black magic is used here, for a later refactoring.
    prelude: (symbol, context, request, next) ->
        assert inline = context.inline.bind context
        assert sender = context.transit.bind context
        assert shadow = Object.create this # isolated
        assert shader = __isolated: true, __origin: @
        try _.extend shadow, session: request.session
        try _.extend shadow, request: request or null
        try _.extend shadow, shader # shade the context
        translation = @obtainTranslation # get provider
        setup = @setupTranslationTools # get installing
        execute = (a...) => translation.apply shadow, a
        spoof = (l, c) -> c @_tmpLanguage, @_tmpMessages
        assert _.isFunction try trx = sender or undefined
        return execute undefined, (language, messages) =>
            do -> assert context._tmpLanguage = language
            do -> assert context._tmpMessages = messages
            trx spoof, (f) -> this.obtainTranslation = f
            trx setup, (f) -> @setupTranslationTools = f
            (inline -> @setupTranslationTools()); next()

    # A routine intended for server side execution inside of the
    # services that need to use the translation toolkit during the
    # server side operations, such as context rendering and alike.
    # This routine internally uses the same code that is used when
    # the translation toolkit is loaded on the client side. Method
    # implements some of the necessary scaffolding to invoke that
    # same code in the standalone, server side environment itself.
    this::i18n = this::withTranslation = (implement) ->
        noImplement = "have no implementation function"
        noIsolation = "the source scope is not isolated"
        assert _.isFunction(implement or 0), noImplement
        assert _.isObject(@request or null), noIsolation
        assert silence = (message) -> # empty logging fn
        assert ident = @constructor.identify().underline
        assert notify = "Translation scope in %s for %s"
        counts = "Offload %s translations in %s into scope"
        args = [@translationLanguage, @translationMessages]
        return implement.apply this, args if _.isFunction @t
        this.session = @request.session unless @session
        this.setupTranslationTools silence, (lng, msg) =>
            assert not _.isEmpty(lng), "got no language"
            assert _.isObject(msg), "got no translation"
            try count = _.keys(msg).length.toString().bold
            try logger.debug notify.grey, lng.bold, ident
            try logger.debug counts.grey, count, lng.bold
            return implement.apply this, arguments

    # An automatically called external routine that will take care
    # of setting up the client site part of the translation toolkit.
    # This implementation requests the necessary translation tables
    # off the server provider. Once is acknowledged, a client side
    # routines are setup and associated with the language and table.
    setupTranslationTools: @awaiting "booted", (log, ack) ->
        unexpected = "received malformed translation"
        unrecognized = "unrecognized language received"
        noted = "Loaded %s translation messages for %s"
        sel = "Using %s as the language selector for %s"
        return if _.isFunction @t # do not double call
        assert _.isFunction logging = log or logger.info
        assert _.isFunction sprintf = _.sprintf # format
        pt = (o, v, key) -> delete o[key]; o[lc key] = v
        lc = (src) => return src.toString().toLowerCase()
        rx = (src) => @translationMessages?[lc src] or src
        try _.transform this.translationMessages or 0, pt
        uservice = @service?.underline?.blue or undefined
        message = "Install i18 & translation tookit for %s"
        logging message.magenta, (try uservice.magenta)
        this.t = (s, a...) => sprintf "#{rx(s)}", a...
        this.th = (s, a...) => _.humanize this.t s, a...
        this.tt = (s, a...) => _.titleize this.t s, a...
        @obtainTranslation 0, (language, translation) =>
            assert _.isString(language), unrecognized
            assert _.isObject(translation), unexpected
            length = _.keys(translation).length.toString()
            assert this.translationMessages = translation
            assert this.translationLanguage = language
            logging noted, length.bold.blue, uservice
            logging sel, language.bold.blue, uservice
            return ack language, translation if ack

    # An out-of-the-box isolated provider that exposes translation
    # messages, provided by the service in the language requested.
    # If no language is explicitly asked, the compound will try to
    # extract the language selector out of the user session. Refer
    # to this provider (and compoudt) implementation for details.
    obtainTranslation: @isolated (language, callback) ->
        assert compiler = @compileTranslationMessages
        assert compiler = compiler.bind @ # fix scoping
        @constructor.compiledTranslations ?= compiler()
        assert cache = @constructor.compiledTranslations
        assert session = @session, "no session detected"
        delete @session.language unless @session.langlock
        negotiator = new require("negotiator") @request
        neg = negotiator.language(_.keys(cache) or [])
        selector = language or @session.language or neg
        selector = selector or "en" # hardcoded default
        assert not _.isEmpty(sel = selector), "lang fail"
        @session.language ?= sel if neg and sel isnt "en"
        assert messages = cache[selector] or new Object
        amount = _.keys(messages).length # of messages
        banner = "Loaded %s messages for %s in %s".grey
        assert identify = try @constructor.identify()
        logger.debug banner, amount, identify, selector
        assert _.isFunction(callback), "invalid callback"
        assert selected = cache[selector] or new Object
        assert fallback = _.clone cache.en or Object()
        callback selector, _.merge fallback, selected

    # Walk over all of the declared translation message locations
    # and try loading messages off the every declared location. All
    # the messages will be merged into one object, indexed by the
    # languages names as keys. Colliding keys are overriden. Every
    # YAML document is treated as a translation for one language.
    # Please, never execute this method directly, since it is very
    # heavy on reasources and should be shadowed with the caching.
    compileTranslationMessages: ->
        assert sreader = require("fs").readFileSync
        assert resolve = join = require("path").join
        identify = @constructor.identify().underline
        e = "UTF-8" # all messages files must be UTF-8
        collector = {} # will hold the translation map
        assert translations = @constructor.translation()
        deduce = (t) -> t.f = join t.directory, t.location
        t.blob = sreader deduce(t), e for t in translations
        processing = (f) -> _.each translations, f; collector
        processing (t) -> try yaml.safeLoadAll t.blob, (doc) ->
            assert loc = t.location, "got invalid location"
            message = "Get translation for %s at %s".cyan
            logger.debug message, identify, loc.underline
            noLanguage = "got incorrect translation file"
            assert (language = doc[t.select]), noLanguage
            previous = collector[language] or new Object
            collector[language] = _.merge previous, doc
            do -> delete collector[language][t.select]

    # Specify the translation file for the current service. This
    # file is meant to contain and provide internationalization
    # messages. These are the strings to use for displaying with
    # different languages. File format is YAML with the special
    # structure that embeds multiple languages in a single file.
    # If second argument is a string, is treated as dir option.
    @translation: (location, options={}) ->
        options = dir: options if _.isString options
        assert not _.isEmpty cwd = try process.cwd()
        assert previous = @translations or new Array()
        return previous if arguments.length is 0 # get
        implicit = "locale" # default dir for messages
        noLocation = "the location has to be a string"
        noOptions = "no suitable options are supplied"
        directory = options.dir or "#{cwd}/#{implicit}"
        select = options.sel or "$translation-language"
        assert _.isString(location or 0), noLocation
        assert _.isObject(options or 0), noOptions
        return this.translations = previous.concat
            directory: directory.toString()
            location: location.toString()
            options: options or Object()
            select: select.toString()
