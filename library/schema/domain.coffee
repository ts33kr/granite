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
events = require "eventemitter2"
colors = require "colors"
assert = require "assert"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"

# Create a new JSON schema document that adheres to the standard
# of JSON Schema Draft v4 by running the supplied builder that uses
# the provides DSL methods to build up the schema. This function
# returns a ready to use schema represented as an object. Please see
# http://json-schema.org/latest/json-schema-core.html for reference.
module.exports.schema = schema = (id, title, pointer) ->
    context = Object.create new Object
    context = _.extend context, module.exports
    noId = "no schema identification tag is given"
    noTitle = "no schema human readable name is given"
    context.$schema = "http://json-schema.org/draft-04/schema#"
    rematerialize = (obj) -> JSON.parse JSON.stringify obj
    assert _.isFunction(pointer), "got no valid schema pointer"
    assert _.isString(context.title = title), noTitle
    assert _.isString(context.id = id), noId
    return rematerialize pointer.apply context

# Create a reference to a JSON schema object within the context. The
# object is described in terms of key/value pairs, as they found by
# invoking the supplied pointer that should return plain object. This
# object should expose members that will be treated as properties. A
# member value should be a valid pointer to an arbitrary data type.
module.exports.object = object = (description, pointer=(->)) ->
    noPointer = "got no pointer to the object members"
    noDescription = "no description has been given"
    assert _.isString(description), noDescription
    assert _.isFunction(pointer), noPointer
    @description = description.toString()
    compiled = pointer.apply this, arguments
    props = @properties = Object.create this
    regex = @patternProperties = Object.create this
    isp = (k, p) -> _.isFunction(p) and not p.pattern?
    isr = (k, p) -> _.isFunction(p) and p.pattern is yes
    f = (k, p) => p.apply n = Object.create(@), arguments; n
    props[k] = f k, p for k, p of compiled when isp(k, p)
    regex[k] = f k, p for k, p of compiled when isr(k, p)
    @type = "object"; return this

# Create a reference to a JSON schema array that contains objects in
# it. This is pretty much the same as declaring an array with object
# pointer passed to it, so this is just a convenient shorthand to aid
# in writing less code. You should normally supply the pointer that
# points to object members. Please refer to `object` implementation
# for more information on the pointer and object creation routine.
module.exports.objects = objects = (description, pointer=(->)) ->
    noPointer = "got no pointer to array elements"
    noDescription = "no description has been given"
    addendum = "an array of items: #{description}"
    assert _.isString(description), noDescription
    assert _.isFunction(pointer), noPointer
    reference = -> @object description, pointer
    @array addendum, reference; return this

# Create a reference to a JSON schema array within the context. The
# array should be described it terms of items that it holds. These
# items will be retrieved by invoking the supplied pointer function.
# The array can point to primitive types as well as complex types.
# Please make sure the pointer actually points to some schema type.
module.exports.array = array = (description, pointer) ->
    noPointer = "got no pointer to array elements"
    noDescription = "no description has been given"
    assert _.isString(description), noDescription
    assert _.isFunction(pointer), noPointer
    items = Object.create this; @items = items
    @description = description.toString()
    pointer.apply items, arguments;
    @type = "array"; return this

# Modify the current name/value property as they found in JSON object
# to be treated as the pattern property, as specified in the schema
# draft v4. This modifier should only be applied within the context of
# an object, otherwise it does not make any sense, by the definition.
# Please be aware that the modifier is set on the value, not on key!
module.exports.pattern = pattern = (pointer) ->
    notPointer = "incorrect pointer for pattern"
    notObject = "pattern used outside of object"
    alreadyMarked = "pointer is already a pattern"
    assert not pointer.pattern?, alreadyMarked
    assert _.isFunction(pointer), notPointer
    assert @patternProperties?, notObject
    pointer.pattern = yes; return pointer

# Modify the pointer decorated with this method as a required member.
# This modifier may only be used inside of the JSON object as defined
# by the JSON schema draft v4. specification. Beware, this method does
# modify the context object, although is being applied to the pointer.
# This corresponds to the draft v4 as oppositve of the draft v3 spec.
module.exports.must = must = (pointer) -> (key) ->
    isObject = @properties? or patternProperties?
    assert _.isFunction(pointer), "incorrect pointer for must"
    assert _.isString(key), "invalid name of property: #{key}"
    assert isObject, "must can only be used on object"
    required = @required if _.has this, "required"
    @required = (required or []).concat key
    return pointer.apply this, arguments

# Modify the supplied JSON object reference to mark this object as
# strict. This means that if an object contains any other properties
# except for the explicitly declared ones, it will be invalid marked
# invalid, as specified according to JSON schema draft v4 standard.
# This applicable to a single object as well as an array of objects.
module.exports.strict = strict = (reference) ->
    invalidSubject = "subject is none of an object"
    subject = reference if reference.type is "object"
    subject = reference.items if reference.type is "array"
    assert reference.type is "object", invalidSubject
    assert _.isObject reference.properties
    assert _.isObject reference.patternProperties
    reference.additionalProperties = no; reference

# Create a reference to the JSON enumeration. An enumeration defines
# what values are valid for this data type. Everything else beyond
# those values are considered invalid. This version may take array
# of values as array object, which is useful for creating enums in
# a programatic fashion as well as collect the trailing arguments.
# Makes sure all values are plain strings anyway. Errors out if not.
module.exports.choose = choose = (description, values...) ->
    noValues = "all values must be primitive strings"
    noDescription = "no description has been given"
    values = head if _.isArray head = _.head values
    assert _.isArray(values), "values are not array"
    assert _.isString(description), noDescription
    assert _.all(values, _.isString), noValues
    @description = description.toString()
    @enum = values; return this

# Create a reference to a JSON schema number within the context. The
# number can optionally be followed by an object that contains some
# validation restrictions, as they are found in the JSON schema v4 or
# some other properties. This object can also be expressed as function
# that will be immediatelly invoked and should return a plain object.
module.exports.number = number = (description, props) ->
    noProps = "no valid properties object supplied"
    noDescription = "no description has been given"
    props = props.apply this if _.isFunction props
    assert _.isString(description), noDescription
    props ?= {}; assert _.isObject(props), noProps
    @description = description.toString()
    @type = "number"; _.extend this, props; @

# Create a reference to a JSON schema string within the context. The
# string can optionally be followed by an object that contains some
# validation restrictions, as they are found in the JSON schema v4 or
# some other properties. This object can also be expressed as function
# that will be immediatelly invoked and should return a plain object.
module.exports.string = string = (description, props) ->
    noProps = "no valid properties object supplied"
    noDescription = "no description has been given"
    props = props.apply this if _.isFunction props
    assert _.isString(description), noDescription
    props ?= {}; assert _.isObject(props), noProps
    @description = description.toString()
    @type = "string"; _.extend this, props; @
