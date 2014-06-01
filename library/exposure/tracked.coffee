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

{Duplex} = require "../membrane/duplex"
{external} = require "../membrane/remote"
{Localized} = require "../exposure/localized"
{Barebones} = require "../membrane/skeleton"
{Preflight} = require "../membrane/preflight"

# This abstract compound provides the enhanced duplex facilities.
# The functionality it implements aids in visual recoginitions of
# the duplexed service life cycle, by issuing a visual popup style
# notifications when most notable events occure on the service. It
# reports connections events in additions to the exceptional ones.
module.exports.TrackedDuplex = class TrackedDuplex extends Duplex

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # These declarations below are implantations of the abstracted
    # components by the means of the dynamic recomposition system.
    # Please take a look at the `Composition` class implementation
    # for all sorts of information on the composition system itself.
    # Each of these will be dynamicall integrated in class hierarchy.
    @implanting Localized

    # This block here defines a set of translation files that are
    # used by the service. Please keep in mind, that translations
    # are inherited from all of the base classes, and the tookit
    # then loads each translation file and combines all messages
    # into one translation table that is used throughout service.
    @translation "tracked.yaml", @EMBEDDED_LOCALE

    # This block here defines a set of Bower dependencies that are
    # required by the client site part of the code that constitutes
    # this service or compound. Dependencies can be restricted to a
    # certain version and also they can have customized entrypoint.
    # Refer to `BowerSupport` class implementation for information.
    @bower "toastr#2.0.x"

    # This method awaits for the `socketing` signal that is emited
    # by the `Duplex` implementation once it successfuly creates a
    # socket object. When that happens, this code sucks up to the
    # socket events that indicate successful and fail conditions.
    # When either one is happens, it emits the `toastr` notice.
    attachWatchdog: @awaiting "socketing", (socket, location) ->
        assert l = lst = @t "server connection has been lost"
        assert s = srv = @t "exception occured on the server"
        assert r = rcn = @t "attempting to restore connection"
        assert c = con = @t "established connection to server"
        pos = positionClass: "toast-top-left", closable: null
        ntm = timeOut: 0, extendedTimeOut: 0, tapToDismiss: 0
        xtm = timeOut: 3000, extendedTimeOut: 1000 # a duplex
        assert _.extend object, pos for object in [ntm, xtm]
        deb = ((f) -> _.debounce f, 500); clear = toastr.clear
        wclear = -> return $(".toast-warning").hide().remove()
        recon = _.debounce (-> toastr.info r, null, xtm), 100
        dropd = deb -> wclear(); toastr.warning lst, 0, ntm
        connd = deb -> clear(); toastr.success con, 0, pos
        error = deb -> clear(); toastr.error srv, 0, pos
        do => $root?.on "reconnecting", => recon.call @
        do => $root?.on "disconnect", => dropd.call @
        do => $root?.on "exception", => error.call @
        do => $root?.on "connect", => connd.call @
