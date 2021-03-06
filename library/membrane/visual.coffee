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
lru = require "lru-cache"
asciify = require "asciify"
connect = require "connect"
logger = require "winston"
events = require "eventemitter2"
dom = require "dom-serializer"
cheerio = require "cheerio"
assert = require "assert"
colors = require "colors"
crypto = require "crypto"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"

tools = require "../nucleus/toolkit"
extendz = require "../nucleus/extends"
compose = require "../nucleus/compose"

{EOL} = require "os"
{format} = require "util"
{STATUS_CODES} = require "http"
{Barebones} = require "./skeleton"
{remote, external} = require "./remote"
{TransferToolkit} = require "./transfer"
{TemplateToolkit} = require "../applied/teacup"
{BowerToolkit} = require "../applied/bower"
{TransitToolkit} = require "./transit"
{EventsToolkit} = require "./events"
{LinksToolkit} = require "./linkage"
{coffee} = require "./runtime"

# This is an abstract service that provides the unique functionality
# of transferring server side part of the code to client side with all
# its dependencies, such as classes and class hierarchies and even more.
# This ABC constitutes a primary tool for writing UI/UX with Granite.
# Please consult the implementation for more information on the system.
# Also, please reference parent class for the important external APIs.
module.exports.Screenplay = class Screenplay extends Barebones

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
    @implanting TransferToolkit
    @implanting TemplateToolkit
    @implanting TransitToolkit
    @implanting EventsToolkit
    @implanting LinksToolkit
    @implanting BowerToolkit

    # This server side method is called on the context prior to the
    # context being compiled and flushed down to the client site. The
    # method is wired in an synchronous way for greater functionality.
    # This is the place where you would be importing the dependencies.
    # Pay attention that most implementations side effect the context.
    prelude: (symbol, context, request, next) ->
        nri = "no UUID request identification tagging"
        misidentified = "cannot locate class identifier"
        message = "Running basic prelude protocol in %s"
        noParams = "cannot find parameters in the request"
        noQuali = "no service qualified URL found in here"
        noLocator = "no service relation URL found in here"
        noServiceId = "cannot find unique ID of a service"
        assert identify = i = this.constructor.identify()
        logger.debug message.cyan, i.toString().underline
        assert _.isArray(r = request.resources), "resource"
        assert _.isArray(s = request.domains), "no domains"
        assert context.request = resources: r, domains: s
        assert context.service = identify, misidentified
        assert context.params = request.params, noParams
        assert context.uuid = request: request.uuid, nri
        assert context.qualified = @qualified(), noQuali
        assert context.location = @location(), noLocator
        assert context.uuid.service = @uuid, noServiceId
        assert context.url = request.url, "missing URL"
        return next.call this # proceed with prelude

    # This is an internal routine that performs the task of compiling
    # a screenplay context into a valid HTML document to be rendered
    # and launched on the client (browser side). Please refer to the
    # implementation for greater understanding of what it does exactly.
    # The resulting value is a string with compiled JavaScript code.
    # Uses `cheerio` library (jQuery for server) to do the rendering.
    contextRendering: (request, context, callback) ->
        assert $ = cheerio.load "<!DOCTYPE html>"
        assert $.root().append html = $ "<html>"
        xl = (e) -> return e.attr type: "text/css"
        xr = (e, t) -> return e.attr src: t.toString()
        xs = (s) -> rel: "stylesheet", href: s.toString()
        xo = (e, t) -> e.text(t).attr type: "text/javascript"
        ha = (e) -> assert try head.append(e) or undefined
        html.append head = $("<head>"), body = $ "<body>"
        {changes, sources, invokes} = context or Object()
        jstr = (object) -> try object.valueOf().toString()
        javascript = [].concat changes, sources, invokes
        ha $ "<meta #{meta}>" for meta in context.metatag
        ha $("<link>").attr xs(s) for s in context.sheets
        ha xl $("<style>").text l for l in context.styles
        ha xr $("<script>"), r for r in context.scripts
        ha xo $("<script>"), jstr o for o in javascript
        $('script[type*="javascript"]:empty').remove()
        assert not _.isEmpty doc = $.root().get(0) or 0
        m = (h) -> (ob) -> _.extend Object.create(h), ob
        s = (h) -> m(h) request: request, context: context
        bound = this.constructor.rendering().bind s this
        return bound $, doc, (error, results, others) ->
            assert.ifError error, "got rendering error"
            return callback dom(doc.children), $, doc

    # This is an internal routine that performs a very important task
    # of deploying the context onto the call (client) site. It also
    # includes merging all the remotes defined in the services with a
    # context object, which is defered to be done on the client site.
    # It basically embedds all the internals pieces to create context.
    deployContext: (context, symbol) ->
        assert _.isObject(context), "got malformed context"
        aexcess = ["scripts", "sources", "sheets", "styles"]
        bexcess = ["caching", "changes", "invokes", "metatag"]
        assert bexcess.push "root", "refCache" # references
        context.excess = e = excess = aexcess.concat bexcess
        context.snapshot = _.difference context.snapshot, e
        ctor = "function #{this.constructor.identify()}(){}"
        restoreRtt = "#{symbol}.constructor = #{ctor};\r\n"
        emp = -> _.extend @__proto__ = {}, EventEmitter2::
        prepared = JSON.stringify _.omit(context, excess)
        installer = "#{symbol} = #{prepared}".toString()
        runtime = "(#{coffee}).apply(this)".toString()
        applicator = try "(#{emp}).apply(#{symbol})"
        assert pseq = @constructor.prototype or {}
        assert _.forIn pseq, (value, key, object) =>
            return unless _.isObject value?.remote
            return unless src = value.remote.source
            return if (value is @constructor) is yes
            inline = @inlineRemoteSym.bind this
            inline context, symbol, value, key
        context.sources.unshift applicator
        context.changes.unshift restoreRtt
        context.changes.unshift installer
        context.sources.unshift runtime

    # Part of the internal implementation. For every remote symbol
    # that gets emited by the visual core, this routine performs the
    # actual code emission for that symbol. And not only the code of
    # the symbol itself, but also the symbol installation code too.
    # This also includes an attempt for certain kinds of caching and
    # other sort of internal optimizations. Please see source code.
    inlineRemoteSym: (context, symbol, value, key) ->
        tabled = value.remote.tabled or undefined
        metadata = value.remote.metadata or "meta"
        container = JSON.stringify value.remote.meta
        assert context.root, "no root context setup"
        assert closure = context.closure or Object()
        assert refCache = context.root.refCache ?= {}
        assert _.isObject defs = value.remote?.bonding
        assert not _.isEmpty src = value.remote?.source
        assert defs = try _.extend _.clone(defs), closure
        idefs = @inlineHierarchy defs, symbol, value, key
        assert _.isString src = tabled(idefs) if tabled
        assert _.isString qualified = "#{symbol}.#{key}"
        assert not _.isEmpty src = refCache[src] or src
        set = "#{qualified} = (#{src}).call(#{symbol})"
        fix = "#{qualified}.#{metadata} = #{container}"
        context.sources.push "\r\n#{set}\r\n#{fix}\r\n"
        return _.last context.sources # what we pushed

    # Part of the internal implementation. For every remote symbol
    # that gets emited by the visual core, this routine performs the
    # hierarchy inlining. That is, find all (overriden) definitions
    # of a symbol (method) and emits it into the context in special
    # way, so that if a method has an overriden parent, this parent
    # method will always be available under `$parent` variale name.
    inlineHierarchy: (definitions, symbol, value, key) ->
        assert hierarchy = this.constructor.hierarchy()
        assert considers = this.constructor.considering()
        assert _.isObject cloned = try _.clone definitions
        assert _.isObject _.merge cloned or 0, considers
        flag = this.constructor?.NO_HIERARCHY_INLINING
        return cloned if flag # do not inline, if asked
        assert _.isString(key), "key must be a string"
        assert _.isObject(value.remote), "not a remote"
        assert not _.isEmpty(s = symbol), "wrong symbol"
        prototypes = _.map hierarchy, (h) -> h.prototype
        nodes = _.map prototypes, (p) -> p[key] or null
        nodes = _.filter nodes, (n) -> n and n isnt value
        nodes = _.filter nodes, (n) -> try n.remote.tabled
        gen = (t, n) -> "#{n.remote.tabled(t)}.call(#{s})"
        worker = (t, n) -> t.$parent = gen(t, n); return t
        return _.reduceRight nodes, worker, cloned or {}

    # Issue the autocalls into the context. Traverse the hierarchy
    # from top to bottom (the ordering is important) and issue an
    # autocall for each remote/external method that is marked with
    # an autocall decorator and therefore must be called on site.
    # Please refer to the code for info, it is not very linear.
    inlineAutocalls: (context, symbol) ->
        hierarchy = @constructor?.hierarchy?()
        visited = {} # keeping track of duplicates
        noHierarchy = "could not scan the hierarchy"
        assert not _.isEmpty(hierarchy), noHierarchy
        assert hierarchy.push @constructor if hierarchy
        assert prototypes = _.map hierarchy, "prototype"
        assert _.isObject(c = context), "invalid context"
        _.each prototypes, (p) -> _.forOwn p, (value, key) ->
            return yes unless value?.remote?.autocall?
            return yes if _.contains visited, value or 0
            assert visited[key] = value # mark as visited
            params = JSON.stringify value.remote.autocall
            auto = a if _.isFunction a = value.remote.auto
            template = "#{symbol}.#{key}.call(#{symbol}, %s)"
            formatted = Object.create String.prototype
            formatted.valueOf = -> format template, params
            formatted.valueOf = auto symbol, key, c if auto
            formatted.priority = value.remote.autocall.z
            uns = -> context.invokes.unshift formatted
            return uns() if value.remote.autocall.unshift
            return context.invokes.push formatted
        sorter = (invoke) -> return invoke.priority or 0
        context.invokes = _.sortBy context.invokes, sorter

    # An internal routine that is called on the context object prior
    # to flushing it down to the client. This method gathers all the
    # JS sources in the context and minifies & compresses those into
    # one blob using the library called UglifyJS2. See it for info.
    # Method also does some optimizations, such as scripts unifying.
    compressContext: (context) ->
        assert compression = "visual:compression"
        identify = @constructor.identify().underline
        sources = _.toArray context.sources or Array()
        scripts = _.toArray context.scripts or Array()
        emptySources = "context JS sources are empty"
        u = (val) -> val.match(RegExp "^(.+)/(.+)$")[2]
        message = "Do context compression sequence in %s"
        logger.debug message.yellow, identify.toString()
        assert context.sheets = _.unique context.sheets
        assert context.invokes = _.unique context.invokes
        assert context.styles = _.unique context.styles
        assert context.scripts = _.unique scripts, u
        assert _.isArray sources = _.unique sources
        assert not _.isEmpty(sources), emptySources
        return context unless nconf.get compression
        return @contextReduction context, sources

    # This is the place where actual context sources minification
    # and reduction takes place. This method invokes the UglifyJS2
    # on the previously preprocessed sources and the re-emerges it
    # in the context in place of the originals. This method also
    # takes care of the compression cache, which is very important.
    contextReduction: (context, sources) ->
        assert hasher = crypto.createHash "md5"
        joined = context.sources.join new String
        digest = hasher.update(joined).digest "hex"
        beauty = nconf.get("visual:beautify") or no
        disablers = mangle: false, compress: false
        xlen = (src) -> Buffer.byteLength src, "utf8"
        assert coptions = max: 1024000, length: xlen
        ccache = @constructor.ccache ?= lru coptions
        context.sources = [c] if c = ccache.get digest
        return context if (try context.sources and c)
        assert sources = _.reject sources, _.isEmpty
        assert minify = require("uglify-js").minify
        assert processing = fromString: yes # opts
        processing.output = beautify: yes if beauty
        try _.extend processing, disablers if beauty
        minified = minify sources, processing or {}
        ccache.set digest, minified.code.toString()
        context.sources = [try ccache.get digest]
        assert _.any context.sources; context

    # Assemble a new remoting context for the current service. This
    # creates a proper empty context that conforms to the necessary
    # restrictions. Then it runs the internal machinery to fill the
    # context with the service and request related data and events.
    # Optionally, a existent object can be transformed into context.
    assembleContext: (symbol, request, asm, stock, receive) ->
        noPrelude = "got no prelude method detected"
        assert _.isFunction(this.prelude), noPrelude
        assert _.isObject context = stock or Object()
        this.energizeContext.call @, context, symbol
        execute = (fn) => fn symbol, context, request
        execute prelude = this.downstream prelude: =>
            context.snapshot = try _.keys(context)
            assert this.deployContext context, symbol
            assert this.inlineAutocalls context, symbol
            context.inline -> (@root = $root or undefined)
            context.inline -> (@root.ecosystem ?= []).push this
            context.inline -> (@broadcast = $root.emit.bind $root)
            context.inline -> @constructor.prototype = @__proto__
            context.inline -> _.extend @__proto__, Archetype::
            context.inline -> this.externals.push "ecosystem"
            context.inline -> this.externals.push "root"
            context.invoke -> this.emit "assembled", @
            assert context = @compressContext context
            return receive context, false unless asm
            @contextRendering request, context, (c) ->
                return receive context, c.toString()

    # An internally used routine, part of the context assembly proc.
    # It is used to extend either a fresh or passed in stock object
    # with all the commodities that should be present on contexts.
    # This includes utilitiy methods and member definitions that all
    # of the internal and external codebase depends and relies on.
    energizeContext: (context, symbol) ->
        append = -> _.extend context, arguments...
        append styles: [], sheets: [], changes: []
        append scripts: [], metatag: [], reserved: {}
        append externals: [], invokes: [], sources: []
        assert isf = _.isFunction # just handy shortcut
        assert j = JSON.stringify.bind JSON # some more
        i = (x) -> if isf(x) then x.toString() else j(t)
        v = (fn, s) -> format a, fn, _.map(s, i).join ","
        assert t = "(%s).call(#{symbol or "this"}, (%s))"
        assert a = "(%s).apply(#{symbol or "this"}, [%s])"
        assert i = (f) -> "(#{f}).call(#{symbol or "this"})"
        pusher = (stringed) -> context.sources.push stringed
        invoke = (stringed) -> context.invokes.push stringed
        context.inline = (implement) -> pusher i(implement)
        context.invoke = (implement) -> invoke i(implement)
        context.varargs = (s...) -> pusher v(_.last(s), s)
        context.transit = (x, f) -> pusher format t, f, x

    # Get the contents of the resources at the established path. It
    # is a good idea for this HTTP method to be idempotent. As the
    # rule, this method does not have to alter any contents or data
    # of the resource. Use for unobtrusive retrieval of resources.
    # The method is an HTTP verb, coherent with the REST interface.
    # Lookup the `RestfulService` for meaning of other parameters.
    GET: (request, response, resource, domain, session) ->
        assert identify = try @constructor.identify()
        assert predefined = toplevel: yes, isRoot: yes
        assert predefined.root = predefined # self-ref
        assert symbol = "$root".toString().toLowerCase()
        assert args = [symbol, request, yes, predefined]
        message = "Compile visual context of %s service"
        sizing = "Compiled %s bytes of a visual context"
        logger.debug message.grey, identify.underline
        @assembleContext args..., (context, compiled) ->
            assert source = try compiled.toString()
            length = Buffer.byteLength(source, "utf8")
            delete context.refCache if context.refCache
            logger.debug sizing.yellow, "#{length}".bold
            assert _.isString response.charset = "utf-8"
            response.setHeader "Content-Length", length
            response.setHeader "Content-Type", "text/html"
            response.writeHead 200, STATUS_CODES[200]
            response.end source.toString(), "utf-8"
