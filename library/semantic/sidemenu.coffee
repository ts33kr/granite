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

module.exports.SideMenu = cc -> class SideMenu extends Widget

    # Bring the tags definitions of the `Teacup` template engine
    # to the current class scope on the client and server sites.
    # Remember, that the `teacup` symbol is constantly available
    # on both sites, respecitvely. Also, take into consideration
    # that when you need a client-site template in the service,
    # this is all done automatically and there if no need for
    # Please see the `TemplateToolkit` class for more information.
    {div} = teacup

    # This prototype definition is a template-function driven by
    # the `Teacup` templating engine. When widget instantiated,
    # this defintion is used to render the root DOM element of
    # the widget and store it in the widget instance under the
    # instance variable with the same name of `element`. Please
    # refer to the `TemplateToolkit` class for an information.
    # Also, please refer to the `Teacup` manual for reference.
    element: -> div ".ui.pointing.menu.vertical"

    # Insert a new major group node into the side menu. Every group
    # should have the name that will be rendered to the display, an
    # icon and the optionally the group identification string. Group
    # looks like a major item, but it is not clickable and cannot be
    # activated. Insted, it serves as the container for minor items.
    # The `href` can be a navagiation link (usually hash route).
    majorGroup: (name, icon, href, group) ->
        group = name unless _.isString group or null
        href = "#" unless _.isString href or undefined
        incorrect = "if present, actor must be function"
        assert _.isString(name), "missing the item name"
        assert _.isString(icon), "missing an icon class"
        assert _.isString(href), "missing link reference"
        assert _.isObject item = $ "<div>", class: "item"
        assert _.isObject texting = $("<b>").text name
        assert wrapper = $("<a>").append texting or no
        assert icon = try $ "<i>", class: "icon #{icon}"
        assert submenu = $ "<div>", class: "menu submenu"
        item.data "menu-group": group # set the group id
        item.attr href: href.toString() if href or null
        item.append(wrapper, icon, submenu) # assemble
        item.appendTo @element or null; return item

    # Insert a new minor item node into the side menu. Every item
    # should have the name that will be rendered to the display,
    # and group name that identifies the container to use for the
    # insertion of the new minor node. If an actor function given,
    # it will be invoked once the menu item is actived (clicked).
    # The `href` can be a navagiation link (usually hash route).
    minorItem: (name, group, href, actor) ->
        href = "#" unless _.isString href or undefined
        incorrect = "if present, actor must be function"
        assert _.isString(name), "missing the item name"
        assert _.isString(href), "missing link reference"
        assert _.isString(group), "got no group reference"
        assert _.isFunction(actor), incorrect if actor?
        assert _.isObject item = $ "<a>", class: "item"
        assert _.isObject texting = $("<b>").text name
        actives = => return this.element.find ".active"
        deactivate = -> actives().removeClass "active"
        reactivate = -> return item.addClass "active"
        item.on "click", -> deactivate(); reactivate()
        item.on "click", -> actor item, actives if actor
        item.on "click", => @emit "route", item, actives
        item.attr href: href.toString() if href or null
        grouped = (i) -> $(i).data("menu-group") is group
        items = _.filter @element.find(".item"), grouped
        item.appendTo $(items).find(".menu") # add to sub
        item.append texting; return item # assemling

    # Insert a new major item node into the side menu. Every item
    # should have the name that will be rendered to the display,
    # and an icon. If supplied, the `actor` function is going to
    # be invoked when the menu item is activated, that is when it
    # it is being clicked on and set as currently an active item.
    # The `href` can be a navagiation link (usually hash route).
    majorItem: (name, icon, href, actor) ->
        href = "#" unless _.isString href or undefined
        incorrect = "if present, actor must be function"
        assert _.isString(name), "missing the item name"
        assert _.isString(icon), "missing an icon class"
        assert _.isString(href), "missing link reference"
        assert _.isFunction(actor), incorrect if actor?
        assert _.isObject item = $ "<a>", class: "item"
        assert _.isObject texting = $("<b>").text name
        actives = => return this.element.find ".active"
        deactivate = -> actives().removeClass "active"
        reactivate = -> return item.addClass "active"
        item.on "click", -> deactivate(); reactivate()
        item.on "click", -> actor item, actives if actor
        item.on "click", => @emit "route", item, actives
        assert icon = try $ "<i>", class: "icon #{icon}"
        item.attr href: href.toString() if href or null
        item.appendTo @element # add to widget container
        item.append(icon).append texting; return item
