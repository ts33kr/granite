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
        services = _.filter @root.ecosystem or [], fp
        for service in services # iterate the services
            assert features = service.$features or {}
            continue unless _.has features, designate
            assert parameters = features[normal] or 0
            assert _.isArray(parameters), "no params"
            action.apply service, parameters # invoke

    # Declare the designated feature in the current class or ABC.
    # Every feature has a string designating its name, followed by
    # an arbitrary amount of arguments. It is typically to supply
    # strings, numbers and functions as the arguments. This method
    # is using the `transferred` mechanism, therefore all the args
    # including functions are automatically going to client site.
    @feature: @transferred (designate, parameters...) ->
        unknown = "no feature designation is supplied"
        eintern = "an internal error with feature set"
        brokeService = "the service seems to be broke"
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
        @broadcast "exchange-feature-x", arguments...
