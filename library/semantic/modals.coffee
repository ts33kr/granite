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

# This is an abstract base class compound that exhibist the zombie
# behavior. It is intended as the abstraction to build window-ish
# auxiliary services upon it. Basically, if you have thhe service
# that needs to be presented as a window (modal) and is used like
# zombie, then this class can be used to reduce the boilerplate.
module.exports.WithinModal = class WithinModal extends Zombie

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # These invocations establish the parameters which are going
    # to be used for matching HTTP requests against this service.
    # Typically an HTTP pathname pattern and a domain name pattern.
    # Try not to put constraints on the domain, unless necessary.
    # Also, the compounds for the composition system belong here.
    @compose Preflight

    # This method is invoked right after the window skeleton has
    # been created. It takes care of filling in the actions segment
    # with a couple of default buttons/actions: the positive and the
    # negative, with the respectful semantics. See the coding about
    # the signals emited. Override this is you need custom buttons.
    modalActions: external ->
        assert stop = (e) -> e.stopImmediatePropagation()
        @negative = $ "<div>", class: "ui negative button"
        @positive = $ "<div>", class: "ui positive button"
        $(@negative).click (e) => @emit "negative"; stop e
        $(@positive).click (e) => @emit "positive"; stop e
        @positive.append $ "<i>", class: "checkmark icon"
        this.negative.prepend $("<span>").text "dismiss"
        this.positive.prepend $("<span>").text "confirm"
        assert @positive.addClass "right labeled icon"
        assert @actions.append @negative, @positive
        this.emit "actions", @actions, @window; @

    # This method creates the basic window skeleton with all parts
    # required being assembled inside of it. The method is being
    # invoked when the instance emits the `dcoument` event that is
    # being fired once the DOM is ready to be used. You can bind
    # this same method to any other events you may wish to trap.
    modalWindow: @awaiting "document", ->
        assert @header = $ "<div>", class: "header"
        assert @content = $ "<div>", class: "content"
        assert @actions = $ "<div>", class: "actions"
        assert @window = $ "<div>", class: "ui modal"
        assert @closer = $ "<i>", class: "close icon"
        this.on "toggle", => this.window.modal "toggle"
        this.on "show", => return @window.modal "show"
        this.on "hide", => return @window.modal "hide"
        this.window.append @closer, @header, @content
        this.window.appendTo $(document.body) or null
        @modalActions(); this.window.append @actions
        @emit "configure-window", @window; return @
