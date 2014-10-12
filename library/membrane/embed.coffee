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
bower = require "bower"
asciify = require "asciify"
connect = require "connect"
logger = require "winston"
events = require "eventemitter2"
assert = require "assert"
colors = require "colors"
crypto = require "crypto"
nconf = require "nconf"
https = require "https"
path = require "path"
http = require "http"
util = require "util"

{Barebones} = require "./skeleton"
{Screenplay} = require "./visual"
{Preflight} = require "./preflight"
{Zombie} = require "../nucleus/zombie"
{Extending} = require "../nucleus/extends"
{Composition} = require "../nucleus/compose"
{Archetype} = require "../nucleus/arche"
{BowerToolkit} = require "../applied/bower"

{remote, external} = require "./remote"
{TransferToolkit} = require "./transfer"
{TransitToolkit} = require "./transit"
{EventsToolkit} = require "./events"
{LinksToolkit} = require "./linkage"

# This abstract base class service is a combination of `Screenplay`
# and `Zombie` for the further environment initialization and seting
# up. These preparations will be nececessary no matter what sort of
# `Screenplay` functionality you are going to implement. Currently the
# purpose of preflight is drawing in the remotes and Bower packages.
# It is intended for the embeddable services, such as auxilliaries.
module.exports.Embedded = class Embedded extends Zombie

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
    @implanting Preflight

    # This is a functional hook that is automatically wired into the
    # composition system. It gets invoked once a composition system
    # has completed implanting a foreign component into this class,
    # which is on the receiving side. This implementation ensures
    # that after the composition is done, the service is still be
    # considered a `Zombie` service with all attributes pertained.
    this.implanted = this.ensureZombie = (compound) ->
        i = "no compound class supplied to the hook"
        assert _.isObject(comp = compound or null), i
        assert sident = try this.identify().underline
        assert fident = try comp.identify().underline
        assert @derives(Zombie), "not a zombie anymore"
        message = "The %s damaged %s zombie, fixing it"
        warning = "Checking %s for validitity after %s"
        try logger.silly warning.grey, sident, fident
        process = try this::process is Zombie::process
        matches = try this::matches is Zombie::matches
        m = malformed = (not process) or (not matches)
        logger.silly message.red, fident, sident if m
        return unless malformed # nothing is damaged
        assert this::process = Zombie::process or 0
        assert this::matches = Zombie::matches or 0
