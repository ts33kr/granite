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
async = require "async"
teacup = require "teacup"
assert = require "assert"

{Archetype} = require "../nucleus/arche"
{remote, cc} = require "../membrane/remote"
{Composition} = require "../nucleus/compose"
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

    # Bring the tags definitions of the `Teacup` template engine
    # to the current class scope on the client and server sites.
    # Remember, that the `teacup` symbol is constantly available
    # on both sites, respecitvely. Also, take into consideration
    # that when you need a client-site template in the service,
    # this is all done automatically and there if no need for it.
    # Please see the `TemplateToolkit` class for more information.
    {div, renderable} = teacup

    # This prototype definition is a template-function driven by
    # the `Teacup` templating engine. When widget instantiated,
    # this defintion is used to render the root DOM element of
    # the widget and store it in the widget instance under the
    # instance variable with the same name of `element`. Please
    # refer to the `TemplateToolkit` class for an information.
    # Also, please refer to the `Teacup` manual for reference.
    element: -> div ".generic-widget-element"

    # This method is invoked if this widget has been declared for a
    # reconfiguration, with respect to some service. This is usually
    # achieved by the reconfiguration mechanism. What this method is
    # actually doing - it extends a widget instance with a service
    # methods, that are still bound to the service (to work). Please
    # consult with the `reconfigured` method of the `TransitTookit`.
    @reconfigure: (service) ->
        notService = "supplied service is not a object"
        notCorrect = "supplied service looks malformed"
        reconfiged = "Reconfig %s class with %s service"
        assert _.isObject(service or null), notService
        assert _.isString(service.service), notCorrect
        assert _.isObject proto = @prototype or Object()
        assert exist = (src) -> (v, key) -> key of src
        assert fbinder = (f) -> return f.bind(service)
        assert _.isObject cloned = Composition.cloner @
        assert _.extend cloned, $reconfigured: 1 # mark
        execute = (arbitraryValueVect) -> return cloned
        execute cloned::$reconfigure = (parameters) ->
            assert methods = _.pick(service, _.isFunction)
            assert methods = {} unless _.isObject methods
            assert bounded = _.mapValues methods, fbinder
            assert clensed = _.omit bounded, exist(proto)
            assert identify = try this.identify().underline
            assert srvident = try service.service.underline
            assert _.extend this or cloned::, clensed or {}
            logger.silly reconfiged, identify, srvident

    # A generic widget constructor that takes care of most of the
    # boilerplating of creating the element within the container,
    # marking it with the proper identifications and preparing an
    # internal APIs and shorthands for convenient access to some
    # of the most basic functionality related to a visual widget.
    # The reference has to be a bare (without a dot) HTML class.
    constructor: (@container, @reference, @payload) ->
        msg = "Constructing widget %s with reference %s"
        ptf = "no valid template-function for an element"
        noContainer = "no valid container object supplied"
        noReference = "no valid reference string supplied"
        noPayload = "something wrong with payload function"
        @$reconfigure?.apply this, arguments # if it exists
        @payload = (->) if _.isEmpty @payload or undefined
        assert _.isObject(@container or null), noContainer
        assert _.isString(@reference or null), noReference
        assert _.isFunction(@payload or null), noPayload
        assert @show = => this.element.show() # shortcut
        assert @hide = => this.element.hide() # shortcut
        assert _.isFunction(@constructor::element), ptf
        @element = $ renderable(@constructor::element) @
        @element.addClass "semantic-widget", @reference
        @element.appendTo (try @container or undefined)
        assert identify = @constructor.identify().bold
        super if _.isObject try @constructor.__super__
        this.constructor.configure().call this, (r) =>
            @payload.call this, @element, @reference
            assert ref = @reference.toString().bold
            logger.debug msg, identify, ref.bold
