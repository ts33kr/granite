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
        assert l = @t "server connection has been lost"
        assert s = @t "exception occured on the server"
        assert c = @t "established connection to server"
        pos = positionClass: "toast-top-left" # location
        bhv = tapToDismiss: 0, closable: 0 # set behavior
        ntm = timeOut: 0, extendedTimeOut: 0 # timeouts
        drn = hideDuration: 300, showDuration: 300 # ms
        assert try _.extend ntm, _.extend pos, bhv, drn
        assert _.isFunction db = (f) -> _.debounce f, 500
        assert _.isFunction clear = toastr.clear # alias
        wclear = -> $(".toast-warning").hide().remove()
        dropd = db -> wclear(); toastr.warning l, 0, ntm
        connd = db -> clear(); toastr.success c, 0, pos
        error = db -> clear(); toastr.error s, 0, pos
        try $root?.on "disconnect", => dropd.call @
        try $root?.on "exception", => error.call @
        try $root?.on "connect", => connd.call @
