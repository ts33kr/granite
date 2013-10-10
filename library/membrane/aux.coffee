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
asciify = require "asciify"
connect = require "connect"
logger = require "winston"
assert = require "assert"
uuid = require "node-uuid"
colors = require "colors"
async = require "async"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"
url = require "url"

{Zombie} = require "../nucleus/zombie"
{Duplex} = require "../membrane/duplex"
{Preflight} = require "./preflight"

# This definition stands for the compound that provides support
# for auxiliary services. These services reside within the conext
# of the parent services, restricted to the context of their own.
# This compound handles the wiring of these services within the
# intestines of the parent service that includes this component.
module.exports.Auxiliaries = class Auxiliaries extends Preflight

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    @abstract yes

    # A hook that will be called once the Connect middleware writes
    # off the headers. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    headers: (request, response, resource, domain, next) ->
        assert auxiliaries = @constructor.aux() or {}
        mapper = (closure) -> _.map auxiliaries, closure
        hosting = try @constructor.identify().underline
        routines = mapper (value, key) -> (callback) ->
            assert _.isObject singleton = value.obtain()
            message = "Cascading headers from %s to %s @ %s"
            headers = singleton.upstreamAsync "headers", ->
                identity = value.identify().underline
                template = [hosting, identity, key]
                logger.debug message.grey, template...
                assert singleton is this; callback()
            headers request, response, resource, domain
        return async.series routines, next

    # This server side method is called on the context prior to the
    # context being compiled and flushed down to the client site. The
    # method is wired in an synchronous way for greater functionality.
    # This is the place where you would be importing the dependencies.
    prelude: (symbol, context, request, next) ->
        assert auxiliaries = @constructor.aux() or {}
        context.externals.push _.keys(auxiliaries)...
        mapper = (closure) -> _.map auxiliaries, closure
        routines = mapper (value, key) -> (callback) ->
            assert _.isObject singleton = value.obtain()
            assert _.isObject ecc = context.caching ?= {}
            assert _.isString qualified = "#{symbol}.#{key}"
            assembler = singleton.assembleContext.bind singleton
            baked = nsp: qualified, caching: context.caching
            assembler qualified, request, yes, baked, (assembled) ->
                assert context.scripts.push assembled.scripts...
                assert context.changes.push assembled.changes...
                assert context.sources.push assembled.sources...
                assert context.invokes.push assembled.invokes...
                context.styles.push assembled.styles...
                context.sheets.push assembled.sheets...
                return callback undefined
        return async.series routines, next

    # Include an auxiliary service definition in this service. The
    # definition should be an object whose keys correspond to the
    # installation symbol of an auxiliary service and whose values
    # are the actual auxiliary services. So that service `value` is
    # installed in the parent under under a name defined by `key`.
    @aux: (definition) ->
        return @$aux if arguments.length is 0
        noDefinition = "definition has to be object"
        assert _.isObject(definition), noDefinition
        assert @$aux = _.clone(@$aux or new Object)
        _.each definition, (value, key, collection) =>
            notAux = "not an auxiliary: #{value}"
            wrongValue = "got invalid value: #{value}"
            wrongKey = "invalid key supplied: #{key}"
            assert _.isObject(value), wrongValue
            assert not _.isEmpty(key), wrongKey
            assert value.inherits(Auxiliary), notAux
            return assert @$aux[key] = value

# An abstract base class for all the auxiliary service definitions.
# An auxiliary service base class is a chimera that extends from the
# `Zombie` service in addition to the end user service: one of those
# implementations. Be careful to consider that auxiliary services do
# inherit the zombie behavior with all the respectful consequences.
module.exports.Auxiliary = class Auxiliary extends Zombie

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    @abstract yes

    # These invocations establish the parameters which are going
    # to be used for matching HTTP requests against this service.
    # Typically an HTTP pathname pattern and a domain name pattern.
    # Try not to put constraints on the domain, unless necessary.
    # Also, the compounds for the composition system belong here.
    @location: -> "/#{@reference()}/#{@identify()}"

    # These invocations establish the parameters which are going
    # to be used for matching HTTP requests against this service.
    # Typically an HTTP pathname pattern and a domain name pattern.
    # Try not to put constraints on the domain, unless necessary.
    # Also, the compounds for the composition system belong here.
    @compose Preflight
