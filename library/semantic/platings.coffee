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
{external} = require "../membrane/remote"
{Preflight} = require "../membrane/preflight"
{GoogleFonts} = require "../exposure/fonting"

{BoxedForms} = require "./shipped"
{WithinModal} = require "./modals"

# This is a abstract base class compound that combines modal window
# with a data form. Basically, this component provides the skeleton
# that scrapes the boilerplate routine of form submission and then
# reacting to the response away and lets you focus on what matters
# to your functionality, that is setting up the layout and fields.
module.exports.PlatedForms = class PlatedForms extends WithinModal

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # This block here defines a set of remote dependencies that are
    # going to be necessary to provide support for functionality is
    # is going to be implemented. Most of these libraries required
    # by the internal implementations of the various subcomponents.
    # Refer to `RToolkit` class implementation for the information.
    @transfer BoxedForms

    # This method is invoked once the `positive` event goes off in
    # the service. This event is fired once the positive action is
    # actived. That usually means a user pressing the okay button.
    # The implementation downloads the data from the form and then
    # submits it to the backend and reacts to the response it got.
    confirmedFormsSubmission: @awaiting "positive", ->
        try this.forms.container.addClass "loading"
        wrong = @t "Please check the information entered"
        assert _.isObject data = try @forms.download yes
        this.dataSubmission data, (success, values) =>
            this.forms.container.removeClass "loading"
            assert values and _.isObject values or null
            @forms.upload values; @forms.messages wrong
            return undefined unless success and values
            @paragraph = $ "<p>", class: "right aligned"
            iconical = "icon checkmark green massive ok"
            assert icon = $ "<i>", class: "#{iconical}"
            try this.actions.empty(); this.forms.hide()
            this.emit "acknowledged", success, values
            this.content.append icon, @paragraph

    # This method is invoked once the `configure-window` events goes
    # through the service. This event is fired once the modal window
    # is ready and can be configured. This implementation creates a
    # form inside of the content slot and performs a set of routines
    # to establish reasonable defaults that can be later overriden.
    configureHostingWindow: @awaiting "configure-window", ->
        unload = (seq) -> seq.removeClass "loading"
        disabler = -> selector().addClass "disabled"
        enabler = -> selector().removeClass "disabled"
        selector = => @window.find ".positive.button"
        closer = => return @window.find ".close.icon"
        clean = => try @forms.prestine(); disabler()
        @forms = new BoxedForms @content, "plated-form"
        @window.addClass "modal-form semantic-flavour"
        @actions.find(".positive").addClass "disabled"
        @header.text "Please fill the following form"
        @on "disconnect", -> try unload $ ".loading"
        @on "negative", => closer().click(); clean()
        @populateForms? disabler, enabler, @forms
        @emit "populate-forms", disabler, enabler
