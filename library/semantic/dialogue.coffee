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
teacup = require "teacup"
assert = require "assert"

{Widget} = require "./abstract"
{Coloring} = require "./coloring"
{Archetype} = require "../nucleus/arche"
{remote, cc} = require "../membrane/remote"

# This frontend widget implements a simple dialogue, rendered as a
# modal window. The HTML markup (and therefore the exterior looks)
# is driven by the Semantic-UI framework. The widget provides not
# just the markup skeleton, but also some cultivation of dialogue
# with the necessary events being emited and the required routine
# for the usage and configuration being provided out-of-the-box.
# Needs to be reconfigured with the service to satisfy the deps.
module.exports.Dialogue = cc -> class Dialogue extends Widget

    # Bring the tags definitions of the `Teacup` template engine
    # to the current class scope on the client and server sites.
    # Remember, that the `teacup` symbol is constantly available
    # on both sites, respecitvely. Also, take into consideration
    # that when you need a client-site template in the service,
    # this is all done automatically and there if no need for it.
    # Please see the `TemplateToolkit` class for more information.
    {div} = teacup

    # These declarations below are implantations of the abstracted
    # components by the means of the dynamic recomposition system.
    # Please take a look at the `Composition` class implementation
    # for all sorts of information on the composition system itself.
    # Each of these will be dynamicall integrated in class hierarchy.
    @implanting Coloring

    # This prototype definition is a template-function driven by
    # the `Teacup` templating engine. When widget instantiated,
    # this defintion is used to render the root DOM element of
    # the widget and store it in the widget instance under the
    # instance variable with the same name of `element`. Please
    # refer to the `TemplateToolkit` class for an information.
    # Also, please refer to the `Teacup` manual for reference.
    element: -> div ".ui.modal.dialogue-widget"

    # Create and insert a new action button. The buttin will be
    # placed within the actions container, where all the buttons
    # reside by the default. This method is a subwidget, which
    # means it will return a fully fledged widget object for it.
    # When button is pressed, a corresponding event is going to
    # be fired on the instance of this widget. If no event name
    # is explicitly given, the name of the button will be used.
    @subwidget actionButton: (name, icon, side, event) ->
        event = name unless _.isString event or null
        assert side = "right" unless _.isString side
        assert _.isString(name), "missing button name"
        assert _.isString(side), "missing an icon side"
        assert _.isString(event), "no event name given"
        assert action = try $ "<div>", class: "ui button"
        action.addClass "#{side} labeled icon action-button"
        assert s = (text) -> return $("<span>").text(text)
        assert mnemonic = $ "<i>", class: "#{icon} icon"
        mnemonic = undefined unless _.isString icon or 0
        action.removeClass "#{side} icon" unless mnemonic
        assert texting = $("<span>").html s this.t name
        assert action.prepend(texting).append(mnemonic)
        stop = (e) -> try e.stopImmediatePropagation()
        action.click (e) -> stop e if $(@).is ".disabled"
        action.click (e) => stop e unless @setInOrder()
        action.click (e) => @emit event, action; stop e
        this.actions.prepend action; return action

    # The auto-runned method that uses algorithmic approach for
    # building the helpers for the dialogue. The helpers are an
    # HTML structure that supplements modal window with all parts
    # necessary to implement a dialogue. The implementation uses
    # the Semantic-UI modal window components to build a helpers
    # up. So the semantics of an HTML tree conforms entirely to.
    assembleHelpers: @autorun axis: +102, ->
        @negative = $ "<div>", class: "ui negative button"
        @positive = $ "<div>", class: "ui positive button"
        assert s = (text) -> return $("<span>").text(text)
        assert stop = (e) -> try e.stopImmediatePropagation()
        $(@negative).click (e) -> stop e if $(@).is ".disabled"
        $(@positive).click (e) -> stop e if $(@).is ".disabled"
        $(@negative).click (e) => stop e unless @setInOrder()
        $(@positive).click (e) => stop e unless @setInOrder()
        $(@negative).click (e) => @emit "negative"; stop e
        $(@positive).click (e) => @emit "positive"; stop e
        this.negative.prepend $("<span>").html s @t "dismiss"
        this.positive.prepend $("<span>").html s @t "confirm"
        this.positive.append $ "<i>", class: "checkmark icon"
        assert this.title = => @headers.text _.head arguments
        assert this.positive.addClass "right labeled icon"
        assert this.actions.append @negative, @positive
        this.emit "configure-helpers", @element; this

    # The auto-runned method that uses algorithmic approach for
    # building the skeleton of the dialogue. The skeleton is an
    # HTML structure that composes a modal window with all parts
    # necessary being already installed. The implementation uses
    # the Semantic-UI modal window components to build an window
    # up. So the semantics of an HTML tree conforms entirely to.
    assembleSkeleton: @autorun axis: +101, ->
        unConfigured = "dialogue have to be configured"
        assert @constructor.$reconfigured, unConfigured
        assert this.headers = $ "<div>", class: "header"
        assert this.content = $ "<div>", class: "content"
        assert this.actions = $ "<div>", class: "actions"
        assert this.closing = $ "<i>", class: "close icon"
        assert _.isObject cross = @closing # the shorthand
        this.element.prepend @actions; @emit "set-actions"
        this.element.prepend @closing, @headers, @content
        cr = (f) => if f then cross.show() else cross.hide()
        cs = (f) => @element.modal "setting", "closable", f
        cf = (o) => @emit "settings", this # emit re-config
        assert this.show = => return @element.modal "show"
        assert this.hide = => return @element.modal "hide"
        assert this.toggle = => @element.modal "toggle"
        assert this.closable = (f) => cs f; cr f; cf @
        this.emit "configure-skeleton", @element; this
