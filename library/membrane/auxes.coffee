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
dom = require "dom-serializer"
asciify = require "asciify"
connect = require "connect"
uuid = require "node-uuid"
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
{Service} = require "../nucleus/service"
{Preflight} = require "./preflight"
{Screenplay} = require "./visual"

# This definition stands for the compound that provides support
# for auxiliary services. These services reside within the conext
# of the parent services, restricted to the context of their own.
# This compound handles the wiring of these services within the
# intestines of the parent service that includes this component.
# Also provides dynamic auxes functionality known as parasites.
module.exports.Auxiliaries = class Auxiliaries extends Preflight

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # These are the shorthand definitions to use when defining new
    # parasites. These exist only for convenience. Consider using
    # these definitions when you need a typical parasites, such as
    # the one that parsites on all standalone (non zombie) services
    # or the one that parasites on all services, including zombies.
    @PEXPERIMENT: (h, r, d) -> d h.kernel.env is "development"
    @PSTANDALONE: (h, r, d) -> d not try h.objectOf Zombie
    @PEVERYWHERE: (h, r, decide) -> return decide true

    # Register current service that invokes the method as parasite.
    # This means that the service will be automatically included to
    # every services as an auxilliary, if it satisfies the condition.
    # The argument has to be a key/value signature, where the key is
    # the variable name that will be used for the aux service and the
    # value is a function that evaluates inclusions conditions every
    # time when any auxilliary-powered services is being executed.
    @parasite: (signature) ->
        assert uid = try _.uniqueId "parasite_"
        vector = Auxiliaries.$parasites ?= Array()
        return vector unless arguments.length >= 1
        identity = try this?.identify?().toString?()
        abused = "an argument has to be a key/value"
        incorrect = "got incorrect decision function"
        assert arguments.length < 2, "usage mistake"
        a = try _.first(arguments).derives(Service)
        (fishing = {})[uid] = _.head arguments if a
        signature = fishing if (fishing or 0) and a
        assert _.isObject(signature or null), abused
        assert token = try _.first _.keys(signature)
        assert decides = _.first _.values(signature)
        fv = (sequence) -> _.first _.values sequence
        ic = (h, r, yn) -> yn h.objectOf fv signature
        decides = ic if (try decides.derives Service)
        assert _.isFunction(decides or 0), incorrect
        notZombie = "not a zombie child: #{identity}"
        notScreen = "has no visual core: #{identity}"
        assert this.derives(Screenplay), notScreen
        assert this.derives(Zombie), notZombie
        return vector.push # append parasite
            token: token.toString()
            target: this or null
            uid: uid.toString()
            decides: decides

    # This is an internal routine that performs the task of compiling
    # a screenplay context into a valid HTML document to be rendered
    # and launched on the client (browser side). Please refer to the
    # implementation for greater understanding of what it does exactly.
    # The resulting value is a string with compiled JavaScript code.
    # Uses `cheerio` library (jQuery for server) to do the rendering.
    # This is overriden version, please see `Screenplay` for original
    contextRendering: (request, context, callback) ->
        {series, apply} = async or require "async"
        assert auxiliaries = @constructor.aux() or {}
        i = "Invoking %s auxilliary renderers inside %s"
        m = (h) -> (ob) -> _.extend Object.create(h), ob
        s = (h) -> m(h) request: request, context: context
        assert identify = @constructor.identify().underline
        assert $parent = Screenplay::contextRendering or null
        rendv = (ax, n) -> if _.isArray rs = ax.renderers then rs else []
        endsq = (rs, n) -> (as) -> conct as, (e, ss) -> n 0, rs.concat ss
        scans = (ax, n) -> n (f.bind s ax.obtain() for f in rendv ax, n)
        reviu = (ax, n) -> ax.obtain().reviewParasites 0, request, n
        conct = (as, n) -> async.concat _.values(as) or [], fetch, n
        fetch = (ax, n) -> scans ax, (rs) -> reviu ax, endsq(rs, n)
        $parent.call @, request, context, (compiled, $, doc) =>
            this.reviewParasites auxiliaries, request, (poly) =>
                async.map _.values(poly), fetch, (e, renderers) =>
                    assert.ifError e, "error when getting renderers"
                    renderers = _.unique _.flatten renderers or []
                    mapped = (apply fn, $, doc for fn in renderers)
                    logger.debug i, "#{mapped.length}".bold, identify
                    return series mapped or [], (error, results) ->
                        assert.ifError error, "got rendering error"
                        return callback dom(doc.children), $, doc

    # A part of the internal implementation of the auxilliaries. It
    # takes care of revewing and connecting the parasiting peers, by
    # polling the registered parasites and seeing if conditions fit.
    # Please see the implementation for understanding the detailing
    # on how the parasiting functionality is implemented and works.
    reviewParasites: (seeds, request, callback) ->
        assert parasites = try Auxiliaries.parasite()
        assert seeds = seeds or @constructor.aux() or []
        selfomit = (par) => par.target is @constructor
        assert parasites = _.reject parasites, selfomit
        assert _.isObject polygone = _.clone seeds or {}
        assert _.isFunction(callback), "got no callback"
        obt = (xi) -> xi.target.obtain() or throw Error()
        ink = (xi) -> -> xi.decides.apply obt(xi), arguments
        ask = (xi, func) => ink(xi)(this, request, func)
        log = (xi) => logger.debug inf, idc(xi), hosting
        idc = (xi) => try xi.target.identify().underline
        inf = "Parasiting %s service into %s hosting".blue
        hosting = try @constructor.identify().underline
        async.filter parasites or [], ask, (results) =>
            _.each results or new Object(), log # notify
            assert tokens = _.map results, (r) -> r.token
            assert targets = _.map results, (r) -> r.target
            assert polished = try _.object(tokens, targets)
            assert merged = try _.merge polygone, polished
            return callback polygone or new Object()

    # A hook that will be called once the Connect middleware writes
    # off the headers. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    headers: (request, response, resource, domain, next) ->
        assert auxiliaries = @constructor.aux() or {}
        @reviewParasites auxiliaries, request, (poly) =>
            assert auxiliaries = poly # replace the vector
            hosting = try @constructor.identify().underline
            mapper = (closure) -> _.map auxiliaries, closure
            routines = mapper (value, key) -> (callback) ->
                assert _.isObject singleton = value.obtain()
                message = "Cascading headers from %s to %s @ %s"
                headers = singleton.downstream headers: ->
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
    # Pay attention that most implementations side effect the context.
    prelude: (symbol, context, request, next) ->
        assert message = "Infusing %s into %s as %s"
        assert auxiliaries = @constructor.aux() or {}
        assert idc = @constructor.identify().underline
        @reviewParasites auxiliaries, request, (poly) =>
            assert auxiliaries = poly # replace the vector
            context.externals.push _.keys(auxiliaries)...
            context.auxiliaries = _.keys(poly) or new Array
            exec = (routines) -> async.series routines, next
            mapper = (closure) -> _.map auxiliaries, closure
            return exec mapper (value, key) => (callback) =>
                assert _.isObject singleton = value.obtain()
                assert _.isObject ecc = context.caching ?= {}
                assert _.isString qualified = "#{symbol}.#{key}"
                stock = nsp: qualified, caching: context.caching
                stock.closure = $host: symbol # set host reference
                assert idv = value.identify().toString().underline
                logger.debug message.blue, idv, idc, qualified.bold
                assembler = singleton.assembleContext.bind singleton
                assembler qualified, request, no, stock, (assembled) =>
                    @mergeContexts key, context, assembled, callback

    # A complementary part of the auxiliaries substem implementation.
    # This routine is invoked once a compiled context is obtained of
    # an auxiliary service. It is up to this routine to figure out how
    # to merge those contexts together. Please refer to the `prelude`
    # implementation for more information on the internals of process.
    mergeContexts: (key, context, assembled, callback) ->
        notify = "Merging the context of %s into service %s"
        s = "scripts=%s, changes=%s, sources=%s, invoked=%s"
        m = "Appended #{s}" # the human-readable statistics
        scripts = context.scripts.push assembled.scripts...
        changes = context.changes.push assembled.changes...
        sources = context.sources.push assembled.sources...
        invoked = context.invokes.push assembled.invokes...
        identity = try this.constructor.identify().underline
        locate = (value) -> "aux=#{value or undefined}".bold
        logger.debug notify, locate(key), identity.toString()
        logger.debug m, scripts, changes, sources, invoked
        styles = context.styles.push assembled.styles...
        sheets = context.sheets.push assembled.sheets...
        callback undefined; return context

    # Include an auxiliary service definition in this service. The
    # definition should be an object whose keys correspond to the
    # installation symbol of an auxiliary service and whose values
    # are the actual auxiliary services. So that service `value` is
    # installed in the parent under under a name defined by `key`.
    this.aux = this.auxilliary = (definition) ->
        return this.$aux if arguments.length is 0
        isClass = _.isObject try definition.__super__
        anon = isClass and definition.derives Screenplay
        symbol = -> _.uniqueId("auxilliary_").toString()
        assert xdefinition = _.clone definition, "uncloned"
        (definition = {})[symbol()] = xdefinition if anon
        noDefinition = "argv definition has to be object"
        assert _.isObject(definition or 0), noDefinition
        assert @$aux = try _.clone(@$aux or new Object())
        _.each definition, (value, key, collection) =>
            notZombie = "not a zombie child: #{value}"
            notScreen = "has no visual core: #{value}"
            wrongValue = "got invalid value: #{value}"
            assert _.isObject(value), wrongValue
            isScreen = value.derives(Screenplay)
            isZombie = value.derives(Zombie)
            assert isScreen is yes, notScreen
            assert isZombie is yes, notZombie
            return assert @$aux[key] = value
