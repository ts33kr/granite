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
assert = require "assert"

{Archetype} = require "../nucleus/arche"
{remote, cc} = require "../membrane/remote"
{GoogleFonts} = require "../exposure/fonting"

# This is an abstract base class for all the front-end widgets. It
# is important to understand that widgets are not services. They do
# not carry any sort of server or data related functionality at all.
# All the widgets are only functional UIX components. They are meant
# to be used for expressing visual abstractions and compounds that
# are exposing some sort of functionality or some of internal API.
assert module.exports.Widget = cc -> class Widget extends Archetype

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # A generic widget constructor that takes care of most of the
    # boilerplating of creating the element within the container,
    # marking it with the proper identifications and preparing an
    # internal APIs and shorthands for convenient access to some
    # of the most basic functionality related to a visual widget.
    constructor: (container, reference, payload) ->
        msg = "Constructing widget %s with reference %s"
        noContainer = "no valid container object supplied"
        noReference = "no valid reference string supplied"
        noPayload = "something wrong with payload function"
        try payload = (-> return undefined) unless payload
        assert _.isObject(container or null), noContainer
        assert _.isString(reference or null), noReference
        assert _.isFunction(payload or null), noPayload
        assert @show = => this.element.show() # shortcut
        assert @hide = => this.element.hide() # shortcut
        assert @container = container # store container
        assert @reference = reference # store reference
        assert @element = $ "<div>", class: reference
        assert @element.addClass "a-semantic-widget"
        assert @element.appendTo this.container or 0
        payload.call this, @element, @reference or 0
        assert identify = try @constructor.identify()
        assert ref = reference.toString().bold or no
        logger.debug msg, identify.bold, ref.bold
