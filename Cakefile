# Copyright (c) 2013, Alexander Cherniuk <ts33kr@gmail.com>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

logger = require "winston"
{spawn} = require "child_process"

# Here lies is the definition of the options required for some of
# the tasks defined in this Cakefile. Remember that the scope of
# definition of the options is global to a Cakefile, therefore the
# options are shared among all of the tasks and the entire file.!
option "-l", "--library", "Path to the library sources"
option "-a", "--artifact", "Path to the artifact directory"

# This is one of the major tasks in this Cakefile, it implements
# the compilatation of the library source code from CoffeeScript
# to JavaScript, taking into account the supplied options or the
# assumed defaults if the options are not supplied via CLI call.
task "compile", "compile CoffeeScript into JavaScript", (options) ->
    input = options.library or "library"
    output = options.artifact or "artifact"
    options = ["-c", "-o", output, input]
    compiler = spawn "coffee", options
    compiler.stdout.pipe(process.stdout)
    compiler.stderr.pipe(process.stderr)
    compiler.on "exit", (status) ->
        failure = "Failed to compile".red
        success = "Successfuly compiled".green
        logger.info(success) if status is 0
        logger.error(failure) if status isnt 0
