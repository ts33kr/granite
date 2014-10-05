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
logger = require "winston"
teacup = require "teacup"
assert = require "assert"

{Widget} = require "./abstract"
{Archetype} = require "../nucleus/arche"
{remote, cc} = require "../membrane/remote"

# This abstract base class component will implement the coloring
# capabilities for every widget that implants this component. Do
# refer to the implementation code of this class for more info.
# It will add a set of methods, named after the defined colors.
# Please refer to the Semantic-UI documentation for reference.
# Also, check out the `colors` definition within this class.
module.exports.Coloring = cc -> class Coloring extends Widget

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # The vector of valid colors predefined by the Semantic-UI.
    # These definitions are used to install universal methods for
    # all the widgets that include this abstract base component.
    # Methods will be able to switch colors for every such widget.
    # Subwidgets inside of the widgets will be able to use it too.
    # Method names will be exactly the same as color names here.
    colors: ["green", "red", "blue", "orange", "purple", "teal"]

    # Enable or disable (toggle) the color inversion of widget.
    # This basically boils down to toggling an `inverted` class
    # on the element of the widget. Please refer to the docs of
    # the Semantic-UI toolkit for more information on this one.
    # This method will also be available in all the subwidgets.
    # It returns the self-reference to enable method chaining.
    inverse: -> @element.toggleClass "inverted"; return this

    # Installation procedure that configures and sets up the
    # coloring methods. Methods will be installed into usual
    # place - prototype, so they will be available just like
    # any normal methods. Please consult with the `colors`
    # definition and procedure coding for some more info.
    # Subwidgets will be automatically affected as well.
    _.each this::colors or Array(), (color, index, colors) =>
        invalid = "iterated over the invalid color value"
        unindex = "incorrect method invocation signature"
        cvector = "missing a vector with all the colors"
        message = "Infusing color method %s into %s class"
        assert _.isNumber(index), unindex # vector index
        assert _.isString(color or undefined), invalid
        assert _.isArray(colors or undefined), cvector
        assert _.isString identify = @identify?() or 0
        logger.silly message.rainbow, color, identify
        return @prototype[color] = (parameters...) ->
            malformed = "context binding is not widget"
            notify = "Setting up %s color to %s widget"
            assert _.isObject(this.element), malformed
            stream = colors.join " " # space-separated
            this.element.removeClass stream # clean up
            this.element.addClass try color.toString()
            logger.silly notify, color, this.reference
            return this # return self for the chaining
