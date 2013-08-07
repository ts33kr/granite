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
events = require "events"
colors = require "colors"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"

# A fancy method for dynamically changing the inheritance chain of
# the existing classes. This method rebases the current class to
# use the supplied base class as its direct ancestor. The supplied
# class must conform to the basic class requirements, such as have
# a valid __super__ descriptor, among some other prototypal things.
Object.defineProperty Object::, "rebased",
    enumerable: no, value: (baseclass) ->
        isClass = _.isObject baseclass.__super__
        noClass = "The argument is not a class"
        throw new Error noClass unless isClass
        _.extend r = receiver = this, baseclass
        `function ctor() {this.constructor = r}`
        ctor.prototype = baseclass.prototype
        this.__super__ = baseclass.prototype
        this.prototype = new ctor(); this

# Scan the supplied class and return an entire inheritance hierarchy
# of classes. The hierarchy is represented as an array of prototypes
# that follow in the order they appear in the chain: starting from
# the supplied class and up to the top. The class has to be a valid
# CoffeeScript class that posses all the necessary internal members.
Object.defineProperty Object::, "hierarchy",
    enumerable: no, value: ->
        [chaining, subject] = [new Array, @]
        isClass = _.isObject subject.__super__
        noClass = "The subject is not a class"
        throw new Error noClass unless isClass
        while subject? and subject isnt null
            subject = subject.__super__
            constructor = subject?.constructor
            validates = _.isFunction constructor
            continue unless validates
            chaining.push constructor
            subject = constructor
        return chaining or []

# A complicated piece of functionality for merging arbitrary classes
# into the linear hierarchical inheritance chain of existing class.
# This method integrated the supplied compound class in the tear in
# between the foreign and common peers in the inheritance chain. Do
# refer to the implementation for the understanding of what happens.
Object.defineProperty Object::, "compose",
    enumerable: no, value: (compound) ->
        current = this.hierarchy()
        foreign = compound.hierarchy()
        identity = compound.name or compound.nick
        duplicate = "Duplicate #{identity} compound"
        throw new Error duplicate if compound in current
        orphan = (shape) -> shape not in commons
        commons = _.intersection current, foreign
        orphans = "No common base classes in hierarchy"
        throw new Error orphans if _.isEmpty commons
        duplicate = (parent) -> class extends parent
        differentiated = _.take current, orphan
        alternative = _.map differentiated, duplicate
        tails = alternative.pop().rebased compound
        rebased = (acc, cls) -> cls.rebased acc; cls
        @rebased _.foldr alternative, rebased, tails
