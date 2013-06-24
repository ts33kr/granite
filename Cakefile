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

logger = require "winston"
{spawn} = require "child_process"

# Here lies is the definition of the options required for some of
# the tasks defined in this Cakefile. Remember that the scope of
# definition of the options is global to a Cakefile, therefore the
# options are shared among all of the tasks and the entire file!
option "-l", "--library", "Path to the library sources"
option "-a", "--artifact", "Path to the artifact directory"
option "-d", "--documents", "Path to the documents directory"
option "-g", "--git-hub-pages", "Publish documents to GitHub pages"

# This is one of the major tasks in this Cakefile, it implements
# the generation of the documentation for the library, using the
# Groc documentation tool. The Groc depends on Pygments being set
# in place, before running. Takes some minor options via CLI call.
task "documents", "generate the library documentation", (options) ->
    library = options.library or "library"
    documents = options.documents or "documents"
    [pattern, index] = ["#{library}/**/*.coffee", "README.md"]
    parameters = [pattern, "Cakefile", index, "-o", documents]
    parameters.push("--github") if g = "git-hub-pages" of options
    logger.info("Publishing docs to GitHub pages".yellow) if g
    generator = spawn "groc", parameters
    generator.stdout.pipe(process.stdout)
    generator.stderr.pipe(process.stderr)
    generator.on "exit", (status) ->
        failure = "Failed to generate documentation".red
        success = "Generated documentation successfuly".green
        logger.error(failure) if status isnt 0
        logger.info(success) if status is 0

# This is one of the major tasks in this Cakefile, it implements
# the compilatation of the library source code from CoffeeScript
# to JavaScript, taking into account the supplied options or the
# assumed defaults if the options are not supplied via CLI call.
task "compile", "compile CoffeeScript into JavaScript", (options) ->
    library = options.library or "library"
    artifact = options.artifact or "artifact"
    parameters = ["-c", "-o", artifact, library]
    compiler = spawn "coffee", parameters
    compiler.stdout.pipe(process.stdout)
    compiler.stderr.pipe(process.stderr)
    compiler.on "exit", (status) ->
        failure = "Failed to compile library".red
        success = "Compiled library successfuly".green
        logger.error(failure) if status isnt 0
        logger.info(success) if status is 0
