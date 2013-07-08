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
        listened = super event, origin, parameters...
        return if @blackhole or @suppress or not @parent?
        try @parent?.emit event, origin, parameters...
