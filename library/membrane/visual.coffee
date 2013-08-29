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
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"

tools = require "./../nucleus/tools"
extendz = require "./../nucleus/extends"
compose = require "./../nucleus/compose"

{format} = require "util"
{STATUS_CODES} = require "http"
{Barebones} = require "./skeleton"
{remote, external} = require "./remote"

# This is an abstract service that provides the unique functionality
# of rendering the server side store code on the client side with all
# its dependencies, such as classes and class hierarchies and even more.
# This ABC constitutes a primary tool for writing UI/UX with Granite.
# Please consult the implementation for more information on the system.
module.exports.Screenplay = class Screenplay extends Barebones

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    @abstract yes

    # Use this static method to mark up the remote/external methods
    # that need to be automaticalled called, once everything is set
    # on the client site and before the entrypoint gets executed. It
    # is a get idea to place generic or setup code in the autocalls.
    @autocall: (parameters..., method) ->
        isRemote = _.isObject method?.remote
        notFunction = "no function is passed in"
        assert _.isFunction(method), notFunction
        method = external method unless isRemote
        parameters = [] unless _.isArray parameters
        method.remote.autocall = parameters
        return method

    # This server side method is called on the context prior to the
    # context being compiled and flushed down to the client site. The
    # method is wired in an synchronous way for greater functionality.
    # This is the place where you would be importing the dependencies.
    prelude: (context, request, next) ->
        context.session = request.session
        context.uuid = request: request.uuid
        context.headers = request.headers
        context.params = request.params
        context.uuid.service = @uuid
        context.url = request.url
        return next()

    # Use this method in the `prelude` scope to bring dependencies into
    # the scope. This method supports JavaScript scripts as a link or
    # JavaScript sources passed in as the remote objects. Please refer
    # to the implementation and the class for more information on it.
    require: (context, subject, symbol) ->
        scripts = -> context.scripts.push subject
        sources = -> context.sources.push compile()
        compile = -> subject.remote?.compile? symbol
        invalid = "not a remote object and not a link"
        compilable = _.isFunction subject.remote?.compile
        return scripts() if _.isString subject
        return sources() if compilable
        throw new Error invalid

    # This is an internal routine that performs the task of compiling
    # a screenplay context into a valid HTML document to be rendered
    # and launched on the client (browser side). Please refer to the
    # implementation for greater understanding of what it does exactly.
    compileContext: (context) ->
        [x, c, j] = ["text/css", "stylesheet", "text/javascript"]
        sheet = (s) -> "<link rel=\x22#{c}\x22 href=\x22#{s}\x22>"
        style = (s) -> "<style type=\x22#{x}\x22>#{s}</style>"
        script = (s) -> "<script src=\x22#{s}\x22></script>"
        source = (s) -> "<script type=\x22#{j}\x22>#{s}</script>"
        template = "%s<html><head>%s</head><body></body></html>"
        sheets = _.map(context.sheets, sheet).join new String
        styles = _.map(context.styles, style).join new String
        scripts = _.map(context.scripts, script).join new String
        sources = _.map(context.sources, source).join new String
        joined = sheets + styles + scripts + sources
        format template, context.doctype, joined

    # This is an internal routine that performs a very important task
    # of deploying the context onto the call (client) site. It also
    # includes merging all the remoted defined in the services with a
    # context object, which is defered to be done on the client site.
    deployContext: (context) ->
        assert _.isObject context
        prepared = JSON.stringify context
        installer = "var context = #{prepared}"
        _.forIn this, (value, key, object) ->
            return unless _.isObject value.remote
            return unless src = value.remote.source
            set = "context.%s = (#{src})()"
            installer += "\r\n#{format set, key}\r\n"
        context.sources.unshift installer
        return context

    # Issue the autocalls into the context. Traverse the hierarchy
    # from top to bottom (the ordering is important) and issue an
    # autocall for each remote/external method that is marked with
    # an autocall decorator and therefore must be called on site.
    issueAutocalls: (context) ->
        hierarchy = @constructor?.hierarchy?()
        noHierarchy = "could not scan the hierarchy"
        assert _.isArray(hierarchy), noHierarchy
        hierarchy.push @constructor if hierarchy
        for peer in hierarchy then do (peer, hierarchy) ->
            _.forOwn peer.prototype, (value, key, object) ->
                return unless _.isObject value.remote
                return unless value.remote.autocall?.length?
                params = JSON.stringify value.remote.autocall
                template = "context.#{key}.apply(context, %s)"
                context.sources.push format(template, params)
        return context

    # Get the contents of the resources at the established path. It
    # is a good idea for this HTTP method to be idempotent. As the
    # rule, this method does not have to alter any contents or data
    # of the resource. Use for unobtrusive retrieval of resources.
    GET: (request, response) ->
        noPrelude = "no prelude method detected"
        assert _.isFunction(@prelude), noPrelude
        context = scripts: [], sources: [], styles: [], sheets: []
        context.doctype = "<!DOCTYPE html>"
        prelude = @upstreamAsync "prelude", =>
            context = @deployContext context
            context = @issueAutocalls context
            compiled = @compileContext context
            length = compiled.length or undefined
            response.setHeader "Content-Length", length
            response.setHeader "Content-Type", "text/html"
            response.writeHead 200, STATUS_CODES[200]
            response.end compiled.toString()
        return prelude context, request
