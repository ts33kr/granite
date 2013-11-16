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

{Zombie} = require "../nucleus/zombie"
{remote} = require "../membrane/remote"
{Archetype} = require "../nucleus/archetype"
{Preflight} = require "../membrane/preflight"
{GoogleFonts} = require "../exposure/fonting"

# This is a zombie like service that is designed to offer help with
# one of the most tedious and routine task of creating, managing and
# working with the forms that are presented to take in and process
# the user entered data, structured in a certain, prediciatable way.
# Please refer to the implementation for information on how to use.
module.exports.Formular = remote -> class Formular extends Archetype

    # This is the initialization method that creates a form within
    # the specified hosting element (or selector) and then runs the
    # payload function (if supplied) that should fill the form with
    # the fields. If missing - that can be done later directly via
    # instance methods of the formular which correspond to fields.
    constructor: (hosting, reference, payload) ->
        payload = (-> null) unless _.isFunction payload
        do -> hosting = $(hosting) if _.isString hosting
        assert _.isObject(hosting), "got invalid hosting"
        assert _.isString(reference), "invalid reference"
        assert _.isFunction(payload), "malformed payload"
        scoped = => return payload.apply this, arguments
        @warnings = $ "<div>", class: "ui warning message"
        @errors = $ "<div>", class: "ui error message err"
        @container = $ "<div>", class: "ui form segment"
        @container.append @errors, @warnings # invisible
        @container.appendTo(hosting); scoped @container
        this.emit "configure-form", @container, @payload
        @hosting = hosting; @reference = reference; this

    # Group the two previously created fields (passed by either as
    # direct object or the selectors) into a one horizontal field
    # that is going to equally share the space between two fields.
    # This method is going to internally insert the grouper right
    # before the first field and them move both fields to grouper.
    groupTwoFields: (fieldOne, fieldTwo) ->
        selectorOne = fieldOne and _.isString fieldOne
        selectorTwo = fieldTwo and _.isString fieldTwo
        fieldOne += ".field".toString() if selectorOne
        fieldTwo += ".field".toString() if selectorTwo
        fieldOne = @container.find fieldOne if selectorOne
        fieldTwo = @container.find fieldTwo if selectorTwo
        assert _.isObject(fieldOne), "invalid object A given"
        assert _.isObject(fieldTwo), "invalid object B given"
        assert union = try $ "<div>", class: "two fields"
        union.insertBefore fieldOne # place before A field
        fieldOne.appendTo union; fieldTwo.appendTo union

    # Create a field that is typically would be used to enter the
    # password or similar information that should not be displayed
    # while it is being typed in. The field has the asterisk to it
    # and can optionally attach an icon to the field (recommended).
    # In other ways, it is structurally equal to `starred` field.
    hidden: (identity, synopsis, icon) ->
        assert _.isObject label = $ "<label>", class: "label"
        assert _.isObject input = $ "<input>", type: "password"
        field = $("<div>", class: "field").appendTo @container
        wrap = $ "<div>", class: "icon input ui left labeled"
        assert corner = $ "<div>", class: "ui corner label"
        assert asterisk = $ "<i>", class: "icon asterisk"
        assert icon = $ "<i>", class: "icon #{icon}" if icon
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
    starred: (identity, synopsis, icon) ->
        assert _.isObject input = $ "<input>", type: "text"
        assert _.isObject label = $ "<label>", class: "label"
        field = $("<div>", class: "field").appendTo @container
        wrap = $ "<div>", class: "icon input ui left labeled"
        assert corner = $ "<div>", class: "ui corner label"
        assert asterisk = $ "<i>", class: "icon asterisk"
        assert icon = $ "<i>", class: "icon #{icon}" if icon
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
    checkbox: (identity, synopsis, onpos, onneg) ->
        assert _.isString what = "ui checkbox".toString()
        assert _.isObject label = $ "<label>", class: "label"
        assert _.isObject input = $ "<input>", type: "checkbox"
        field = $("<div>", class: "field").appendTo @container
        wrap = $ "<div>", class: what; field.addClass "inline"
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
    regular: (identity, synopsis, icon) ->
        assert _.isObject input = $ "<input>", type: "text"
        assert _.isObject label = $ "<label>", class: "label"
        field = $("<div>", class: "field").appendTo @container
        wrap = $ "<div>", class: "icon input ui left labeled"
        assert icon = $ "<i>", class: "icon #{icon}" if icon
        assert input.attr placeholder: synopsis.toString()
        try $(field).data "identity", identity.toString()
        field.addClass try identity.toString() if identity
        field.append label, wrap; input.appendTo wrap
        if icon then wrap.append icon else no; field
