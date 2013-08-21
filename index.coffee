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
wrench = require "wrench"
colors = require "colors"
logger = require "winston"
paths = require "path"
fs = require "fs"

# This method is the base method for very important functionality.
# It scans the supplied directory, find all the modules there and
# return an object, where keys are names of modules minus the ext.
# This is used to build up entire module hierarchy of the framework.
collectModules = (directory, shallow) ->
    supported = [".coffee", ".js"]
    ext = (name) -> paths.extname name
    sym = (name) -> paths.basename name, ext name
    isSupported = (name) -> ext(name) in supported
    ingest = (x) -> require paths.resolve directory, x
    return {} unless fs.existsSync directory
    scanSync = wrench.readdirSyncRecursive
    scanSync = fs.readdirSync if shallow
    scanned = scanSync directory.toString()
    supported = _.filter scanned, isSupported
    modules = _.map supported, ingest
    symbols = _.map supported, sym
    _.object symbols, modules

# This method is the base method for very important functionality.
# It scans the supplied directory, find all the packages there and
# return an object, where keys are names of modules minus the ext.
# This is used to build up entire module hierarchy of the framework.
collectPackages = (closure, directory="library") ->
    stat = (p) -> fs.statSync fix p
    isDir = (p) -> stat(p).isDirectory()
    fix = (p) -> paths.join directory, p
    resolve = -> paths.resolve closure, directory
    directory = resolve() if _.isString closure
    nodes = fs.readdirSync directory.toString()
    directories = _.filter nodes, isDir
    scanner = (d) -> collectPackages closure, fix d
    symbols = _.map directories, paths.basename
    packages = _.map directories, scanner
    packages = _.object symbols, packages
    modules = collectModules directory, yes
    _.merge modules, packages

# Traverse the hierarchy of all cached modules and try find kernel
# class that the most deep hiererachy. That is the kernel that is a
# most derived from the original one. If no such kernel can be found
# then revert to returning the original kernel embedded in framework.
lookupCachedKernel = ->
    origin = module.exports.nucleus.kernel.Kernel
    assert _.isObject(origin), "no kernel origin"
    spaces = _.map require.cache, (x) -> x.exports
    hierarchy = (c) -> c.hierarchy().length
    isKernel = (x) -> try x.inherits? origin
    values = _.flatten _.map(spaces, _.values)
    objects = _.filter values, _.isObject
    kernels = _.filter objects, isKernel
    sorted = _.sortBy kernels, hierarchy
    return _.last(sorted) or origin

# Build up the entire module hierarchy of the framework. Please do
# refer to the `collectModules` method implementation for more
# information on how this is being done. See the modules in the
# framework library to see the structure of the built hieararchy.
module.exports = collectPackages __dirname
module.exports.collectModules = collectModules
module.exports.collectPackages = collectPackages
module.exports.lookupCachedKernel = lookupCachedKernel
