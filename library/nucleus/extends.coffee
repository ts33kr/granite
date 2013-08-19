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
events = require "events"
assert = require "assert"
colors = require "colors"
nconf = require "nconf"
https = require "https"
paths = require "path"
http = require "http"
util = require "util"
fs = require "fs"

# This extension provides a convenient interface for looking up and
# setting up the object identifification tag. This tag is usually a
# class or function name, nick or an arbitraty name set with this
# method. If nothing found, the methods falls back to some default.
Object.defineProperty Object::, "identify",
    enumerable: no, value: (identificator) ->
        set = => @$identify = identificator
        return set() if _.isString identificator
        return @$identify if _.isString @$identify
        return @nick if _.isString @nick
        return @name if _.isString @name
        return @identify typeof this

# This method is a stub that must be called in the abstract methods
# who do not have any implementation. When called, this method will
# spit out the relevant error about the caller method. It would say
# that the method is abstract and has no implementation attached to.
Object.defineProperty Object::, "unimplemented",
    enumerable: no, value: (archarguments) ->
        stack = strace.get arguments.callee
        caller = _.head stack or undefined
        identification = caller.getMethodName()
        naming = "abstract method #{identification}"
        throw new Error "#{naming} is not implemented"

# A universal method to both check and set the indicator of whether
# an object is an abstract class or not. This is very useful for
# implementing proper architectural abstractions and concretizations.
# Use this method rather than directly setting and check for markers.
Object.defineProperty Object::, "abstract",
    enumerable: no, value: (boolean) ->
        isAbstract = @$abstract is this
        return isAbstract unless boolean?
        return @$abstract = this if boolean
        delete @$abstract; @$abstract is @

# Determine if the object that is bound to this invocation is a
# subclass of the supplied archetype class (as argument). Of course
# it is assumed that you should be invoking this method only on the
# objects that are valid CoffeeSscript classes with necessary attrs.
Object.defineProperty Object::, "inherits",
    enumerable: no, value: (archetype) ->
        notObject = "acrhetype is not object"
        assert _.isObject archetype, notObject
        predicate = (x) -> x is archetype
        assert @__super__, "not a class"
        _.any @hierarchy(), predicate

# Determine if the object that is bound to this invocation is an
# object of the supplied archetype class (as argument). Of course
# if is assumed that you should be invoking this only on instances
# of some class in order to yield positive results. Please refer
# to the `compose` module for more information on how this works.
Object.defineProperty Object::, "objectOf",
    enumerable: no, value: (archetype) ->
        notObject = "acrhetype is not object"
        assert _.isObject archetype, notObject
        predicate = (x) -> x is archetype
        hierarchy = @constructor?.hierarchy()
        _.any hierarchy or [], predicate

# Extend the native RegExp object to implement method for escaping
# a supplied string. Escaping here means substituting all the RE
# characters so that it can be used inside of the regular expression
# pattern. The implementation was borrowed from StackOverflow thread.
RegExp.escape = (string) ->
    primary = /[-\/\\^$*+?.()|[\]{}]/g
    string.replace primary, "\\$&"

# Extend the native RegExp object to implement method for unescaping
# a supplied string. Unscaping here means substituting all the RE back
# characters so that it cannot be used inside of the regular expression
# pattern. The implementation was borrowed from StackOverflow thread.
RegExp::unescape = ->
    string = @source.replace /\\\//g, "/"
    string.replace /[\$\^]/g, ""
