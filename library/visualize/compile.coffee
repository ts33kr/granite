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
uuid = require "node-uuid"
asciify = require "asciify"
connect = require "connect"
logger = require "winston"
events = require "events"
colors = require "colors"
nconf = require "nconf"
https = require "https"
paths = require "path"
http = require "http"
util = require "util"
fs = require "fs"

# This class is a rough draft implementation of the tree compiler.
# It compiles the entiry tree (or subtree) recursively into a subset
# of SGML. For all intents and purposes this representation can be
# used for XML and XHTML documents, which is the sole purpose for it.
module.exports.Compiler = class Compiler extends events.EventEmitter

    # A protected compilation routine that is part of the internal
    # compiler implementation. This method should not be directly
    # used by the end user. This is only for the implementation.
    # Please refer to the `compile` method implementation for info.
    content: (content) -> _.escape content.content()

    # A protected compilation routine that is part of the internal
    # compiler implementation. This method should not be directly
    # used by the end user. This is only for the implementation.
    # Please refer to the `compile` method implementation for info.
    attribute: (attribute) ->
        name = attribute.name().toString()
        value = _.escape attribute.value()
        prefixed = _.isString p = attribute.prefix()
        prefix = if prefixed then "#{p}:" else ""
        return "#{prefix}#{name}=\x22#{value}\x22"

    # A protected compilation routine that is part of the internal
    # compiler implementation. This method should not be directly
    # used by the end user. This is only for the implementation.
    # Please refer to the `compile` method implementation for info.
    element: (element) ->
        compiler = this.compile.bind this
        prefixed = _.isString p = element.prefix()
        prefix = if prefixed then "#{p}:" else ""
        attributes = element.traverse Attribute
        children = element.traverse Element, Content
        attributes = attributes.map(compiler).join "\x20"
        children = children.map(compiler).join ""
        id = "#{prefix}#{element.name().toString()}"
        "<#{id} #{attributes}>#{children}</#{id}>"

    # Recursively compile a tree of subtree, supplied as the abstract
    # parameter, into a string representation encoded as a subset of
    # SGML markup. For all intents and purposes it can be used for
    # XML, HTML or XHTML documents with the equal interoperability.
    compile: (abstract) -> switch
        when abstract instanceof Content then @content abstract
        when abstract instanceof Attribute then @attribute abstract
        when abstract instanceof Element then @element abstract
        else throw new Error "Unknown node: #{typeof(abstract)}"

    # Compile and return a string that contains the Document Type
    # Declaration construct. This construct can be used in any SGML
    # derived documents, such as HTML, XML or XHTML, which is why
    # this SGML compilation method was created in the first place.
    doctype: (type, scope, fpi, url) ->
        invalid = "The supplied doc type is invalid"
        throw new Error invalid unless _.isString type
        scope = if _.isString scope then scope else ""
        fpi = if _.isString fpi then "\x22#{fpi}\x22" else ""
        url = if _.isString url then "\x22#{url}\x22" else ""
        compact = (string) -> string.replace /\s+/g, "\x20"
        compact "<!DOCTYPE #{type} #{scope} #{fpi} #{url} >"

    # Compile and return a string that contains the XML declaration
    # construct. This construct specifies the version and encoding
    # of any XML document. This will typically be used to correctly
    # interpret the XML and XHTML documents by the end user client.
    xmldecl: (version, encoding) ->
        noVersion = "The supplied XML version is invalid"
        noEncoding = "The supplied XML encoding is invalid"
        throw new Error noVersion unless _.isString version
        throw new Error noEncoding unless _.isString encoding
        version = "version=\x22#{version}\x22" if version
        encoding = "encoding=\x22#{encoding}\x22" if encoding
        compact = (string) -> string.replace /\s+/g, "\x20"
        compact "<?xml #{version} #{encoding} ?>"
