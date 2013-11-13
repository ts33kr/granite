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

{format} = require "util"

{external} = require "../membrane/remote"
{Barebones} = require "../membrane/skeleton"
{Preflight} = require "../membrane/preflight"

# This abstract compound provides the internal service API for the
# automatic generation of necessary links and then inclusion of the
# required tags to use the confgured fonts provided by the Google
# Fonts service that generates the CSS stylesheets with settings.
# Please refer to the Google docs to get info on the fonts format.
module.exports.GoogleFonts = class GoogleFonts extends Preflight

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # This server side method is called on the context prior to the
    # context being compiled and flushed down to the client site. The
    # method is wired in an asynchronous way for greater functionality.
    # This is the place where you would be importing the dependencies.
    # Pay attention that most implementations side effect the context.
    prelude: (symbol, context, request, next) ->
        googlefonts = @constructor.googlefonts or []
        assert _.isArray(googlefonts), "invalid fonts"
        assert googlefonts = try googlefonts.reverse()
        j = (strc) -> return strc.typographs.join ","
        t = "http://fonts.googleapis.com/css?family=%s"
        foldtyp = (x) -> family: x.family, joined: j(x)
        infusor = (fx) -> "#{fx.family}:#{fx.joined}"
        extract = (record) -> try return record.family
        googlefonts = _.unique googlefonts, extract
        assert prepped = _.map googlefonts, foldtyp
        assert infused = try _.map prepped, infusor
        assert not _.isEmpty blob = infused.join "|"
        context.sheets.push format t, blob; next()

    # Add the described font to the font request that is going to be
    # compiled and emited when the context is assembled. Description
    # of a font is formed of a font family name and a vector of the
    # typographic descriptions, such as sizes and styles. Values in
    # the vector can be strings or any others - all are stringified.
    @googlefont: (family, typographs...) ->
        string = (val) -> return val.toString()
        isntEmpty = -> not _.isEmpty arguments...
        assert previous = @googlefonts or Array()
        empty = "got an empty font typograph handler"
        assert _.isString(family), "no valid family"
        assert _.isArray(typographs), "no typographs"
        assert typographs = _.map typographs, string
        assert _.all(typographs, isntEmpty), empty
        @googlefonts = previous.concat new Object
            family: family.replace /\s/g, "+"
            typographs: _.toArray typographs

    # This is the composition hook that gets invoked when compound
    # is being composed into other services and components. Merges
    # together added jscripts found in both hierarchies, the current
    # one and the foreign (the one that is beign merged in). Exists
    # for backing up the consistent behavior when using composition.
    @composition: (destination) ->
        assert currents = this.googlefonts or Array()
        previous = destination.googlefonts or Array()
        return unless destination.derives GoogleFonts
        assert previous? and try _.isArray previous
        assert merged = previous.concat currents
        assert merged = _.toArray _.unique merged
        assert try destination.googlefonts = merged
        try super catch error finally return this
