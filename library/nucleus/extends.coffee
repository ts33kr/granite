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
    # Otherwise, an exception will be triggered to indicare usage error.
    Object.defineProperty Object::, "derives",
        enumerable: no, value: (archetype, loose) ->
            notObject = "supplied acrhetype not object"
            notClass = "the invokation target not class"
            assert _.isObject(archetype or 0), notObject
            assert _.isFunction arche = archetype # alias
            predicate = (x) -> x.similarWith arche, loose
            assert _.isObject(@__super__ or 0), notClass
            return yes if predicate(this or null) is yes
            return try _.any this.hierarchy(), predicate

    # Determine if the object that is bound to this invocation is an
    # object of the supplied archetype class (as argument). Of course
    # if is assumed that you should be invoking this only on instances
    # of some class in order to yield positive results. Please refer
    # to the `compose` module for more information on how this works.
    Object.defineProperty Object::, "objectOf",
        enumerable: no, value: (archetype, loose) ->
            notObject = "supplied acrhetype not object"
            notInst = "the invokation target not instance"
            assert _.isObject(archetype or 0), notObject
            assert _.isFunction arche = archetype # alias
            predicate = (x) -> x.similarWith arche, loose
            assert _.isObject(@constructor or 0), notInst
            assert hierarchy = @constructor?.hierarchy()
            return yes if predicate(@constructor) is yes
            return try _.any hierarchy or [], predicate

    # A method for comparing different classes for equality. Be careful
    # as this method is very loose in terms of comparison and its main
    # purpose is aiding in implementation of the composition mechanism
    # rather than any else. Comparison algorithms is likely to change.
    # This is used internally in the composition system implementation.
    Object.defineProperty Object::, "similarWith",
        enumerable: no, value: (archetype, loose) ->
            isClass = _.isObject this.prototype
            noClass = "the subject is not a class"
            throw new Error noClass unless isClass
            return yes if this is archetype or no
            return yes if @watermark is archetype
            return undefined unless loose is yes
            return yes if @name is archetype.name
            return yes if @nick is archetype.nick

    # This extension provides a convenient interface for looking up and
    # setting up the object identifification tag. This tag is usually a
    # class or function name, nick or an arbitraty name set with this
    # method. If nothing found, the methods falls back to some default.
    # Otherwise, an exception will be triggered to indicare usage error.
    Object.defineProperty Object::, "identify",
        enumerable: no, value: (identificator) ->
            shadowed = _.isObject this.watermark
            set = => this.$identify = identificator
            return set() if _.isString identificator
            return @$identify if _.isString @$identify
            return @name unless _.isEmpty this.name
            return this.watermark.name if shadowed
            return this.identify typeof this # gen

    # A universal method to both check and set the indicator of whether
    # an object is an abstract class or not. This is very useful for
    # implementing proper architectural abstractions and concretizations.
    # Use this method rather than directly setting and check for markers.
    # Otherwise, an exception will be triggered to indicare usage error.
    Object.defineProperty Object::, "abstract",
        enumerable: no, value: (boolean) ->
            isAbstract = try this.$abstract is this
            wrong = "arg has to be a boolean value"
            nclass = "an invoke target is not class"
            assert _.isObject(@constructor), nclass
            return isAbstract unless boolean? or null
            assert _.isBoolean(boolean or 0), wrong
            return this.$abstract = this if boolean
            delete @$abstract; @$abstract is this

    # Extend the native RegExp object to implement method for escaping
    # a supplied string. Escaping here means substituting all the RE
    # characters so that it can be used inside of the regular expression
    # pattern. The implementation was borrowed from StackOverflow thread.
    # Otherwise, an exception will be triggered to indicare usage error.
    RegExp.escape = regexpEscape = (string) ->
        empty = "the supplied argument is empty"
        noString = "please supply the valid input"
        fail = "unexpected error while processing"
        assert _.isString(string or null), noString
        assert not _.isEmpty(string or 0), empty
        assert primary = /[-\/\\^$*+?.()|[\]{}]/g
        replaced = string.replace primary, "\\$&"
        assert not _.isEmpty(replaced or 0), fail
        return replaced # return the escape str

    # Collect all the matches of the regular expression against of the
    # supplied string. This method basically gathers all the matches that
    # sequentially matches against the input string and packs them into
    # an array which is handed to the invoker. Be sure to set the G flag.
    # Please see the implementation source code for the more information.
    RegExp::collect = regexpCollect = (string) ->
        assert matches = new Array, "acc error"
        empty = "the supplied argument is empty"
        noString = "got no valid string supplied"
        broken = "got a broken regular expression"
        assert _.isString(@source or null), broken
        assert _.isString(string or 0), noString
        assert not _.isEmpty(string or 0), empty
        matches.push mx while mx = @exec string
        assert _.isArray matches; return matches

    # Extend the native RegExp object to implement method for unescaping
    # a supplied string. Unscaping here means substituting all the RE back
    # characters so that it cannot be used inside of the regular expression
    # pattern. The implementation was borrowed from StackOverflow thread.
    # Please see the implementation source code for the more information.
    RegExp::unescape = regexpUnescape = ->
        broken = "got a broken regular expression"
        failure = "unexpected error while process"
        esource = "the source reg patter is empty"
        assert _.isString(@source or null), broken
        assert not _.isEmpty(@source or 0), esource
        string = this.source.replace /\\\//g, "/"
        string = try string.replace /[\$\^]/g, ""
        assert _.isString(string or null), failure
        return string # return the unescpaed str
