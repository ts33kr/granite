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
asciify = require "asciify"
connect = require "connect"
logger = require "winston"
uuid = require "node-uuid"
events = require "eventemitter2"
assert = require "assert"
colors = require "colors"
crypto = require "crypto"
teacup = require "teacup"
async = require "async"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"

{EOL} = require "os"
{format} = require "util"
{STATUS_CODES} = require "http"

{Barebones} = require "../membrane/skeleton"
{remote, external} = require "../membrane/remote"
{coffee} = require "../membrane/runtime"

# This is an internal abstract base class that is not intended for
# being used directly. The class is being used by the implementation
# of framework sysrems to segregate the implementation of the visual
# core from the convenience API targeted to be used by a developers.
# Please refer to the `Screenplay` class for actual implementation.
# This can also contain non-developer internals of the visual core.
module.exports.TemplateToolkit = class TemplateToolkit extends Barebones

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # Use this static method to mark up the remote/external methods
    # that are really `Teacup` templates. This method takes care of
    # all the internal needs of such templates and transfers those
    # to the client site, saving their ability to become properly
    # rendered. Some additional options supported. See the coding.
    # Beware, this is essentially the same as defining external fn.
    @template: (xoptions, ximplement) ->
        assert identify = this.identify().underline
        invalidOptions = "found no options supplied"
        invalidImplement = "found no template function"
        message = "Defining the new Teacup template at %s"
        options = _.find(arguments, _.isPlainObject) or {}
        implement = _.find(arguments, _.isFunction) or 0
        assert _.isPlainObject(options), invalidOptions
        assert _.isFunction(implement), invalidImplement
        assert method = @autocall new Object, implement
        assert _.isObject bonds = method.remote.bonding
        bonds[key] = "teacup.#{key}" for key of teacup
        logger.silly message.grey, identify.toString()
        auto = (fn) -> method.remote.auto = fn; method
        return auto (symbol, key, context) -> _.once ->
            assert not _.isEmpty q = "#{symbol}.#{key}"
            s = "#{q}$teacup.apply(#{symbol}, arguments)"
            t = "#{q}$teacup = teacup.renderable(#{q})"
            f = "#{q} = function() { return $(#{s}); }"
            return format("%s; %s", t, f).toString()
