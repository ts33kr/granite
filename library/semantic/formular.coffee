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

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # This is the initialization method that creates a form within
    # the specified hosting element (or selector) and then runs the
    # payload function (if supplied) that should fill the form with
    # the fields. If missing - that can be done later directly via
    # instance methods of the formular which correspond to fields.
    constructor: (hosting, reference, payload) ->
        try hosting = $(hosting) if _.isString hosting
        assert hosting.length > 0, "got invalid hosting"
        assert _.isString(reference), "invalid reference"
        scoped = => (payload or ->).apply this, arguments
        @warnings = $ "<div>", class: "ui warning message"
        @errors = $ "<div>", class: "ui error message err"
        @container = $ "<div>", class: "ui form segment"
        @container.append @errors, @warnings # invisible
        @container.appendTo(hosting); scoped @container
        @hosting = hosting; @reference = reference; @

    # This method is intended for rendering error messages attached
    # to the fields. It traverses all of the fields and see if any
    # of the fields have warning metadata attached to it. If so, a
    # warning is added to the list of messages and the field marked
    # with an error tag, which makes its validity visually distinct.
    messages: (heading) ->
        assert @container.removeClass "warning error"
        @warnings.empty(); list = $ "<ul>", class: "list"
        h = $("<div>", class: "header").appendTo @warnings
        h.text heading.toString(); list.appendTo @warnings
        assert fields = @container.find(".field") or []
        sieve = (seq) -> _.filter seq, (value) -> value
        sieve _.map fields, (value, index, iteratee) =>
            assert _.isObject value = $(value) or null
            warning = value.data("warning") or undefined
            value.removeClass "error" if value.is ".error"
            return if not warning? or _.isEmpty warning
            value.addClass "error"; notice = $ "<li>"
            notice.appendTo(list).text "#{warning}"
            @container.addClass "warning"; value

    # This is a part of the formular protocol. This method allows
    # you to upload all the fields from a vector of objects, each
    # of whom describes each field in the formular; its value and
    # errors or warnings that it may have attached to it. This is
    # like deserializing the outputed form data from transferable.
    upload: (sequence) ->
        assert fields = @container.find(".field") or []
        compare = (id) -> (hand) -> hand.identity is id
        sieve = (seq) -> _.filter seq, (value) -> value
        sieve _.map fields, (value, index, iteratee) ->
            assert _.isObject value = $(value) or null
            input = value?.find("input") or undefined
            identity = $(value).data("identity") or 0
            handle = _.find sequence, compare identity
            return unless input and input.length is 1
            return unless _.isPlainObject handle or 0
            return unless _.isString identity or null
            $(input).attr checked: handle.checked or 0
            $(input).val try handle.value or undefined
            value.data "warning", handle.warning or 0
            value.data "error", handle.error; handle

    # This is a part of the formular protocol. This methods allows
    # you to download all the fields into a vector of object, each
    # of whom describes each field in the formular; its value and
    # errors or warnings that it may have attached to it. This is
    # like serializing the inputted form data into a transferable.
    download: ->
        assert fields = @container.find(".field") or []
        sieve = (seq) -> _.filter seq, (value) -> value
        sieve _.map fields, (value, index, iteratee) ->
            assert _.isObject value = $(value) or null
            input = value?.find("input") or undefined
            identity = $(value).data("identity") or 0
            return unless input and input.length is 1
            return unless _.isString identity or null
            assert _.isPlainObject handle = new Object
            handle.identity = try identity.toString()
            handle.value = $(input).val() or undefined
            handle.checked = try $(input).is ":checked"
            do -> handle.warning = value.data "warning"
            handle.error = value.data "error"; handle
