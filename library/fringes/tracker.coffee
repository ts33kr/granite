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
logger = require "winston"
colors = require "colors"
async = require "async"
nconf = require "nconf"

{Behavior} = require "../gearbox/behavior"
{DuplexCore} = require "../membrane/duplex"

# This compound is a parasite that hosts itself to all standalone
# services and monitors the duplex connection of the root service.
# When the state of the connection changes, that is - dropped or
# renewed, this service issues a visual notification of the event.
# Notifications are implemented as nice little pop-ups that carry
# the connection event information, text and color coded, usually.
module.exports.DuplexTracker = class DuplexTracker extends Behavior

    # Make the current service available to the specified roles of
    # authenticated accounts, utilizing the `Policies` component.
    # The signature is either a role name (as a string) or object
    # with the 'alias: role' signature. Where alias is a key that
    # represents the member name to use for inclusion in the root.
    # The function can be supplied to do further decision making.
    # Please refer to `Auxiliaries` class and `@parasite` method.
    @available $watchdog: "everyone"

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
    monitoring: @awaiting "socketing", (socket, location) ->
        assert l = i18n "server connection has been lost"
        assert s = i18n "exception occured on the server"
        assert c = i18n "established connection to server"
        assert $root is $host, "parasite on wrong service"
        pos = positionClass: "toast-top-right" # location
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
