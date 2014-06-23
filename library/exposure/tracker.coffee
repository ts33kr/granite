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

{external} = require "../membrane/remote"
{Auxiliaries} = require "../membrane/auxes"
{Localized} = require "../exposure/localized"
{Barebones} = require "../membrane/skeleton"
{Preflight} = require "../membrane/preflight"
{DuplexCore} = require "../membrane/duplex"
{Embedded} = require "../membrane/embed"

# This compound is a parasite that hosts itself to all standalone
# services and monitors the duplex connection of the root service.
# When the state of the connection changes, that is - dropped or
# renewed, this service issues a visual notification of the event.
# Notifications are implemented as nice little pop-ups that carry
# the connection event information, text and color coded, usually.
module.exports.DuplexTracker = class DuplexTracker extends Embedded

    # This block here defines a set of Bower dependencies that are
    # required by the client site part of the code that constitutes
    # this service or compound. Dependencies can be restricted to a
    # certain version and also they can have customized entrypoint.
    # Refer to `BowerSupport` class implementation for information.
    @bower "toastr#2.0.x"

    # These declarations below are implantations of the abstracted
    # components by the means of the dynamic recomposition system.
    # Please take a look at the `Composition` class implementation
    # for all sorts of information on the composition system itself.
    # Each of these will be dynamicall integrated in class hierarchy.
    @implanting Auxiliaries, DuplexCore, Localized

    # This block contains declarations that control the auxilliary
    # services inclusion and the parasite services specifications.
    # For more information on a both subjects, please refer to the
    # implementation of the `Auxiliaries` components. Specifically
    # look at the class methods `aux` and `parasite` source codes.
    @parasite $watchdog: @ROOT_CONFORMS_TO DuplexCore

    # This block here defines a set of translation files that are
    # used by the service. Please keep in mind, that translations
    # are inherited from all of the base classes, and the tookit
    # then loads each translation file and combines all messages
    # into one translation table that is used throughout service.
    @translation "tracked.yaml", @EMBEDDED_LOCALE

    # This method awaits for the `socketing` signal that is emited
    # by the `DuplexCore` implementation once it successfuly creates
    # socket object. When that happens, this code sucks up to the
    # socket events that indicate successful and fail conditions.
    # When either one is happens, it emits the `toastr` notice. A
    # most recent method implementation uses `$root` as a subject.
    attachWatchdog: @awaiting "socketing", (socket, location) ->
        assert l = @t "server connection has been lost"
        assert s = @t "exception occured on the server"
        assert c = @t "established connection to server"
        assert $root is $host, "parasite on wrong service"
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
        try $root.on "disconnect", => dropd.call @
        try $root.on "exception", => error.call @
        try $root.on "connect", => connd.call @
