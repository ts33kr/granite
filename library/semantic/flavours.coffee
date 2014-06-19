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

{Preflight} = require "../membrane/preflight"
{GoogleFonts} = require "../exposure/fonting"

# This is an abstract compound that is intended for the services to
# be composed in. It customizes a hosting service to include all the
# prerequisites necessary to properly make usage of the Semantic UI
# frontend framework that are shipped within the primary framework.
# This frontend scaffolding is used to style the provided components.
assert module.exports.Semantic = class Semantic extends Preflight

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
    @implanting GoogleFonts

    # This block defines a set of fonts that are used throughout the
    # site. The fonts are employed by the means of the external CSS
    # stylesheet. However, the fonts are requested, downloaded and
    # setup with help of Google Fonts API and a corresponding class
    # that implement the functionality, which is the `GoogleFonts`.
    @googlefont "Open Sans Condensed", "300italic", 300, 400, 700
    @googlefont "Source Sans Pro", "300italic", 300, 400, 700
    @googlefont "Open Sans", "300italic", 300, 400, 700

    # This block here defines a set of assets, such as CSS styles
    # or JavaScript files that will be included on every context
    # emited by the service that composes this abstract base class
    # in. Remember that these links are as they will appear on the
    # client browser, unless some else, overriding options are set.
    @javascript "javascript/semantic.min.js"
    @stylesheet "css/semantic.min.css"
    @stylesheet "css/semantic.uix.css"

    # This block define a set of meta tags that specify or tweak
    # the way a client browser treats the content that it has got
    # from the server site. Please refer to the HTML5 specification
    # for more information on the exact semantics of any meta tag.
    # Reference the `Preflight` for the implementation guidance.
    @metatag charset: "utf-8"
