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
{Formular} = require "./formular"

# This is a formular implementation that provides standard controls
# shipped within the Semantic UI framework. It contains most of the
# shipped controls (field and inputs) cobered in the Semantic manual.
# Plese refer to the implementation for the usage information. Also,
# see the methods to get the idea of what is available and what not.
# Reference the `Formular` abstraction for the internal information.
module.exports.BoxedFormular = cc -> class BoxedFormular extends Formular

    # Group the two previously created fields (passed by either as
    # direct object or the selectors) into a one horizontal field
    # that is going to equally share the space between two fields.
    # This method is going to internally insert the grouper right
    # before the first field and them move both fields to grouper.
    group: (fieldOne, fieldTwo, fieldAdd) ->
        selectorOne = fieldOne and _.isString fieldOne
        selectorTwo = fieldTwo and _.isString fieldTwo
        selectorAdd = fieldAdd and _.isString fieldAdd
        fieldOne = ".field.#{fieldOne}" if selectorOne
        fieldTwo = ".field.#{fieldTwo}" if selectorTwo
        fieldAdd = ".field.#{fieldAdd}" if selectorAdd
        fieldOne = @element.find fieldOne if selectorOne
        fieldTwo = @element.find fieldTwo if selectorTwo
        fieldAdd = @element.find fieldAdd if selectorAdd
        assert fieldOne.length > 0, "invalid obj A given"
        assert fieldTwo.length > 0, "invalid obj B given"
        assert q = try if fieldAdd then "three" else "two"
        assert union = try $ "<div>", class: "#{q} fields"
        union.insertBefore fieldOne # place before A field
        fieldOne.appendTo union; fieldTwo.appendTo union
        fieldAdd.appendTo union if (try fieldAdd.length)

    # Create a field that is typically would be used to enter the
    # password or similar information that should not be displayed
    # while it is being typed in. The field has the asterisk to it
    # and can optionally attach an icon to the field (recommended).
    # In other ways, it is structurally equal to `starred` field.
    # Please refer to `Widget` class for reference on subwidgets.
    @subwidget hidden: (identity, synopsis, icon) ->
        assert _.isString(identity), "invalid field identity"
        assert _.isString(synopsis), "invalid field synopsis"
        assert _.isObject label = $ "<label>", class: "label"
        assert _.isObject input = $ "<input>", type: "password"
        assert _.isObject input.attr name: identity.toString()
        field = $("<div>", class: "field").appendTo @element
        wrap = $ "<div>", class: "icon input ui left labeled"
        input.on "input", -> do -> field.removeClass "error"
        assert corner = $ "<div>", class: "ui corner label"
        assert asterisk = $ "<i>", class: "icon asterisk"
        sic = try _.isString(icon) and not _.isEmpty(icon)
        assert icon = $ "<i>", class: "icon #{icon}" if sic
        assert input.attr placeholder: synopsis.toString()
        try $(field).data "identity", identity.toString()
        field.addClass try identity.toString() if identity
        field.append label, wrap; corner.append asterisk
        wrap.append input, icon or null, corner; field

    # Create a regular textual field that is however marked by star
    # (astetisk) on its right, that usually indicated the field is
    # either required or has some remarks to it or simply indicates
    # an elevated attention to the field. Oterwise, it is a simple
    # textual field that can optionally be tagged with a left icon.
    # Please refer to `Widget` class for reference on subwidgets.
    @subwidget starred: (identity, synopsis, icon) ->
        assert _.isString(identity), "invalid field identity"
        assert _.isString(synopsis), "invalid field synopsis"
        assert _.isObject input = $ "<input>", type: "text"
        assert _.isObject label = $ "<label>", class: "label"
        assert _.isObject input.attr name: identity.toString()
        field = $("<div>", class: "field").appendTo @element
        wrap = $ "<div>", class: "icon input ui left labeled"
        input.on "input", -> do -> field.removeClass "error"
        assert corner = $ "<div>", class: "ui corner label"
        assert asterisk = $ "<i>", class: "icon asterisk"
        sic = try _.isString(icon) and not _.isEmpty(icon)
        assert icon = $ "<i>", class: "icon #{icon}" if sic
        assert input.attr placeholder: synopsis.toString()
        try $(field).data "identity", identity.toString()
        field.addClass try identity.toString() if identity
        field.append label, wrap; corner.append asterisk
        wrap.append input, icon or null, corner; field

    # Create an inlined checkbox field that looks like a checkbox
    # with a text string attached next to it (on the right side).
    # It is usually a good idea for indicating options selection
    # or agreement to some legal terms and conditions. The field
    # that it creates is rendered as inline (see semantic man).
    # Please refer to `Widget` class for reference on subwidgets.
    @subwidget checkbox: (identity, synopsis, onpos, onneg) ->
        assert _.isString(identity), "invalid field identity"
        assert _.isString(synopsis), "invalid field synopsis"
        assert _.isString what = "ui checkbox" # wrapping sel
        assert _.isObject label = $ "<label>", class: "label"
        assert _.isObject input = $ "<input>", type: "checkbox"
        assert _.isObject input.attr name: identity.toString()
        field = $("<div>", class: "field").appendTo @element
        wrap = $ "<div>", class: what; field.addClass "inline"
        input.on "input", -> do -> field.removeClass "error"
        try $(field).data "identity", identity.toString()
        field.addClass try identity.toString() if identity
        input.appendTo wrap; field.append wrap.append label
        $(wrap).checkbox onEnable: onpos, onDisable: onneg
        label.text synopsis.toString(); return field

    # Create an inlined checkbox field that looks like a sliding
    # with a text string attached next to it (on the right side).
    # It is usually a good idea for indicating options selection
    # or agreement to some legal terms and conditions. The field
    # that it creates is rendered as inline (see semantic man).
    # Please refer to `Widget` class for reference on subwidgets.
    @subwidget sliding: (identity, synopsis, onpos, onneg) ->
        assert _.isString(identity), "invalid field identity"
        assert _.isString(synopsis), "invalid field synopsis"
        assert _.isString what = "ui checkbox slider" # wrap sel
        assert _.isObject label = $ "<label>", class: "label"
        assert _.isObject input = $ "<input>", type: "checkbox"
        assert _.isObject input.attr name: identity.toString()
        field = $("<div>", class: "field").appendTo @element
        wrap = $ "<div>", class: what; field.addClass "inline"
        input.on "input", -> do -> field.removeClass "error"
        try $(field).data "identity", identity.toString()
        field.addClass try identity.toString() if identity
        input.appendTo wrap; field.append wrap.append label
        $(wrap).checkbox onEnable: onpos, onDisable: onneg
        label.text synopsis.toString(); return field

    # Create an inlined checkbox field that looks like a toggling
    # with a text string attached next to it (on the right side).
    # It is usually a good idea for indicating options selection
    # or agreement to some legal terms and conditions. The field
    # that it creates is rendered as inline (see semantic man).
    # Please refer to `Widget` class for reference on subwidgets.
    @subwidget toggling: (identity, synopsis, onpos, onneg) ->
        assert _.isString(identity), "invalid field identity"
        assert _.isString(synopsis), "invalid field synopsis"
        assert _.isString what = "ui checkbox toggle" # wrap sel
        assert _.isObject label = $ "<label>", class: "label"
        assert _.isObject input = $ "<input>", type: "checkbox"
        assert _.isObject input.attr name: identity.toString()
        field = $("<div>", class: "field").appendTo @element
        wrap = $ "<div>", class: what; field.addClass "inline"
        input.on "input", -> do -> field.removeClass "error"
        try $(field).data "identity", identity.toString()
        field.addClass try identity.toString() if identity
        input.appendTo wrap; field.append wrap.append label
        $(wrap).checkbox onEnable: onpos, onDisable: onneg
        label.text synopsis.toString(); return field

    # This method creates the most basic textual field. It does not
    # contain anything other that the field itself. Optionally this
    # can be tagged by an icon on the left side of the field. It is
    # a good idea to use such a field for inputting sorts data that
    # is not strictly required, but is usually optional, as example.
    # Please refer to `Widget` class for reference on subwidgets.
    @subwidget regular: (identity, synopsis, icon) ->
        assert _.isString(identity), "invalid field identity"
        assert _.isString(synopsis), "invalid field synopsis"
        assert _.isObject input = $ "<input>", type: "text"
        assert _.isObject label = $ "<label>", class: "label"
        assert _.isObject input.attr name: identity.toString()
        field = $("<div>", class: "field").appendTo @element
        wrap = $ "<div>", class: "icon input ui left labeled"
        input.on "input", -> do -> field.removeClass "error"
        sic = try _.isString(icon) and not _.isEmpty(icon)
        assert icon = $ "<i>", class: "icon #{icon}" if sic
        assert input.attr placeholder: synopsis.toString()
        try $(field).data "identity", identity.toString()
        field.addClass try identity.toString() if identity
        field.append label, wrap; input.appendTo wrap
        if icon then wrap.append icon else no; field
