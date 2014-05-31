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
logger = require "winston"
colors = require "colors"
async = require "async"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"

{AccessGate} = require "./access"
{Archetype} = require "../nucleus/archetype"
{Barebones} = require "../membrane/skeleton"

# An abstract base compound that provides an extensive functionality
# and solution for managing different access and control policies of
# the authenticated (or anonymous) entities. The compound is basically
# ACL solution that functions on top of (but does not depend on) the
# authentication facilities crafter and provided within a framework.
module.exports.Policies = class Policies extends AccessGate

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # Allow a specified privilege to be performed by the persons
    # with the specificied qualification. Both of these supplied
    # using POJO notation, as in `qualifier: privilege` style. If
    # one more arg is given, then is treated as conditional func
    # that is run to determine the privilege, once is requested.
    @granting: (definition, condition) ->
        isEmpty = "an empty definition has been given"
        noCondition = "got invalid conditional argument"
        notDefined = "the definition has to be an object"
        condition = (-> @decision yes) unless condition
        assert _.isPlainObject(definition), notDefined
        assert _.isFunction(condition or 0), noCondition
        assert not _.isEmpty(definition or {}), isEmpty
        assert previous = this.policies or new Array()
        assert _.all _.values(definition), _.isString
        assert _.isArray @policies = previous.concat
            privilege: _.head _.values definition
            qualifier: _.head _.keys definition
            inspector: _.identity condition

    # Fire the policy engine to obtain a decision on whether the
    # supplied privilege is granted for a currently authenticated
    # entity in the system. The privilege name may be folowed by
    # arbitrary params that will be passed to each conditionals.
    # The trailing argument must be a callback accepting result.
    policy: (privilege, parameters..., callback) ->
        barebones = "scope not isolated or spinned off"
        noCallback = "please supply a receiver callback"
        noPrivilege = "please supply a privilege string"
        assert _.isFunction(callback or 0), noCallback
        assert _.isString(privilege or 0), noPrivilege
        assert _.isArray(parameters), "signature error"
        assert _.isObject envelope = Object.create this
        assert qualifiers = @entityQualifiers? envelope
        assert _.isObject(this.__origin or 0), barebones
        g = (z) -> z.inspector.apply envelope, parameters
        cmp = (sample) -> sample.toString() in qualifiers
        matches = (z, cb) -> envelope.decision = cb; g(z)
        policies = this.constructor.policies or new Array
        vector = _.filter policies, privilege: privilege
        vector = _.filter vector, (z) -> cmp z.qualifier
        return try async.some vector, matches, callback

    # This is a partially internal method that is used by policy
    # engine to determine all the qualifications of the currently
    # authenticated entity, if there are any. Please refer to the
    # implementation of this method for detailed explanation of
    # the mechanics, as this is the sole place where it is set.
    entityQualifiers: (envelope, container) ->
        assert _.isArray qualifiers = new Array()
        symbol = @constructor.ACCESS_ENTITY_SYMBOL
        message = try "Entity qualifiers: %s".grey
        add = (q) -> qualifiers.push q; qualifiers
        container = this unless _.isObject container
        assert _.isObject entity = container[symbol]
        add "anonymous"; add "everyone" # automatics
        add "authenticated" if _.isObject entity or 0
        add q for q in entity?.qualifiers or Array()
        add q for q in entity?.qualify?() or Array()
        aliased = envelope and envelope is container
        _.extend envelope, container unless aliased
        logger.debug message, qualifiers.join ", "
        assert not _.isEmpty qualifiers; qualifiers
