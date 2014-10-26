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

{Pinpoint} = require "../gearbox/pinpoint"
{Exchange} = require "../gearbox/exchange"
{Policies} = require "../gearbox/policies"
{GrandCentral} = require "../gearbox/central"
{Localized} = require "../fringes/localized"
{Bilateral} = require "../membrane/bilateral"
{Auxiliaries} = require "../membrane/auxes"
{Preflight} = require "../membrane/preflight"

# This abstract compound is designed to be the starting point in a
# clearly disambigued tree of inheritance for the application and
# the framework services. This particular abstraction is marking
# an application, which is one of entrypoints within the concept
# of `Single Page Applications`. This component encompases all
# of the functionality need for providing a good `root` service.
module.exports.Application = class Application extends Preflight

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
    # P.S. These are the core definitions for every active component.
    @implanting Auxiliaries, Bilateral, Policies

    # These declarations below are implantations of the abstracted
    # components by the means of the dynamic recomposition system.
    # Please take a look at the `Composition` class implementation
    # for all sorts of information on the composition system itself.
    # Each of these will be dynamicall integrated in class hierarchy.
    # P.S. These are the secondary essentials for every active comp.
    @implanting Localized, Pinpoint, Exchange, GrandCentral

    # This method is synchronized over the `attached` event of the
    # kernel that gets fired once some component has been booted.
    # Method monitors all the attachment events, and every time it
    # checks if all the components has been booted. Once it so, it
    # broadcasts `completed` event to the kernel. The event will be
    # repeated after connection restoring, however a special event
    # `completed-once` is guaranteed to be fired one time only.
    waitCompletion: @synchronize "attached", (service) ->
        broken = "could not find essential functions"
        signature = "got an incorrect event signature"
        ecosystem = "can not detect current ecosystem"
        m = "Booting sequence has been completed at %s"
        assert _.isObject(service or null), signature
        assert _.isArray(@ecosystem or no), ecosystem
        assert _.isFunction(@broadcast or no), broken
        isDup = (service) -> _.isString service.duplex
        isCom = (service) -> try service.setInOrder?()
        duplexed = _.filter @ecosystem or [], isDup
        completed = _.every @ecosystem or [], isCom
        return unless completed # boot not finished
        @broadcast "completed" # notify of completed
        @broadcast "completed-once" unless @$complete
        assert identify = this.constructor.identify()
        logger.debug m.green, identify.green.bold
        this.$complete = yes # was completed once
