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

# Monitor object is at the heart of visual subsystem for framework.
# It contains a tree snapshot, a transport object and some internal,
# necessary objects. The monitor implements passing of events and
# data between the server side and the client side interpreter. It
# is the mechanism that keeps the synchronization between the trees.
module.exports.Monitor = class Monitor extends events.EventEmitter

    # This is the reference of the DOM events that need to be
    # monitored by the monitor and possible by some other entities
    # in the framework subsustems. The actual registry of events is
    # being loaded from the module in this dir, called `reference`.
    @REFERENCE = require "#{__dirname}/reference"

    # Public constructor for creating new monitor object. Please do
    # not use it directly, since managing the lifecyle of the monitor
    # object is the responsibility of the internal services that are
    # dedicated for this purpose. Each monitor has an UUID tag to it.
    constructor: (@kernel, @tag = uuid.v1()) ->
        isKernel = @kernel instanceof kernel.Kernel
        noKernel = "The instance of kernel is invalid"
        noTagging = "The supplied tagging is not valid"
        throw new Error noTagging unless _.isSring tag
        throw new Error noKernel unless isKernel

    # Attach one of the ends of the monitor to the previously bound
    # transport instance. This method will attach the specific event
    # handlers for all of the reference events, which will transfer
    # the event into the corresponding event on the bound element.
    attachToTransport: -> for descriptor in @constructor.REFERENCE
        @transport.on descriptor.event, (event, origin, context) ->
            resolved = @element.resolve origin
            missing = "Cannot resolve element #{origin}"
            throw new Error missing unless resolved?
            @element.emit event, resolved, context

    # Attach one of the ends of the monitor to the previously bound
    # element instance. This method will attach the specific event
    # handlers for all of the reference events, which will transfer
    # the event into the corresponding event on the bound transport.
    attachToTransport: -> for descriptor in @constructor.REFERENCE
        @element.on descriptor.event, (event, origin, context) ->
            tagging = @element.tag or undefined
            missing = "The element has not tag attached"
            throw new Error missing unless tagging?
            @transport.emit event, tagging, context

    # Set the transport channel of this session. If the transport is
    # not supplied, the method will return the transport instead of
    # setting one. The transport will be tested to ensure that it is
    # of the correct type. Please use instances of an `EventEmitter`.
    transport: (transport) ->
        return @$transport unless transport?
        invalid = "The supplied transport is invalid"
        correct = transport instanceof events.EventEmitter
        throw new Error invalid unless correct
        @emit "transport", this, @$transport, transport
        attachToTransport @$transport = transport; this

    # Set the root tree element of this session. If the element is
    # not supplied, the method will return the element instead of
    # setting one. The element will be tested to ensure that it is
    # of the correct type. Please use instances of `Element` class.
    element: (element) ->
        return @$element unless element?
        invalid = "The supplied element is invalid"
        correct = element instanceof trees.Element
        throw new Error invalid unless correct
        @emit "element", this, @$element, element
        attachToElement @$element = element; this
