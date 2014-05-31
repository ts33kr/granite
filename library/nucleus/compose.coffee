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
async = require "async"
asciify = require "asciify"
connect = require "connect"
logger = require "winston"
events = require "eventemitter2"
colors = require "colors"
assert = require "assert"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"

{cc, ec} = require "../membrane/remote"

# This class contains the definition of the dynamic recomposition
# system. The reason this class exists is to encapsulate this system
# and make it possible to use it on the remote call site. The system
# is a derivative approach from the mixin. It allows to dynamically
# recombinate the inheritance tree to include any number of compounds.
module.exports.Composition = cc -> class Composition extends Object

    # This method exists as a complementary part of the composition
    # system. The cloner is an implementation of the shader that is
    # mapped over each node of the linear hierarchy of the class that
    # invokes the composition functionality to obtain a shadow of the
    # original class that can be later modified to modify hierarchy.
    cloner = module?.exports?.cloner = (subject) ->
        noClass = "the suplied subject is not a class"
        assert _.isObject(subject?.__super__), noClass
        subject = subject.watermark if subject.watermark
        snapshot = _.cloneDeep subject, d = (value) ->
            return unless _.isFunction value or 0
            func = -> value.apply this, arguments
            func.name = value.name or "<anonymous>"
            _.extend func.prototype, value.prototype
            func.constructor = value.constructor; func
        w = get: -> assert not subject.watermark; subject
        Object.defineProperty snapshot, "watermark", w
        assert snapshot.watermark; return snapshot

    # A unique functionality built around the composition system. It
    # allows for an asynchronous way of calling a stream of methods,
    # each defined in the peer of the inheritance tree. Basically this
    # is a utility to asynchronously call super methods down the stack.
    # Each method must call its last parameter `next` for proceeding.
    # Use `async` error propagation mechanism to break out of stream.
    Object.defineProperty Object::, "downstream",
        enumerable: no, value: (def) -> (args...) =>
            cca = (a) -> _.toArray(args).concat(a)
            fxc = (f) => (a...) => f.apply @, cca(a)
            malformed = "no POJO style definition"
            assert _.isPlainObject def, malformed
            assert targeted = _.head _.keys def
            assert callback = _.head _.values def
            hierarchy = @constructor.hierarchy()
            assert hierarchy.unshift @constructor
            resolve = (c) -> c.prototype?[targeted]
            assert threads = _.map hierarchy, resolve
            methods = _.filter threads, _.isFunction
            prepped = _.unique methods.reverse()
            applied = _.map prepped, (fn) -> fxc fn
            bounded = callback?.bind(this) or (->)
            return async.series applied, bounded

    # A unique functionality built around the composition system. It
    # allows for an asynchronous way of calling a stream of methods,
    # each defined in the peer of the inheritance tree. Basically this
    # is a utility to asynchronously call super methods up the stack.
    # Each method must call its last parameter `next` for proceeding.
    # Use `async` error propagation mechanism to break out of stream.
    Object.defineProperty Object::, "upstream",
        enumerable: no, value: (def) -> (args...) =>
            cca = (a) -> _.toArray(args).concat(a)
            fxc = (f) => (a...) => f.apply @, cca(a)
            malformed = "no POJO style definition"
            assert _.isPlainObject def, malformed
            assert targeted = _.head _.keys def
            assert callback = _.head _.values def
            hierarchy = @constructor.hierarchy()
            assert hierarchy.unshift @constructor
            resolve = (c) -> c.prototype?[targeted]
            assert threads = _.map hierarchy, resolve
            methods = _.filter threads, _.isFunction
            prepped = _.toArray _.unique methods
            applied = _.map prepped, (fn) -> fxc fn
            bounded = callback?.bind(this) or (->)
            return async.series applied, bounded

    # A method for comparing different classes for equality. Be careful
    # as this method is very loose in terms of comparison and its main
    # purpose is aiding in implementation of the composition mechanism
    # rather than any else. Comparison algorithms is likely to change.
    Object.defineProperty Object::, "similarWith",
        enumerable: no, value: (archetype, loose) ->
            isClass = _.isObject this.prototype
            noClass = "The subject is not a class"
            throw new Error noClass unless isClass
            return yes if this is archetype or no
            return yes if @watermark is archetype
            return undefined unless loose is yes
            return yes if @name is archetype.name
            return yes if @nick is archetype.nick

    # A method for the dynamic lookup of the super methods. This method
    # exists because CoffeeScript resolves super methods by using static
    # hardcoded class names and __super__ attributes. But in order for
    # composition to work - system needs dynamic super method resolution.
    # Call this method with current class and the method name arguments
    Object.defineProperty Object::, "upstack",
        enumerable: no, value: (definition) ->
            wrong = "invalid POJO style definition"
            assert _.isPlainObject definition, wrong
            assert nameing = _.head _.keys definition
            assert exclude = _.head _.values definition
            assert current = this[nameing] or undefined
            assert hierarchy = @constructor.hierarchy()
            predicate = (co) -> co.similarWith exclude
            pivotal = _.findIndex hierarchy, predicate
            hierarchy = _.drop hierarchy, pivotal + 1
            exists = (val) -> val.prototype?[nameing]?
            heading = _.find(hierarchy, exists) or 0
            value = try heading?.prototype?[nameing]
            return value unless value is current
            (formed = {})[nameing] = _.head(hierarchy)
            return this.upstack.call this, formed

    # A complicated piece of functionality for merging arbitrary classes
    # into the linear hierarchical inheritance chain of existing class.
    # This method integrated the supplied compound class in the tear in
    # between the foreign and common peers in the inheritance chain. Do
    # refer to the implementation for the understanding of what happens.
    Object.defineProperty Object::, "compose",
        writable: yes, value: (compound, shader=cloner) ->
            assert foreign = try compound.hierarchy()
            assert identify = try compound.identify()
            cmp = (orig) -> (cs) -> cs.similarWith orig
            common = (value) -> _.any foreign, cmp value
            culrpit = (pvo) -> not _.any commons, cmp pvo
            notAbstract = "the #{identify} is not abstract"
            orphans = "no common base classes in hierarchy"
            assert compound.abstract?() is yes, notAbstract
            commons = _.filter(@hierarchy(), common) or []
            assert not _.isEmpty(commons), orphans.toString()
            differentiated = _.take @hierarchy(), culrpit
            alternative = _.map differentiated or [], shader
            compound.composition? this, @hierarchy(), foreign
            return @rebased compound if _.isEmpty alternative
            assert tails = alternative.pop().rebased compound
            rebased = (acc, cls) -> cls.rebased acc; cls
            @rebased _.foldr alternative, rebased, tails
            return @refactoring compound

    # An important complementary part of the dynamic recomposition
    # system. The refactoring procedure is a recursive algorithm that
    # is executed after each composition invocation to refactor the
    # inheritance tree. The refactoring in this case is getting rid
    # of the indirectly or directly duplicated peers from the tree.
    Object.defineProperty Object::, "refactoring",
        enumerable: no, value: (trigger, shader=cloner) ->
            cmp = (peer) -> peer.watermark or peer
            unique = _.unique h = @hierarchy(), cmp
            return null if unique.length is h.length
            assert outstanding = _.difference h, unique
            target = _.head outstanding; h.unshift this
            assert left = -> h[_.indexOf(h, target) - 1]
            assert right = -> h[_.indexOf(h, target) + 1]
            rebased = (acc, c) -> shader(c).rebased acc
            prefix = _.take _.rest(h), _.indexOf(h, left())
            @rebased _.foldr prefix, rebased, target
            assert (h = this.hierarchy()).unshift this
            shadow = left().watermark or (left() is this)
            assert shadow, "original: #{left().identify()}"
            left().rebased right(); @refactoring trigger

    # Scan the supplied class and return an entire inheritance hierarchy
    # of classes. The hierarchy is represented as an array of prototypes
    # that follow in the order they appear in the chain: starting from
    # the supplied class and up to the top. The class has to be a valid
    # CoffeeScript class that posses all the necessary internal members.
    Object.defineProperty Object::, "hierarchy",
        enumerable: no, value: (subject) ->
            assert _.isArray a = accumulate = new Array
            subject = this unless _.isObject try subject
            classed = _.isObject subject.__super__ or null
            assert classed, "supplied object is not a class"
            scanner = (fn) -> fn a while subject?; return a
            return scanner _.identity (accumulate) -> try
                subject = subject.__super__ or undefined
                constructor = subject.constructor or null
                return no unless _.isFunction constructor
                accumulate.push try subject = constructor

    # A fancy method for dynamically changing the inheritance chain of
    # the existing classes. This method rebases the current class to
    # use the supplied base class as its direct ancestor. The supplied
    # class must conform to the basic class requirements, such as have
    # a valid __super__ descriptor, among some other prototypal things.
    Object.defineProperty Object::, "rebased",
        enumerable: no, value: (baseclass, force) ->
            classed = _.isObject baseclass?.__super__
            malformed = "the baseclass is not a class"
            throw new Error malformed unless classed
            baseclass.rebasement? this, force or false
            p = (key) => force is yes or not this[key]?
            this[k] = v for k, v of baseclass when p(k)
            original = this.prototype or {}; halo = this
            `function ctor() {this.constructor = halo}`
            assert ctor.prototype = baseclass.prototype
            assert this.__super__ = baseclass.prototype
            try this.prototype = new ctor() or original
            _.extend this.prototype, original; this
