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

{external} = require "../membrane/remote"
{Dialogue} = require "../semantic/dialogue"
{Semantic} = require "../semantic/flavours"
{Application} = require "../gearbox/application"

# This is an abstract base class that is intended to be used as the
# foundation for applications within the RAD core, provided by this
# framework. It contains a set of encapsulated routine that perform
# certain configurations and setups that have the visiable, visual
# impact on what is being rendered on the client side, when certain
# situations occure. Please refer to the source code for details.
module.exports.Layout = class Layout extends Application

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # These declarations below are implantations of the abstracted
    # components by the means of the dynamic recomposition system.
    # Please take a look at the `Composition` class implementation
    # for all sorts of information on the composition system itself.
    # Each of these will be dynamicall integrated in class hierarchy.
    @implanting Semantic

    # This block here defines a set of translation files that are
    # used by the service. Please keep in mind, that translations
    # are inherited from all of the base classes, and the tookit
    # then loads each translation file and combines all messages
    # into one translation table that is used throughout service.
    @translation "layout.yaml", @EMBEDDED_LOCALE

    # This setting can be overriden multiple times by descendants.
    # It controls whether the layout will render and make use of
    # the page dimmer. The page dimmer is used for two purposes.
    # One purpose is to illustrate that the system is starting up.
    # The second one is to show when the system looses connection.
    # By default, the page dimmer is being enabled and rendered.
    @ENABLE_PAGE_DIMMER: yes

    # Once the frontend part of this service is assembled, this
    # function will be invoked to take control of the previously
    # constructed and rendered dimmer. The dimmer is already there
    # as it were rendered on the server side and transferred here.
    # This code manages the workflow of when the dimmer is shown
    # and when it is hidden. Also, it manages contents of dimmer.
    layoutToolchain: @awaiting "assembled", ->
        assert delay = 1000 # milliseconds to wait for
        sel = ".dimmer"; con = ".dimmer>.content>.center>h2"
        assert dShow = -> $(sel).dimmer "show"; $(con).show()
        assert dHide = -> $(sel).dimmer "hide"; $(con).hide()
        assert dOpts = -> $(".dimmer").dimmer closable: false
        assert dText = (t) -> $(".dimmer").find("h2").append t
        assert dIcon = (i) -> $(".dimmer").find("h2").append i
        assert debounce = (xt, xf) -> return _.debounce xf, xt
        waiting = @th "attempting to restore the connection"
        $(document).ready -> dShow(); dOpts() # show & conf
        this.on "completed", -> try setTimeout dHide, delay
        this.on "disconnect", debounce 1000, -> # low latency
            return unless $(".dimmer").find("h2").length > 0
            $(".dimmer").find("h2").empty() # clear contents
            icon = $ "<i>", class: "inverted emphasized"
            icon.addClass "icon circular teal warning"
            dIcon icon; dText waiting # set new values
            return dShow() # show the new dimmer again

    # This is a declaration of the rendering function that will be
    # invoked during the initial rendering phase of this service
    # lifecycle. This function performs on the server side and its
    # result is compiled as HTML, which then gets directly emited.
    # This implementation sets up the usable dimmer for a layout.
    # The dimmer is by-default inactive, see the methods above.
    @rendering ($, document, next) -> @i18n =>
        noConti = "the continuation function is missing"
        noDocument = "the document has not been supplied"
        texting = @th "please wait, system is starting up"
        assert _.isFunction($), "missing jquery emulator"
        assert _.isFunction(next or undefined), noConti
        assert _.isObject(document or null), noDocument
        return next() unless @constructor.ENABLE_PAGE_DIMMER
        assert icon = $("<i>").addClass "icon circular"
        assert head = $("<h2>").append icon, texting
        assert dim = $("<div>").addClass "ui page dimmer"
        assert content = $("<div>").addClass "content"
        assert center = $("<div>").addClass "center"
        icon.addClass "inverted emphasized teal laptop"
        head.addClass "inverted ui icon header" # size
        dim.append content.append center.append head
        $("body").append dim; return next()
