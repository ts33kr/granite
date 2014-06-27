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

{Pinpoint} = require "../exposure/pinpoint"
{Localized} = require "../exposure/localized"
{Bilateral} = require "../membrane/bilateral"
{Auxiliaries} = require "../membrane/auxes"
{Embedded} = require "../membrane/embed"

# This abstract compound is designed to be the starting point in a
# clearly disambigued tree of inheritance for the application and
# the framework services. This particular abstraction is marking
# an auxiliary (embedded) service. It also implants a set of usual
# suspects, that generally should be included in any service that
# is actually implementing something useful, not just a stub one.
assert module.exports.Behavior = class Behavior extends Embedded

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
    @implanting Auxiliaries, Bilateral, Localized, Pinpoint

    # This method is part of an internal integrity assurance toolkit.
    # Once the behavior-enabled service emits a signal that indicate
    # service has been successfuly booted, this implementation takes
    # on performing a series of tests to ensure that current service
    # has been propertly installed, bootloaded and then initialized.
    powerOnSelfTest: @awaiting "installed", ->
        return if this.skip_post_testing or undefined
        noEco = "ecosystem hosted by the root missing"
        noArch = "tools provided by archetype missing"
        noRoots = "the root service cannot be located"
        notSys = "service is not present in ecosystem"
        noService = "service identification is missing"
        noIdentic = "missing constructor identity tags"
        namesIncons = "inconsistent service identities"
        m = "Power-on self-testing OK at the %s".magenta
        identity = @constructor?.identify?().toString()
        assert _.isFunction(this.tap or false), noArch
        assert _.isObject(@root or undefined), noRoots
        assert _.isObject(@root.ecosystem or 0), noEco
        assert _.isString(@service or null), noService
        assert _.isString(identity or null), noIdentic
        assert this in (@root.ecosystem or []), notSys
        assert (try identity is @service), namesIncons
        logger.debug m, identity.underline.magenta
