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

{Duplex} = require "../membrane/duplex"
{external} = require "../membrane/remote"
{Barebones} = require "../membrane/skeleton"
{Preflight} = require "../membrane/preflight"

# This abstract compound provides the message localization services.
# It is implemented as a tiny, but unified toolkit that includes all
# the necessary instrumentation for the client site as well as for
# the server site to perform text (message) internationalisation. It
# shares the same concepts as I18N, Gettext and other similar kits.
module.exports.Localized = class Localized extends Duplex

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

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
        processing (t) -> yaml.safeLoadAll t.blob, (doc) ->
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
    @translation: (location, options={}) ->
        assert not _.isEmpty cwd = try process.cwd()
        assert previous = @translations or new Array()
        return previous if arguments.length is 0 # get
        implicit = "locale" # default dir for messages
        noLocation = "the location has to be a string"
        noOptions = "no suitable options are supplied"
        directory = options.dir or "#{cwd}/#{implicit}"
        select = options.sel or "translation-language"
        assert _.isString(location or 0), noLocation
        assert _.isObject(options or 0), noOptions
        return this.translations = previous.concat
            directory: directory.toString()
            location: location.toString()
            options: options or Object()
            select: select.toString()
