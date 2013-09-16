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
    context = Object.create {}
    context = _.extend context, module.exports
    noId = "no schema identification tag is given"
    noTitle = "no schema human readable name is given"
    context.$schema = "http://json-schema.org/draft-04/schema#"
    rematerialize = (obj) -> JSON.parse JSON.stringify obj
    assert _.isFunction(pointer), "got no valid schema pointer"
    assert _.isString(context.title = title), noTitle
    assert _.isString(context.id = id), noId
    return rematerialize pointer.apply(context)

# This defines one of the built in pointers. A pointer is a method
# defintion that provides an ability to specify (or point to) to a
# specific kind of data type. Pointers may create simple or complex
# data type references and definitions. Refer to their implementation.
# A modificator that marks objects as strict (no additional properties).
module.exports.strict = strict = (object) ->
    notObject = "applicable only for an object"
    assert object.type is "object", notObject
    object.additionalProperties = no; object

# This defines one of the built in pointers. A pointer is a method
# defintion that provides an ability to specify (or point to) to a
# specific kind of data type. Pointers may create simple or complex
# data type references and definitions. Refer to their implementation.
# A modificator that marks arrays as containting only unique items.
module.exports.unique = unique = (array) ->
    notArray = "applicable only for an array"
    assert array.type is "array", notArray
    array.uniqueItems = yes; return array

# This defines one of the built in pointers. A pointer is a method
# defintion that provides an ability to specify (or point to) to a
# specific kind of data type. Pointers may create simple or complex
# data type references and definitions. Refer to their implementation.
# A modificator that marks any array member/pointer as a mandatory.
module.exports.must = must = (p) -> (k, o) ->
    assert _.isFunction(p), "incorrect pointer for must"
    assert _.isString(k), "invalid name of property: #{k}"
    assert _.isObject(o), "internal error, no outer object"
    (o.required ?= []).push k; p.apply @, arguments

# This defines one of the built in pointers. A pointer is a method
# defintion that provides an ability to specify (or point to) to a
# specific kind of data type. Pointers may create simple or complex
# data type references and definitions. Refer to their implementation.
# This pointer creates a reference to object with composite pointer.
module.exports.object = object = (description, pointer) ->
    noPointer = "got no pointer to the object members"
    noCompiled = "content pointer must return object"
    noDescription = "no description has been given"
    assert _.isString(description), noDescription
    assert _.isFunction(pointer), noPointer
    compiled = pointer.apply this
    @properties = Object.create this
    @description = description.toString()
    assert _.isObject(compiled), noCompiled
    f = (k, p) => p.call n = Object.create(@), k, @; n
    @properties[key] = f key, p for key, p of compiled
    @type = "object"; return this

# This defines one of the built in pointers. A pointer is a method
# defintion that provides an ability to specify (or point to) to a
# specific kind of data type. Pointers may create simple or complex
# data type references and definitions. Refer to their implementation.
# This pointer creates a reference to an array of other pointers.
module.exports.array = array = (description, pointer) ->
    noPointer = "got no pointer to array elements"
    noDescription = "no description has been given"
    assert _.isString(description), noDescription
    assert _.isFunction(pointer), noPointer
    items = Object.create this; @items = items
    @description = description.toString()
    @type = "array"; pointer.apply items; @

# This defines one of the built in pointers. A pointer is a method
# defintion that provides an ability to specify (or point to) to a
# specific kind of data type. Pointers may create simple or complex
# data type references and definitions. Refer to their implementation.
# This pointer creates a reference to an number with optional props.
module.exports.number = number = (description, props) ->
    noProps = "no valid properties object supplied"
    noDescription = "no description has been given"
    assert _.isString(description), noDescription
    props ?= {}; assert _.isObject(props), noProps
    @description = description.toString()
    @type = "number"; _.extend this, props; @

# This defines one of the built in pointers. A pointer is a method
# defintion that provides an ability to specify (or point to) to a
# specific kind of data type. Pointers may create simple or complex
# data type references and definitions. Refer to their implementation.
# This pointer creates a reference to an string with optional props.
module.exports.string = string = (description, props) ->
    noProps = "no valid properties object supplied"
    noDescription = "no description has been given"
    assert _.isString(description), noDescription
    props ?= {}; assert _.isObject(props), noProps
    @description = description.toString()
    @type = "string"; _.extend this, props; @
