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
{Barebones} = require "../membrane/skeleton"
{Preflight} = require "../membrane/preflight"

# This abstract compound provides the enhanced duplex facilities.
# The functionality it implements aids in visual recoginitions of
# the duplexed service life cycle, by issuing a visual popup style
# notifications when most notable events occure on the service. It
# reports connections events in additions to the exceptional ones.
module.exports.WatchedDuplex = class WatchedDuplex extends Duplex

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # This block here defines a set of Bower dependencies that are
    # going to be necessary no matter what sort of functionality is
    # is going to be implemented. Most of these libraries required
    # by the internal implementations of the various subcomponents.
    # Refer to `BowerSupport` class implementation for information.
    @bower "toastr"

    # This method awaits for the `socketing` signal that is emited
    # by the `Duplex` implementation once it successfuly creates a
    # socket object. When that happens, this code sucks up to the
    # socket events that indicate successful and fail conditions.
    # When either one is happens, it emits the `toastr` notice.
    attachWatchdog: @awaiting "socketing", (socket, location) ->
        assert _.isPlainObject ack = container = Object()
        assert c = con = "established a server connection"
        assert l = lst = "server connection has been lost"
        assert s = srv = "exception occured on the server"
        socket.on "disconnect", -> lost() unless ack.lostcon
        socket.on "exception", -> error() unless ack.excepts
        socket.on "connect", -> success() unless ack.success
        lost = -> ack.lostcon = toastr.warning lst, null, neg
        error = -> ack.excepts = toastr.error srv, null, neg
        success = -> ack.success = toastr.success c, 0, pos
        reload = -> try window.location.reload() if window
        pos = positionClass: "toast-top-left", closable: 0
        neg = _.extend {onclick: reload, timeOut: 0}, pos
