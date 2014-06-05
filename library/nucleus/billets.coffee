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

assert = require "assert"
logger = require "winston"
uuid = require "node-uuid"
crypto = require "crypto"
colors = require "colors"
async = require "async"
nconf = require "nconf"
http = require "http"
util = require "util"
url = require "url"

_ = require "lodash"
extendz = require "./extends"
routing = require "./routing"
scoping = require "./scoping"

{format} = require "util"
{Archetype} = require "./archetype"
{urlOfServer} = require "./tools"
{urlOfMaster} = require "./tools"

# This abstract base class is a part of the internal implementation
# of the services infrastructure. It holds a set of methods defined
# on the service prototypes that do not pertain to the essential ones.
# In other words, it is just a container with a set of utility tools
# that are used in the implementation of this particular subsystem.
# This class is known to be used only by the `Service` as its ABC.
module.exports.ServiceBillets = class ServiceBillets extends Archetype

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # This method provides a handy, convenient tool for obtainting a
    # stringified identificator tag (a reference) for a service class.
    # This tag is supposed to be something between machine and human
    # readable. Typically, this is a short hash function, such as an
    # MD5 hash represented (stringified) with HEX digesting mechanism.
    @reference: ->
        installed = try _.isString @$reference
        return @$reference if installed is yes
        noOrigin = "#{identify()} has no origin"
        assert hasher = crypto.createHash "md5"
        assert location = @origin.id, noOrigin
        assert factor = "#{location}:#{@identify()}"
        digest = hasher.update(factor).digest "hex"
        assert digest; return @$reference = digest

    # This method is a tool for obtaining a fully qualified path to
    # access to the resource, according to the HTTP specification.
    # This includes details such as host, port, path and alike. The
    # method knows how to disambiguate between SSL and non SSL paths.
    # Do not confuse it with `location` method that deals locations.
    @qualified: (master=yes) ->
        int = "internal error getting qualified"
        noLocation = "the service has no location"
        securing = require "../membrane/securing"
        assert not _.isEmpty(@location()), noLocation
        isProtected = this.derives securing.OnlySsl
        sel = master and urlOfMaster or urlOfServer
        link = sel.call this, isProtected, @location()
        assert not _.isEmpty(link), int; return link

    # Either obtain or set the HTTP location of the current service.
    # If not location has been set, but the one is requested then
    # the deduced default is returned. Default location is the first
    # resource regular expression pattern being unescaped to string.
    # Do not confuse it with `qualified` method that deals with URL.
    @location: (location) ->
        current = => try @$location or automatic
        automatic = _.head(@resources)?.unescape()
        return current() if arguments.length is 0
        isEmpty = "the location must not be empty"
        noLocation = "the location is not a string"
        assert _.isString(location), noLocation
        assert not _.isEmpty(location), isEmpty
        @$location = location.toString(); this
