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

# This class represents an abstract tree node that has no particular
# semantics implemented, but rather has a common behavior patterns
# that must be inherited by all kinds of different implementations.
# Defines the foundation for tree traversal and event propagation.
module.exports.Abstract = class Abstract extends events.EventEmitter

    # This is a marker that indicates to some internal substsems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    @abstract yes

    # A public node constructor. Be sure to invoke it in your node
    # implementations. By default it accepts parent node as param.
    # Each node should generally know its parent in order to create
    # complete and functional hierarchical tree for navigating it.
    constructor: (@parent, @tag = uuid.v1()) ->
        correct = @parent instanceof Abstract
        correct = correct or not @parent?
        abstract = "Cannot create abstract nodes"
        invalid = "Not valid parent node object"
        tagging = "The supplied tagging is not valid"
        throw new Error tagging unless _.isSring tag
        throw new Error abstract if @abstract()
        throw new Error invalid unless correct

    # The overriding of the standard `EventEmiter` emit method. This
    # implementation always keep track of the sender and propagates
    # the event up to the parent no, if such node has been defined.
    # The exact semantics of propagation and such can be changed.
    emit: (event, origin, parameters...) ->
        correct = origin instanceof Abstract
        invalid = "Not a valid origin node object"
        throw new Error invalid unless correct
        event.suppress = -> event.suppressing = yes
        listened = super event, origin, parameters...
        return if event.suppressing or @supermassive
        try @parent?.emit event, origin, parameters...

# This is an abstract base class for nodes that have the identity
# attached next to them. The identify consists of an optional prefix
# and not mandatory name, both expressed as strings. This class is
# a conretization of the top-level tree node abstract base class
module.exports.Identity = class Identity extends Abstract

    # This is a marker that indicates to some internal substsems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    @abstract yes

    # Either get or set the identification name string for this
    # element. For the semantics of the name please refer to the
    # XML and/or SGML specification documents. If the name param
    # is not supplied, this method will return the current name.
    name: (name) ->
        correct = _.isString name
        return @$name unless name?
        invalid = "Name is not a string"
        throw new Error invalid unless correct
        @emit "name", this, @$name, name
        @$name = name.toString()

    # Either get or set the identification prefix string for this
    # element. For the semantics of the prefix please refer to the
    # XML and/or SGML specification documents. If the prefix param
    # is not supplied, this method will return the current prefix.
    prefix: (prefix) ->
        correct = _.isString prefix
        return @$prefix unless prefix?
        invalid = "Prefix is not a string"
        throw new Error invalid unless correct
        @emit "prefix", this, @$prefix, prefix
        @$prefix = prefix.toString()

# This class represents an implementation of non abstract tree node
# that implements semantics of the textal content node, equal to
# XML text content. This node implementation inherits the root ABC
# and therefore provides no extra capabilies beyond what is does.
module.exports.Content = class Content extends Abstract

    # Either get or set the attr textual content string for this
    # element. For the semantics of the name please refer to the
    # XML and/or SGML specification documents. If the value content
    # is not supplied, this method will return the current content.
    content: (content) ->
        correct = _.isString content
        return @$content unless content?
        invalid = "Content is not a string"
        throw new Error invalid unless correct
        @emit "content", this, @$content, content
        @$content = content.toString()

# This class represents an implementation of non abstract tree node
# that implements semantics of the named, valueable node, equal to
# XML attrubte. This node implementation inherits the identity ABC
# and therefore provides the naming and identification capabilities.
module.exports.Attribute = class Attribute extends Identity

    # Either get or set the attr content value string for this
    # element. For the semantics of the name please refer to the
    # XML and/or SGML specification documents. If the value param
    # is not supplied, this method will return the current value.
    value: (value) ->
        correct = _.isString value
        return @$value unless value?
        invalid = "Value is not a string"
        throw new Error invalid unless correct
        @emit "value", this, @$value, value
        @$value = value.toString()

# This class represents an implementation of non abstract tree node
# that implements semantics of the hierarhical tree branch, equal to
# XML element. This node can contain child elements in the preserved
# order that they were added in. Also contains the name of the tag.
module.exports.Element = class Element extends Identity

    # Resolve the specific node by its tag. The method is recursive
    # and will look under the entire tree of this element. If no node
    # whose tag matches the supplied one can be found, the method
    # should return either undefined or false value, but not a node.
    resolve: (tag) ->
        correct = _.isString tag
        return this if @tag is tag
        invalid "The supplied node is not string"
        throw new Error invalid unless correct
        for index, node in (@children or [])
            return node if node.tag is tag
            continue unless node instanceof Element
            return child if child = node.reslove tag

    # Remove the supplied node from array of children nodes of
    # this element. The node undergoes some substantial testing
    # before it will be removed. If the node does not exist in the
    # element then the method will return as is. Idempotent method.
    remove: (node) ->
        correct = node instanceof Abstract
        invalid "The supplied node is not valid"
        abstract = "The supplied not is abstract"
        isEqual = (n) -> n.tag is node.tag
        throw new Error invalid unless correct
        throw new Error abstract if node.abstract()
        index = _.findIndex @children or [], isEqual
        @emit "remove", this, node, index if index?
        (@children ?= []).splice index, 1 if index?

    # Prepend the supplied node to the array of children nodes of
    # this element. The node undergoes some substantial testing
    # before it will be added. If the node already exists in the
    # element then it will not be added again. Idempotent method.
    prepend: (node) ->
        correct = node instanceof Abstract
        invalid "The supplied node is not valid"
        abstract = "The supplied not is abstract"
        isEqual = (n) -> n.tag is node.tag
        throw new Error invalid unless correct
        throw new Error abstract if node.abstract()
        exists = _.find @children or [], isEqual
        @emit "prepend", this, node unless exists?
        (@children ?= []).unshift node unless exists

    # Append the supplied node to the array of children nodes of
    # this element. The node undergoes some substantial testing
    # before it will be added. If the node already exists in the
    # element then it will not be added again. Idempotent method.
    append: (node) ->
        correct = node instanceof Abstract
        invalid "The supplied node is not valid"
        abstract = "The supplied not is abstract"
        isEqual = (n) -> n.tag is node.tag
        throw new Error invalid unless correct
        throw new Error abstract if node.abstract()
        exists = _.find @children or [], isEqual
        @emit "append", this, node unless exists?
        (@children ?= []).push node unless exists
