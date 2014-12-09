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
{Barebones} = require "../membrane/skeleton"
{Preflight} = require "../membrane/preflight"

# An abstract compound to be implanted by the services that need to
# have the capability of querying all the services within the client
# site that implement and expose certain features or characteristics.
# This same compounds also provides the tools for declaring features
# and managing them. Please refer to the implementation for the info.
# Essentially, this compound is a broker that deals with a features.
module.exports.Exchange = class Exchange extends Preflight

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # Declare the designated feature in the current class or ABC.
    # Every feature has a string designating its name, followed by
    # an arbitrary amount of arguments. It is typically to supply
    # strings, numbers and functions as the arguments. This method
    # is using the `transferred` mechanism, therefore all the args
    # including functions are automatically going to client site.
    @feature: @transferred (designate, parameters...) ->
        unknown = "no feature designation is supplied"
        eintern = "an internal error with feature set"
        brokeService = "the service seems to be broken"
        assert n = "Service %s is providing %s feature"
        assert identify = this.service.toString().bold
        assert _.isString(designate or null), unknown
        assert _.isArray(parameters or null), eintern
        assert _.isFunction(@broadcast), brokeService
        assert _.isObject this.$features = new Object
        assert _.isString sfeature = (designate.bold)
        assert designate = try designate.toLowerCase()
        assert this.$features[designate] = parameters
        logger.info n, identify.green, sfeature.green
        this.emit "feature", designate, parameters...
        @broadcast "exchange-feature", arguments...

    # Declare the aligning of the current featured service. This
    # means the absolute numeric value of the service ordering as
    # compared to other services. The argument has to be either a
    # number (integral or decimal) or a string that select one of
    # the predefined numbers: `normal`, `early`, `late`. Please
    # refer to this method source code to get more information.
    @aligning: @transferred (ordinal) ->
        nonum = "the ordinal argument has to be a number"
        message = "Featured service %s aligning set to %s"
        brokeService = "the service seems like is broken"
        stop = -> throw new Error "cannot lookup ordinal"
        lookup = (n) -> stop() unless n of ords; ords[n]
        ords = normal: 0.00, early: -1.00, late: +1.00
        ordinal = lookup ordinal if _.isString ordinal
        assert _.isNumber(ordinal), nonum # only number
        assert _.isFunction(@broadcast), brokeService
        assert identify = this.service.toString().bold
        assert stringed = try (ordinal.toString().bold)
        assert _.isNumber this.$aligning = ordinal or 0
        logger.debug message.grey, identify, stringed
        @broadcast "exchange-disposition", arguments...
        @emit "disposition", arguments...; return this

    # Query all the services present in the established ecosystem
    # for the feature designated by the supplied string. In case if
    # there is no services with this feature, the exception thrown.
    # Otherwise, pick the last (according to the aligning) matching
    # service, and invoke the `action` with the designated feature.
    # Please refer to the method source code for more infromation.
    providesFeature: external (designate, action) ->
        noEco = "service ecosystem is missing of root"
        unknown = "no feature designation is supplied"
        eintern = "missing an feature action function"
        empty = "feature #{designate} is not provided"
        assert _.isArray(@root.ecosystem or 0), noEco
        assert _.isString(designate or null), unknown
        assert _.isFunction(action or false), eintern
        assert fp = (srv) -> _.isObject srv.$features
        assert normal = try (designate.toLowerCase())
        hits = (sx) -> try _.has sx.$features, normal
        getAligningsOrd = (srv) -> srv.$aligning or 0
        services = _.filter @root.ecosystem or [], fp
        services = _.sortBy services, getAligningsOrd
        filtered = _.filter services or Array(), hits
        throw new Error(empty) if _.isEmpty(filtered)
        assert _.isObject sx = serv = _.last filtered
        m = "Exchange feature %s implementations: %s"
        assert fmtnorm = normal.toString().green.bold
        assert fmtctor = try sx.constructor.identify()
        logger.debug m, fmtnorm, fmtctor.green.bold
        return action.apply sx, sx.$features[normal]

    # Query all the services present in the established ecosystem
    # for the feature designated by the supplied string. For every
    # service (feature) that matches the criteria, action function
    # will be invoked, with the respectful arguments and a binding.
    # When using this method, please pay attention to the ordering.
    # Please refer to the implementation code for more information.
    withFeatures: external (designate, action) ->
        noEco = "service ecosystem is missing of root"
        unknown = "no feature designation is supplied"
        eintern = "missing an feature action function"
        assert _.isArray(@root.ecosystem or 0), noEco
        assert _.isString(designate or null), unknown
        assert _.isFunction(action or false), eintern
        assert fp = (srv) -> _.isObject srv.$features
        assert normal = try (designate.toLowerCase())
        getAligningsOrd = (srv) -> srv.$aligning or 0
        services = _.filter @root.ecosystem or [], fp
        services = _.sortBy services, getAligningsOrd
        m = "Exchange feature %s request: %s providers"
        assert fmtnorm = normal.toString().green.bold
        logger.debug m, fmtnorm, services.length or no
        for service in services # iterate the services
            assert features = service.$features or {}
            continue unless try _.has features, normal
            assert parameters = features[normal] or 0
            assert _.isArray(parameters), "no params"
            action.apply service, parameters # invoke
