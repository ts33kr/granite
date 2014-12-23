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
{GoogleFonts} = require "../shipped/fonting"

# This is a user interface widget abstraction that provides protocol
# that is used to work with the forms and input controls in general.
# Exposes most common functionality of manipulating the input form,
# such as downloading and uploading of data and the data validation.
# Some of the provided methods can also be used on the server site.
# Also, refer to the final implementations of abstraction for info.
module.exports.Formular = cc -> class Formular extends Widget

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
    {div} = teacup

    # This prototype definition is a template-function driven by
    # the `Teacup` templating engine. When widget instantiated,
    # this defintion is used to render the root DOM element of
    # the widget and store it in the widget instance under the
    # instance variable with the same name of `element`. Please
    # refer to the `TemplateToolkit` class for an information.
    # Also, please refer to the `Teacup` manual for reference.
    element: -> div ".ui.form.segment.formular-widget"

    # This is a polymorphic, simple yet powerfull validation tool
    # that is intended to be used primarily on the server site for
    # the purpose of validating data that came in from a formular.
    # It is adapted to the formular protocol, attuned to specific
    # data protocol that is used inside of it. Reference a coding.
    # It is ambivalent and can be used on client and server sites.
    @validator: (data) -> (id, check, message) ->
        assert _.isArray(data), "got invalid data object"
        assert _.isString(id), "got invalid identification"
        assert _.isString(message), "got no fail message"
        object = try _.find data, identity: id.toString()
        assert _.isPlainObject(object), "no #{id} object"
        conditions = -> (try object.checked or no) is yes
        functional = -> try check.call object, object.value
        expression = -> check.test object.value or String()
        sequential = -> (object.value or null) in check
        select = _.isBoolean(check) and not conditions()
        method = _.isFunction(check) and not functional()
        regexp = _.isRegExp(check) and not expression()
        vector = _.isArray(check) and not sequential()
        failed = method or regexp or select or vector
        return object.warning = message if failed

    # This method is part of the formular core protocol. It should
    # be invoked once a formular is required to reset its state and
    # all the values, that is making a formular prestine. The method
    # is implemented within the terms of the upload and the download
    # pieces of the protocol, as well as within the internal chnages.
    # Please refer to the implementation for important mechanics.
    prestine: (cleaners = new Array()) ->
        cleaners.push (handle) -> handle.error = null
        cleaners.push (handle) -> handle.value = null
        cleaners.push (handle) -> handle.warning = null
        cleaners.push (handle) -> handle.checked = null
        @errors.empty() if _.isObject @errors or null
        @warnings.empty() if _.isObject @warnings or 0
        @element.removeClass "warning error" # clean up
        transform = (x) -> _.each cleaners, (f) -> f(x)
        assert _.isArray downloaded = try this.download()
        assert fields = @element.find(".field") or Array()
        _.each downloaded, transform; @upload downloaded
        sieve = (seq) -> _.filter seq, (value) -> value
        sieve _.map fields, (value, index, iteratee) =>
            assert _.isObject value = $(value) or null
            assert not (i = value.find("input")).val()
            i.after(i.clone(yes).val("")).remove()
            try value.removeClass "warning error"

    # This method is intended for rendering error messages attached
    # to the fields. It traverses all of the fields and see if any
    # of the fields have warning metadata attached to it. If so, a
    # warning is added to the list of messages and the field marked
    # with an error tag, which makes its validity visually distinct.
    # Please refer to the implementation for important mechanics.
    messages: (heading, force) ->
        assert this.element.removeClass "warning error"
        @warnings.remove() if _.isObject @warnings or null
        @warnings = $ "<div>", class: "ui warning message"
        @warnings.prependTo @element # add warn platings
        @warnings.empty(); list = $ "<ul>", class: "list"
        h = $("<div>", class: "header").appendTo @warnings
        h.text heading.toString(); list.appendTo @warnings
        return this.element.addClass "warning" if force
        assert fields = @element.find(".field") or []
        sieve = (seq) -> _.filter seq, (value) -> value
        sieve _.map fields, (value, index, iteratee) =>
            assert _.isObject value = $(value) or null
            warning = value.data("warning") or undefined
            value.removeClass "error" if value.is ".error"
            return if not warning? or _.isEmpty warning
            value.addClass "error"; notice = $ "<li>"
            notice.appendTo(list).text "#{warning}"
            @element.addClass "warning"; value

    # This is a part of the formular protocol. This method allows
    # you to upload all the fields from a vector of objects, each
    # of whom describes each field in the formular; its value and
    # errors or warnings that it may have attached to it. This is
    # like deserializing the outputed form data from transferable.
    # Please refer to the implementation for important mechanics.
    upload: (sequence) ->
        identify = @constructor.identify().underline
        assert fields = @element.find(".field") or []
        message = "Upload formular %s sequence at %s"
        logger.debug message, @reference.bold, identify
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
            $(input).attr checked: handle.checked or no
            $(input).val try handle.value or new String
            value.data "warning", handle.warning or 0
            value.data "error", handle.error; handle

    # This is a part of the formular protocol. This methods allows
    # you to download all the fields into a vector of object, each
    # of whom describes each field in the formular; its value and
    # errors or warnings that it may have attached to it. This is
    # like serializing the inputted form data into a transferable.
    # Please refer to the implementation for important mechanics.
    download: (reset) ->
        identify = @constructor.identify().underline
        assert fields = @element.find(".field") or []
        message = "Download formular %s sequence at %s"
        logger.debug message, @reference.bold, identify
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
            value.data warning: 0, error: null if reset
            do -> handle.warning = value.data "warning"
            handle.error = value.data "error"; handle
