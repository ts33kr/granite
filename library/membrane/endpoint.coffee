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
logger = require "winston"
crossroads = require "crossroads"
uuid = require "node-uuid"
assert = require "assert"
colors = require "colors"
crypto = require "crypto"
nconf = require "nconf"
async = require "async"
https = require "https"
http = require "http"
util = require "util"
url = require "url"

{EOL} = require "os"
{format} = require "util"
{STATUS_CODES} = require "http"
{Barebones} = require "./skeleton"
{remote, external} = require "./remote"

# This is an internal component that is a part of the new API engine
# implementation. It holds a supplementary toolkit that is intended
# for defining pieces that go along with the API endpoint definition.
# These pieces are documentation of arbitrary kind, as well as param
# declarations and their respective rules, et cetera. Please refer to
# the implementation of this toolkit as well as to the implementation
# of its direct implementation `ApiService` for more information bits.
module.exports.EndpointToolkit = class EndpointToolkit extends Barebones

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # Class directive that sets the specified documentations in
    # the documentation sequence that will be used & emptied when
    # a API method is defined below. That is, this method operates
    # in a sequential mode. The documentation data is supplied to
    # this method as an object argument with arbitrary key/value
    # pairs, where keys are doc name and value is the doc itself.
    # Multiple docs with the same key name may exist just fine.
    this.defineDocument = this.docs = (xsignature) ->
        assert {ApiService} = try require "./api"
        noSignature = "please, supply a plain object"
        noDocuments = "cannot find the documents seq"
        internal = "an anomaly found in doc sequence"
        malfuncs = "derived from the incorrect source"
        message = "Setting an API documentation in %s"
        @documents ?= new Array() # document sequence
        assert previous = this.documents or new Array
        assert _.all(previous, _.isObject), internal
        return previous unless arguments.length > 0
        signature = _.find arguments, _.isPlainObject
        assert _.isPlainObject(signature), noSignature
        assert _.isArray(this.documents), noDocuments
        assert (try @derives(ApiService)), malfuncs
        assert identify = this.identify().underline
        logger.silly message.yellow, identify.bold
        fn = (arbitraryVector) -> return signature
        fn @documents = previous.concat signature

    # Class directive that sets the specified Crossroads rule in
    # a Crossroads rules sequence that will be used & emptied when
    # a API method is defined below. That is, this method operates
    # in a sequential mode. The Crossroads rule gets supplied to
    # this method as an object argument with arbitrary key/value
    # pairs, where keys are rule name and value is a rule itself.
    # Rules are attached to the route defined right after rules.
    this.crossroadsRule = this.rule = (xsignature) ->
        assert {ApiService} = try require "./api"
        noSignature = "please, supply a plain object"
        noCrossRules = "cannot find a cross-rules seq"
        internal = "an anomaly found in rule sequence"
        malfuncs = "derived from the incorrect source"
        message = "Setting the Crossroads rule in %s"
        @crossRules ?= new Array() # cross-rules seqs
        assert previous = this.crossRules or Array()
        assert _.all(previous, _.isObject), internal
        return previous unless arguments.length > 0
        signature = _.find arguments, _.isPlainObject
        assert _.isPlainObject(signature), noSignature
        assert _.isArray(this.crossRules), noCrossRules
        assert (try @derives(ApiService)), malfuncs
        assert identify = this.identify().underline
        logger.silly message.yellow, identify.bold
        fn = (arbitraryVector) -> return signature
        fn @crossRules = previous.concat signature

    # Class directive that sets the specified parameter summary in
    # the parameters/arg sequence that will be used & emptied when
    # a API method is defined below. That is, this method operates
    # in a sequential mode. The parameter summary gets supplied to
    # this method as an object argument with arbitrary key/value
    # pairs, where keys are arg names and values are the synopsis.
    # Params are attached to the route defined right after docs.
    this.defineParameter = this.argv = (xsignature) ->
        assert {ApiService} = try require "./api"
        noSignature = "please, supply a plain object"
        noParamStore = "cannot find a param-store seq"
        internal = "an anomaly found in argv sequence"
        malfuncs = "derived from the incorrect source"
        message = "Setting the parameter value in %s"
        @paramStore ?= new Array() # cross-rules seqs
        assert previous = this.paramStore or Array()
        assert _.all(previous, _.isObject), internal
        return previous unless arguments.length > 0
        signature = _.find arguments, _.isPlainObject
        assert _.isPlainObject(signature), noSignature
        assert _.isArray(this.paramStore), noParamStore
        assert (try @derives(ApiService)), malfuncs
        assert identify = this.identify().underline
        logger.silly message.yellow, identify.bold
        fn = (arbitraryVector) -> return signature
        fn @paramStore = previous.concat signature
