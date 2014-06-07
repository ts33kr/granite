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
uuid = require "node-uuid"
strace = require "stack-trace"
asciify = require "asciify"
connect = require "connect"
logger = require "winston"
events = require "eventemitter2"
assert = require "assert"
colors = require "colors"
nconf = require "nconf"
https = require "https"
paths = require "path"
http = require "http"
util = require "util"
fs = require "fs"

{cc, ec} = require "../membrane/remote"

# This class encapsulates arbitrary definition that extend built in
# data types or similar to it. This is a small collection of the handy
# routines that are used throughout the code. These definitions are
# placed in this class in order to transfer it to the remote call site.
# Some of them depend on other subsystems, such as dynamic composition.
assert module.exports.Extending = cc -> class Extending extends Object

    # Determine if the object that is bound to this invocation is a
    # subclass of the supplied archetype class (as argument). Of course
    # it is assumed that you should be invoking this method only on the
    # objects that are valid CoffeeSscript classes with necessary attrs.
    Object.defineProperty Object::, "derives",
        enumerable: no, value: (archetype, loose) ->
            notObject = "supplied acrhetype is not object"
            assert _.isObject(archetype or null), notObject
            predicate = (x) -> x.similarWith archetype, loose
            assert _.isObject(@__super__), "this is not class"
            return yes if predicate(this or undefined) is yes
            return _.any this.hierarchy(), predicate

    # Determine if the object that is bound to this invocation is an
    # object of the supplied archetype class (as argument). Of course
    # if is assumed that you should be invoking this only on instances
    # of some class in order to yield positive results. Please refer
    # to the `compose` module for more information on how this works.
    Object.defineProperty Object::, "objectOf",
        enumerable: no, value: (archetype, loose) ->
            notObject = "supplied acrhetype is not object"
            assert _.isObject(archetype or null), notObject
            predicate = (x) -> x.similarWith archetype, loose
            assert hierarchy = @constructor?.hierarchy()
            return yes if predicate(@constructor) is yes
            return _.any hierarchy or [], predicate

    # This extension provides a convenient interface for looking up and
    # setting up the object identifification tag. This tag is usually a
    # class or function name, nick or an arbitraty name set with this
    # method. If nothing found, the methods falls back to some default.
    Object.defineProperty Object::, "identify",
        enumerable: no, value: (identificator) ->
            shadowed = _.isObject @watermark
            set = => @$identify = identificator
            return set() if _.isString identificator
            return @$identify if _.isString @$identify
            return @name unless _.isEmpty @name
            return @watermark.name if shadowed
            return @identify typeof this

    # A universal method to both check and set the indicator of whether
    # an object is an abstract class or not. This is very useful for
    # implementing proper architectural abstractions and concretizations.
    # Use this method rather than directly setting and check for markers.
    Object.defineProperty Object::, "abstract",
        enumerable: no, value: (boolean) ->
            isAbstract = @$abstract is this
            return isAbstract unless boolean?
            wrong = "has to be a boolean value"
            assert _.isBoolean(boolean), wrong
            return @$abstract = this if boolean
            delete @$abstract; @$abstract is @

    # Extend the native RegExp object to implement method for escaping
    # a supplied string. Escaping here means substituting all the RE
    # characters so that it can be used inside of the regular expression
    # pattern. The implementation was borrowed from StackOverflow thread.
    RegExp.escape = (string) ->
        noString = "please supply valid input"
        assert not _.isEmpty(string), noString
        primary = /[-\/\\^$*+?.()|[\]{}]/g
        string.replace primary, "\\$&"

    # Extend the native RegExp object to implement method for unescaping
    # a supplied string. Unscaping here means substituting all the RE back
    # characters so that it cannot be used inside of the regular expression
    # pattern. The implementation was borrowed from StackOverflow thread.
    RegExp::unescape = ->
        noString = "cannot retrieve RE source"
        assert not _.isEmpty(@source), noString
        string = @source.replace /\\\//g, "/"
        return string.replace /[\$\^]/g, ""

    # Collect all the matches of the regular expression against of the
    # supplied string. This method basically gathers all the matches that
    # sequentially matches against the input string and packs them into
    # an array which is handed to the invoker. Be sure to set the G flag.
    RegExp::collect = (string) ->
        matches = new Array undefined
        noString = "got no string supplied"
        assert _.isString(string), noString
        matches.push m while m = @exec string
        assert matches; return matches
