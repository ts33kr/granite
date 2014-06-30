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
{BoxFormular} = require "../semantic/standard"
{Behavior} = require "../exposure/behavior"

# This is a abstract base class compound that combines modal window
# with a data form. Basically, this component provides the skeleton
# that scrapes the boilerplate routine of form submission and then
# reacting to the response away and lets you focus on what matters
# to your functionality, that is setting up the layout and fields.
# As a basis, the service uses `BoxFormular` & `Dialogue` widgets.
assert module.exports.SimpleEntry = class SimpleEntry extends Behavior

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # Define a set of considerations used by this service. An every
    # consideration is one key/value pair. Where the key corresponds
    # to the type name (also known as token) and the  value is holding
    # either an implementation function or a remotable type (an alias).
    # This allows you to override type definitions that may be used in
    # the parent classes, without having to replace implementation code.
    # Allows to inject arbitrary lexical-local values to external fns.
    @considering TFormular: BoxFormular
    @reconfigure TDialogue: Dialogue

    # Once the service has been successfully booted, this method is
    # going to set up all the necessary scaffolding for the service.
    # It means setting up all the required UIX widgets, binding it
    # all together and coupling with the service, adding a desigred
    # overall behavior. See method implementation for more details.
    # Pay attention, this method is only triggeted at a first boot.
    configureScaffolding: @onetimer "booted", ->
        disabler = -> selector().addClass "disabled"
        enabler = -> selector().removeClass "disabled"
        selector = => @dialogue.$.find ".positive.button"
        unload = (visual) -> visual.removeClass "loading"
        closer = => return @dialogue.$.find ".close.icon"
        clean = => this.formular.prestine(); disabler()
        @dialogue = new TDialogue $("body"), "mfs-dialogue"
        @dialogue.title @t "Please enter the following data"
        @tap this.dialogue, "positive" # tap positive event
        @tap this.dialogue, "negative" # tap negative event
        assert _.isObject @content = this.dialogue.content
        assert _.isObject @actions = this.dialogue.actions
        @formular = new TFormular @content, "mfs-formular"
        @configureFormular? disabler, enabler, this.formular
        this.actions.find(".positive").addClass("disabled")
        this.emit("configure-formular", disabler, enabler)
        @on "disconnect", -> unload $(".loading", @content)
        @on "negative", => closer().click(); clean()

    # This is the actual engine of the separate formular service.
    # Method gets invoked each time the user submits a form data.
    # It takes care of all the internal mechanics: download form
    # data, invokes the specially designated server provider with
    # this data, and then makes sense of the response provided by.
    # Please refer to the implementation for better understanding.
    confirmedSubmission: @awaiting "positive", ->
        assert this.formular.element.addClass "loading"
        assert _.isObject data = @formular.download yes
        w = @th "Please check the information you entered"
        s = @th "You have sucessfully submitted your data"
        invalid = "got invalid response from the provider"
        this.dataSubmission data, (success, values) =>
            this.formular.element.removeClass "loading"
            assert values and _.isObject(values), invalid
            lo = (k) => (value) => value[k] = @t value[k]
            pp = (k) => _.each _.filter(values, k), lo(k)
            pp "warning"; pp "error" # localize server msg
            @formular.upload values; @formular.messages w
            return undefined unless (success and values)
            this.emit "acknowledged", success, values # ok
            this.once "acknowledged", (success, values) =>
                iconical = "icon checkmark green massive ok"
                @paragraph = $ "<p>", class: "right aligned"
                @paragraph.text s.toString() # success note
                assert icon = $ "<i>", class: "#{iconical}"
                try this.actions.empty(); this.formular.hide()
                this.content.append icon, this.paragraph

    # This method is invoked once the `configure-formular` event is
    # fired on the service. This event means that a dialogue and the
    # formular are ready to be configured. This method sets a handy
    # sort of behavior, when `enter` key is pressed, it either sets
    # the focus to the next field or submits the form if it was last.
    # Please refer directly to the implementation for more guidance.
    configureKeyboard: @awaiting "configure-formular", ->
        pos = => return $ ".positive.button", @dialogue.$
        disabled = (element) => $(element).is ".disabled"
        proceed = => pb.click() unless disabled pb = pos()
        next = => return performFieldResolution arguments...
        textInputs = "input[type=text],input[type=password]"
        assert not _.isEmpty idc = @dialogue.id.toString()
        jwerty.key "enter", next, textInputs, "##{idc}"
        return performFieldResolution = (event, key) ->
            assert _.isObject target = try event.target
            sibling = $(target).parents(".field").next()
            assert input = sibling.find(textInputs)
            return proceed() unless sibling.is ".field"
            return proceed() unless sibling.length > 0
            return proceed() unless input.length > 0
            return input.focus() # set to next input
