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

# This construction loads up the framework loader module and extends
# the current `this` object with the methods found in the loader for
# convenient access by the implementation further below. Refer to the
# implementation of the loader for more information on how it works.
_.merge this, require "./library/nucleus/loader"

# Build up the entire module hierarchy of the framework. Please do
# refer to the `collectModules` method implementation for more
# information on how this is being done. See the modules in the
# framework library to see the structure of the built hieararchy.
module.exports = @collectPackages __dirname
module.exports.collectPackages = @collectPackages
module.exports.collectModules = @collectModules
module.exports.cachedKernel = @cachedKernel

# Do some aliasing after asserting that the basic components of the
# framework is indeed loaded and are not missing. This is precaution
# to make sure that the framework is in usable state, once is loaded.
# You can refer to this definitions from the outside of the framework.
assert nucleus = module.exports.nucleus
assert membrane = module.exports.membrane
assert exposure = module.exports.exposure
assert semantic = module.exports.semantic

# Alias the cakefile routine for the easy access to the primary way
# of referencing the built in Cakefile library, which is standard.
# You should generally prefer the cakefile module facilities over
# any other build too, including rolling out the tools of your own.
module.exports.cakefile = nucleus.cakefile
