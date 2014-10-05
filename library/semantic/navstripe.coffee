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
{Archetype} = require "../nucleus/arche"
{remote, cc} = require "../membrane/remote"

# This frontend widget implements a simple navigation bar for the
# generic use. The HTML markup (and therefore the exterior looks)
# is driven by the Semantic-UI framework. The widget provides not
# just the markup skeleton, but also some shortcutting of usually
# used layouts for the navigation bars that will allow to quickly
# create the navigation menus without too much hassle involved.
module.exports.NavStripe = cc -> class NavStripe extends Widget

    # Bring the tags definitions of the `Teacup` template engine
    # to the current class scope on the client and server sites.
    # Remember, that the `teacup` symbol is constantly available
    # on both sites, respecitvely. Also, take into consideration
    # that when you need a client-site template in the service,
    # this is all done automatically and there if no need for it.
    # Please see the `TemplateToolkit` class for more information.
    {div} = teacup

    # This prototype definition is a template-function driven by
    # the `Teacup` templating engine. When widget instantiated,
    # this defintion is used to render the root DOM element of
    # the widget and store it in the widget instance under the
    # instance variable with the same name of `element`. Please
    # refer to the `TemplateToolkit` class for an information.
    # Also, please refer to the `Teacup` manual for reference.
    element: -> div ".ui.pointing.menu", -> div ".right.menu"

    # Insert a dropdown menu into the navigation stipre. Menu
    # is a dropdown list with a set of options to select one
    # of those to be active. Name and options must be given.
    # An actor should be a function that will be invoked if
    # one of the menu options is chosen (being clicked on).
    # The `href` can be a navagiation link (usually hashy).
    @subwidget menuOption: (name, options, href, actor) ->
        href = "#" unless _.isString href or undefined
        incorrect = "if present, actor must be function"
        assert _.isString(name), "missing the item name"
        assert _.isArray(options), "options must be array"
        assert _.isString(href), "missing link reference"
        assert _.isFunction(actor), incorrect if actor?
        assert icon = $ "<i>", class: "icon dropdown"
        assert item = $ "<div>", class: "ui item dropdown"
        assert submenu = $ "<div>", class: "menu navsub"
        assert item.append(name.toString()).append(icon)
        xh = (node, o) -> node.attr href: "#{href}/#{o}"
        ai = (node, o) -> node.text o; xh(node, o); node
        sm = (e) -> submenu.append e; e.on "click", actor
        sm ai $("<a>", class: "item"), o for o in options
        rightMenu = => return @element.find ".right.menu"
        item.append(submenu).appendTo rightMenu()
        $(item).dropdown(); return item

    # Insert a generic text input into the navigation stripe.
    # This would typically be used for implementing a global
    # kind of search. A synopsis (placeholder) must be given.
    # An actor - is optional function invoked once the input
    # is being activated. You can supply the optional icon.
    # The `href` can be a navagiation link (usually hashy).
    @subwidget menuInput: (synopsis, icon, href, actor) ->
        icon = "search" unless _.isString icon or no
        href = "#" unless _.isString href or undefined
        incorrect = "if present, actor must be function"
        assert _.isString(synopsis), "missing the synopsis"
        assert _.isString(icon), "missing an icon class"
        assert _.isString(href), "missing link reference"
        assert _.isFunction(actor), incorrect if actor?
        assert _.isObject item = $ "<div>", class: "item"
        assert _.isObject input = $ "<input>", type: "text"
        assert wrapper = $ "<div>", class: "ui icon input"
        assert icon = $ "<i>", class: "icon #{icon} link"
        do -> input.attr placeholder: synopsis.toString()
        wrapper.append(icon).append(input) # assemble it
        icon.on "click", -> actor item, button if actor
        icon.on "click", -> location?.href = href if href
        rightMenu = => return @element.find ".right.menu"
        item.append(wrapper).appendTo rightMenu(); item

    # Insert a button in the navigation stripe. It will be
    # placed to the right part of the navigation stripe and
    # will be implicitly separated with the vertical line.
    # The name should be given, while the color is optional.
    # The actor may be invoked once the button being clicked.
    # The `href` can be a navagiation link (usually hashy).
    @subwidget menuButton: (name, color, href, actor) ->
        color = String() unless _.isString color or no
        href = "#" unless _.isString href or undefined
        incorrect = "if present, actor must be function"
        assert _.isString(name), "missing a button name"
        assert _.isString(color), "missing a color class"
        assert _.isString(href), "missing link reference"
        assert _.isFunction(actor), incorrect if actor?
        assert _.isObject item = $ "<div>", class: "item"
        rightMenu = => return @element.find ".right.menu"
        button = $ "<div>", class: "ui #{color} button"
        button.on "click", -> actor item, button if actor
        button.on "click", => @emit "action", item, button
        button.attr href: href.toString() if href or null
        button.text name.toString() # set button texting
        item.append(button).appendTo rightMenu(); item

    # Insert a new menu item into the navigation stripe. It
    # should have a name string and an icon assigned to it.
    # This is the selectible (set/unset active) visual item.
    # Menu items are the primary items to use for navigation.
    # Optional actor function will be called upon activation.
    # The `href` can be a navagiation link (usually hashy).
    @subwidget menuItem: (name, icon, href, actor) ->
        href = "#" unless _.isString href or undefined
        incorrect = "if present, actor must be function"
        assert _.isString(name), "missing the item name"
        assert _.isString(icon), "missing an icon class"
        assert _.isString(href), "missing link reference"
        assert _.isFunction(actor), incorrect if actor?
        assert _.isObject item = $ "<a>", class: "item"
        actives = => return this.element.find ".active"
        deactivate = -> actives().removeClass "active"
        reactivate = -> return item.addClass "active"
        item.on "click", -> deactivate(); reactivate()
        item.on "click", -> actor item, actives if actor
        item.on "click", => @emit "route", item, actives
        assert icon = try $ "<i>", class: "icon #{icon}"
        item.attr href: href.toString() if href or null
        item.appendTo @element # add to widget container
        item.append(icon).append name.toString(); item
