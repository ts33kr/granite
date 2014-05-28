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
{EOL} = require "os"

asciify = require "asciify"
connect = require "connect"
logger = require "winston"
events = require "eventemitter2"
assert = require "assert"
colors = require "colors"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"

# The decorator style of routine that is used to capture the
# source code of classes, functions and the other first class
# citizens for later transportation on the other environment.
# Typically this would be the browser JS engine environment.
# Call it with an empty function argument wrapping target.
module.exports.remote = module.exports.cc = (wrapper) ->
    noWrapper = "wrapper must be a function"
    invalidArgs = "wrapper cannot have arguments"
    assert _.isFunction(wrapper), noWrapper
    assert wrapper.length is 0, invalidArgs
    try compiled = wrapper() catch error
        message = error.message.toString()
        msg = "compilation failed: #{message}"
        error.message = "#{msg}"; throw error
    assert compiled.remote = Object.create {}
    assert compiled.remote.compiled = compiled
    assert compiled.remote.compile = compiler
    assert compiled.remote.source = wrapper
    assert compiled.remote.meta ?= Object()
    compiled.remote.symbol = compiled.name
    assert _.isFunction compiled; compiled

# A handy shortcut for the `remote` decorator that can be used with
# pure functions (not classes) to avoid having the top level, zero
# arguments functional closure over the compiled routines that is
# only necessary for properly capturing classes. Please refer to
# the `remote` method for info, since it is relevant here as well.
module.exports.external = module.exports.ec = (compiled) ->
    notFunction = "a compiled is not a function"
    wrongCompiled = "using external with classes"
    assert.ok _.isFunction(compiled), notFunction
    assert not compiled.__super__?, wrongCompiled
    p = (ds) -> ("var #{k} = #{v}" for k, v in ds)
    tabled = (d) -> _.sprintf wrapper, p(d).join ";\n"
    wrapper = "function() { %s; return #{compiled}}"
    assert compiled.remote = Object.create {}
    assert compiled.remote.compiled = compiled
    assert compiled.remote.compile = compiler
    assert compiled.remote.source = tabled {}
    assert compiled.remote.tabled = tabled
    assert compiled.remote.meta ?= Object()
    compiled.remote.symbol = compiled.name
    assert _.isFunction compiled; compiled

# An internal method that will be bolted on the remote objects.
# Knows how to compile the citizens to be transferred onto the
# foreign environments under the specified or inherited symbol.
# Please refer to the implementation for greater understanding!
# The method knows how to recursively compile class hierarchies.
compiler = module.exports.compiler = (caching, symbol) ->
    noSymbol = "a symbol must be non empty"
    @symbol = symbol unless _.isEmpty symbol
    assert not _.isEmpty(@symbol), noSymbol
    return new String if @symbol of caching
    f = => "var #{@symbol} = (#{@source})()"
    return f() unless _.isObject @compiled
    hierarchy = try @compiled.hierarchy?()
    assert _.isArray(hierarchy), "no hierarchy"
    hasRemote = (val) -> _.isObject val.remote
    compilation = (x) -> x.remote.compile caching
    areRemote = _.filter hierarchy, hasRemote
    compiled = _.map areRemote, compilation
    bases = compiled.reverse().join EOL + EOL
    assembled = "#{bases}#{EOL + EOL}#{f()}"
    return caching[@symbol] = assembled
