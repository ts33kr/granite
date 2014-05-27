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
events = require "eventemitter2"
assert = require "assert"
colors = require "colors"
crypto = require "crypto"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"

tools = require "./../nucleus/tools"
extendz = require "./../nucleus/extends"
compose = require "./../nucleus/compose"

{EOL} = require "os"
{format} = require "util"
{STATUS_CODES} = require "http"
{Barebones} = require "./skeleton"
{remote, external} = require "./remote"
{VisualBillet} = require "./billets"
{coffee} = require "./runtime"

# This is an abstract service that provides the unique functionality
# of rendering the server side store code on the client side with all
# its dependencies, such as classes and class hierarchies and even more.
# This ABC constitutes a primary tool for writing UI/UX with Granite.
# Please consult the implementation for more information on the system.
# Also, please reference parent class for the important external APIs.
module.exports.Screenplay = class Screenplay extends VisualBillet

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # This is an internal routine that performs the task of compiling
    # a screenplay context into a valid HTML document to be rendered
    # and launched on the client (browser side). Please refer to the
    # implementation for greater understanding of what it does exactly.
    # The resulting value is a string with compiled JavaScript code.
    compileContext: (context) ->
        meta = (content) -> "\r\n<meta #{content.toString()}>"
        script = (s) -> "\r\n<script src=\x22#{s}\x22></script>"
        style = (s) -> "\r\n<style type=\x22#{x}\x22>#{s}</style>"
        source = (s) -> "\r\n<script type=\x22#{j}\x22>#{s}</script>"
        sheet = (s) -> "\r\n<link rel=\x22#{c}\x22 href=\x22#{s}\x22>"
        template = "%s<html><head>%s</head><body></body></html>"
        [x, c, j] = ["text/css", "stylesheet", "text/javascript"]
        scripts = _.map(context.scripts, script).join String()
        changes = _.map(context.changes, source).join String()
        sources = _.map(context.sources, source).join String()
        invokes = _.map(context.invokes, source).join String()
        metatag = _.map(context.metatag, meta).join String()
        sheets = _.map(context.sheets, sheet).join String()
        styles = _.map(context.styles, style).join String()
        assert _.isString joined = metatag + sheets + styles
        assert _.isString joined += scripts + changes + sources
        format template, context.doctype, joined + invokes

    # This is an internal routine that performs a very important task
    # of deploying the context onto the call (client) site. It also
    # includes merging all the remotes defined in the services with a
    # context object, which is defered to be done on the client site.
    # It basically embedds all the internals pieces to create context.
    deployContext: (context, symbol) ->
        assert _.isObject(context), "malformed context"
        aexcess = ["scripts", "sources", "sheets", "styles"]
        bexcess = ["caching", "changes", "invokes", "metatag"]
        assert not _.isEmpty excess = aexcess.concat bexcess
        prepared = JSON.stringify _.omit(context, excess)
        installer = "#{symbol} = #{prepared}".toString()
        runtime = "(#{coffee}).apply(this)".toString()
        emp = -> _.extend @, EventEmitter2.prototype
        applicator = try "(#{emp}).apply(#{symbol})"
        assert _.forIn this, (value, key, object) =>
            return unless _.isObject value?.remote
            return unless src = value.remote.source
            return if (value is @constructor) is yes
            blob = JSON.stringify value.remote.meta
            metadata = value.remote.metadata or "meta"
            set = "#{symbol}.#{key} = (#{src}).call()\r\n"
            set += "#{symbol}.#{key}.#{metadata} = #{blob}"
            assert context.sources.push "\r\n#{set}\r\n"
        context.sources.unshift applicator
        context.changes.unshift installer
        context.sources.unshift runtime

    # Issue the autocalls into the context. Traverse the hierarchy
    # from top to bottom (the ordering is important) and issue an
    # autocall for each remote/external method that is marked with
    # an autocall decorator and therefore must be called on site.
    # Please refer to the code for info, it is not very linear.
    inlineAutocalls: (context, symbol) ->
        hierarchy = @constructor?.hierarchy?()
        noHierarchy = "could not scan the hierarchy"
        assert not _.isEmpty(hierarchy), noHierarchy
        assert hierarchy.push @constructor if hierarchy
        assert prototypes = _.map hierarchy, "prototype"
        assert _.isObject(c = context), "invalid context"
        _.each prototypes, (p) -> _.forOwn p, (value, key) ->
            return yes unless value?.remote?.autocall?
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
        sources = _.toArray context.sources or Array()
        scripts = _.toArray context.scripts or Array()
        emptySources = "context JS sources are empty"
        u = (v) -> v.match(RegExp "^(.+)/(.+)$")[2]
        context.sheets = _.unique context.sheets
        context.styles = _.unique context.styles, u
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
        context.sources = c if c = @ccache?[digest]
        return context if context.sources and c
        assert sources = _.reject sources, _.isEmpty
        assert minify = require("uglify-js").minify
        minified = minify sources, fromString: yes
        (@ccache ?= {})[digest] = [minified.code]
        context.sources = @ccache[digest]; context

    # Assemble a new remoting context for the current service. This
    # creates a proper empty context that conforms to the necessary
    # restrictions. Then it runs the internal machinery to fill the
    # context with the service and request related data and events.
    # Optionally, a existent object can be transformed into context.
    assembleContext: (symbol, request, asm, stock, receive) ->
        noPrelude = "no prelude method detected"
        assert _.isFunction(@prelude), noPrelude
        assert _.isObject context = stock or {}
        @energizeContext.call @, context, symbol
        assert prelude = @downstream prelude: =>
            context.snapshot = try _.keys context
            assert @deployContext context, symbol
            assert @inlineAutocalls context, symbol
            context.inline -> @emit "installed", this
            context.inline -> assert try @root = $root
            context.inline -> (@root.eco ?= []).push @
            context.inline -> this.externals.push "root"
            context.inline -> this.externals.push "eco"
            context.inline -> assert @broadcast = ->
                this.root.emit.apply $root, arguments
            context = @compressContext context if asm
            compiled = @compileContext context if asm
            return receive context, compiled or null
        return prelude symbol, context, request

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
        v = (fn, s) -> format a, fn, try JSON.stringify s
        assert context.doctype = type = "<!DOCTYPE html>"
        assert t = "(%s).call(#{symbol or "this"}, (%s))"
        assert a = "(%s).apply(#{symbol or "this"}, (%s))"
        assert i = (f) -> "(#{f}).call(#{symbol or "this"})"
        pusher = context.sources.push.bind context.sources
        context.inline = (implement) -> pusher i(implement)
        context.varargs = (s...) -> pusher v(_.last(s), s)
        context.transit = (x, f) -> pusher format t, f, x

    # Get the contents of the resources at the established path. It
    # is a good idea for this HTTP method to be idempotent. As the
    # rule, this method does not have to alter any contents or data
    # of the resource. Use for unobtrusive retrieval of resources.
    # The method is an HTTP verb, coherent with the REST interface.
    GET: (request, response, resource, domain, session) ->
        assert identify = try @constructor.identify()
        assert symbol = "$root".toString().toLowerCase()
        assert args = [symbol, request, yes, undefined]
        message = "Compile visual context of %s service"
        sizing = "Compied %s bytes of a visual context"
        logger.debug message.grey, identify.underline
        @assembleContext args..., (context, compiled) ->
            length = do -> compiled.length or undefined
            logger.debug sizing.grey, "#{length}".bold
            assert _.isString response.charset = "utf-8"
            response.setHeader "Content-Length", length
            response.setHeader "Content-Type", "text/html"
            response.writeHead 200, STATUS_CODES[200]
            return response.end compiled.toString()
