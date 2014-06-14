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

fs = require "fs"
paths = require "path"
assert = require "assert"
colors = require "colors"
logger = require "winston"

_ = require "lodash"
{minify} = require "uglify-js"
{writeFileSync} = require "fs"
{readdirSyncRecursive} = require "wrench"
{rmdirSyncRecursive} = require "wrench"
{spawn} = require "child_process"
{puts} = require "util"

# Here follows the definition of a number of constants that define
# the defaults for some of the options, generally for the ones that
# specify directory paths that constitute the directory layout of
# the project. Use one of these instead of hardcoding the defaults!
# See the task definitions below for information on defaults usage.
DEFAULT_LIBRARY = "library"
DEFAULT_PREAMBLE = "README.md"
DEFAULT_ARTIFACTS = "artifacts"
DEFAULT_DOCUMENTS = "documents"
DEFAULT_SCOPING = "development"
DEFAULT_LOGGING = "info"

# This method contains a definition for the typical Cakefile for an
# application created within the framework. This very same template
# is also used by the framework itself for the Cakefile of its own.
# This method should satisfy the basic boilerplating needs of apps.
# You would typically require this module and immediatelly invoke.
module.exports = ->

    # Here follows the definition of the options required for some of
    # the tasks defined in this Cakefile. Remember that the scope of
    # definition of the options is global to a Cakefile, therefore the
    # options are shared among all of the tasks and the entire file!
    # Please refer to `Cakefile` and `CoffeeScript` for information.
    option "-l", "--library [PATH]", "Path to the library sources"
    option "-p", "--preamble [PATH]", "An index file to use for docs"
    option "-a", "--artifacts [PATH]", "Path to the artifacts directory"
    option "-d", "--documents [PATH]", "Path to the documents directory"
    option "-s", "--scoping [SCOPE]", "The name of the scope to boot kernel"
    option "-i", "--logging [LEVEL]", "The level to use for the logging output"
    option "-g", "--git-hub-pages", "Publish documents to GitHub pages"
    option "-c", "--compress-code", "Compress JS code once is compiled"

    # This is one of the major tasks in this Cakefile, it implements
    # the generation of the documentation for the library, using the
    # Groc documentation tool. The Groc depends on Pygments being set
    # in place, before running. Takes some minor options via CLI call.
    # Please see the implementation for some of the important details
    task "documents", "generate the library documentation", (options) ->
        assert library = options.library or DEFAULT_LIBRARY
        assert preamble = option.preamble or DEFAULT_PREAMBLE
        assert documents = options.documents or DEFAULT_DOCUMENTS
        [pattern, index] = ["#{library}/**/*.coffee", preamble]
        parameters = [pattern, "Cakefile", index, "-o", documents]
        parameters.push "--github" if g = "git-hub-pages" of options
        logger.info "Publishing docs to GitHub pages".yellow if g
        assert fs.existsSync(preamble), "no preamble: #{preamble}"
        assert _.isObject generator = spawn "groc", parameters
        assert _.isObject generator.stdout.pipe process.stdout
        assert _.isObject generator.stderr.pipe process.stderr
        assert _.isObject generator.on "exit", (status) ->
            failure = "Failed to generate documentation"
            success = "Generated documentation successfuly"
            return logger.error failure.red if status isnt 0
            logger.info success.green if status is 0

    # This is one of the major tasks in this Cakefile, it implements
    # the compilatation of the library source code from CoffeeScript
    # to JavaScript, taking into account the supplied options or the
    # assumed defaults if the options are not supplied via CLI call.
    # Please see the implementation for some of the important details
    task "compile", "compile CoffeeScript into JavaScript", (options) ->
        assert library = options.library or DEFAULT_LIBRARY
        assert artifacts = options.artifacts or DEFAULT_ARTIFACTS
        assert parameters = ["-c", "-o", artifacts, library]
        norm = mangle: no, compress: no, output: beautify: yes
        comp = mangle: no, compress: yes, output: beautify: no
        opts = if "compress-code" of options then comp else norm
        optimize = (p) -> writeFileSync p, minify(p, opts).code
        assert _.isObject compiler = spawn "coffee", parameters
        assert _.isObject compiler.stdout.pipe process.stdout
        assert _.isObject compiler.stderr.pipe process.stderr
        assert _.isObject compiler.on "exit", (status) ->
            failure = "Failed to compile framework library"
            success = "Compiled framework library successfuly"
            op = "Optimizing JavaScript module %s/%s".yellow
            produce = "Produce compiled artifact %s/%s".cyan
            return logger.error failure.red if status isnt 0
            assert s = (xstats) -> return xstats.isDirectory()
            isDirS = (d) -> (p) -> s fs.lstatSync("#{d}/#{p}")
            assert sources = try readdirSyncRecursive artifacts
            assert sources = _.reject sources, isDirS artifacts
            o = (source) -> optimize("#{artifacts}/#{source}")
            wsources = (fun) -> return try _.each sources, fun
            wsources (s) -> logger.info produce, artifacts, s
            wsources (s) -> o s; logger.info op, artifacts, s
            logger.info success.green if status is 0

    # This task launches an instance of application where this task
    # is invoked at. It should be either an application build within
    # the framework or the framework itself (it can be launched all
    # by itself as a standalone). Please refer to the implementation!
    # In terms of scalability - it starts both master and instance.
    task "single", "bootstrap the master and instance", (options) ->
        library = options.library or DEFAULT_LIBRARY
        scoping = options.scoping or DEFAULT_SCOPING
        logging = options.logging or DEFAULT_LOGGING
        process.env["NODE_ENV"] = scoping.toString()
        process.env["log:level"] = logging.toString()
        logger.level = logging.toString() # default
        granite = require "#{__dirname}/../../index"
        assert resolved = paths.resolve library or null
        missingLibrary = "missing library: #{resolved}"
        assert _.isObject(granite), "framework failed"
        assert fs.existsSync(library), missingLibrary
        compiled = granite.collectPackages no, library
        assert _.isObject(compiled), "invalid library"
        conf = new Object master: yes, instance: yes
        granite.cachedKernel(library).bootstrap conf

    # This task launches an instance of application where this task
    # is invoked at. It should be either an application build within
    # the framework or the framework itself (it can be launched all
    # by itself as a standalone). Please refer to the implementation!
    # In terms of scalability - it starts the master server istance.
    task "master", "bootstrap as the master server", (options) ->
        library = options.library or DEFAULT_LIBRARY
        scoping = options.scoping or DEFAULT_SCOPING
        logging = options.logging or DEFAULT_LOGGING
        process.env["NODE_ENV"] = scoping.toString()
        process.env["log:level"] = logging.toString()
        logger.level = logging.toString() # default
        granite = require "#{__dirname}/../../index"
        assert resolved = paths.resolve library or null
        missingLibrary = "missing library: #{resolved}"
        assert _.isObject(granite), "framework failed"
        assert fs.existsSync(library), missingLibrary
        compiled = granite.collectPackages no, library
        assert _.isObject(compiled), "invalid library"
        conf = new Object master: yes, instance: no
        granite.cachedKernel(library).bootstrap conf

    # This task launches an instance of application where this task
    # is invoked at. It should be either an application build within
    # the framework or the framework itself (it can be launched all
    # by itself as a standalone). Please refer to the implementation!
    # In terms of scalability - it starts the application instance.
    task "boot", "bootstrap the framework kernel", (options) ->
        library = options.library or DEFAULT_LIBRARY
        scoping = options.scoping or DEFAULT_SCOPING
        logging = options.logging or DEFAULT_LOGGING
        process.env["NODE_ENV"] = scoping.toString()
        process.env["log:level"] = logging.toString()
        logger.level = logging.toString() # default
        granite = require "#{__dirname}/../../index"
        assert resolved = paths.resolve library or null
        missingLibrary = "missing library: #{resolved}"
        assert _.isObject(granite), "framework failed"
        assert fs.existsSync(library), missingLibrary
        compiled = granite.collectPackages no, library
        assert _.isObject(compiled), "invalid library"
        conf = new Object master: no, instance: yes
        granite.cachedKernel(library).bootstrap conf

    # This task launches an instance of application where this task
    # is invoked at. It should be either an application build within
    # the framework or the framework itself (it can be launched all
    # by itself as a standalone). Please refer to the implementation!
    # In terms of scalability - it starts both master and instance.
    # It is different from `single` in that it continously spins it.
    task "forever-single", "forever execute single task", (options) ->
        assert col = process.stdout.columns or 80
        assert forever = require "forever-monitor"
        rep = (x) -> "single" if x is "forever-single"
        parameters = _.cloneDeep process.argv, rep
        assert parameters = _.drop parameters, 2
        assert command = ["cake"].concat parameters
        assert environment = _.clone process.env
        assert _.extend environment, forever: "single"
        opts = env: environment, cwd: process.cwd
        assert _.isString opts.killSignal = "SIGINT"
        assert monitor = forever.start command, opts
        restart = ("-" for i in [0..col - 1]).join ""
        monitor.on "restart", -> puts restart.red
        process.on "SIGTERM", -> monitor.stop()
        process.on "SIGINT", -> monitor.stop()

    # This task launches an instance of application where this task
    # is invoked at. It should be either an application build within
    # the framework or the framework itself (it can be launched all
    # by itself as a standalone). Please refer to the implementation!
    # In terms of scalability - it starts the master server istance.
    # It is different from `master` in that it continously spins it.
    task "forever-master", "forever execute master task", (options) ->
        assert col = process.stdout.columns or 80
        assert forever = require "forever-monitor"
        rep = (x) -> "master" if x is "forever-master"
        parameters = _.cloneDeep process.argv, rep
        assert parameters = _.drop parameters, 2
        assert command = ["cake"].concat parameters
        assert environment = _.clone process.env
        assert _.extend environment, forever: "master"
        opts = env: environment, cwd: process.cwd
        assert _.isString opts.killSignal = "SIGINT"
        assert monitor = forever.start command, opts
        restart = ("-" for i in [0..col - 1]).join ""
        monitor.on "restart", -> puts restart.red
        process.on "SIGTERM", -> monitor.stop()
        process.on "SIGINT", -> monitor.stop()

    # This task launches an instance of application where this task
    # is invoked at. It should be either an application build within
    # the framework or the framework itself (it can be launched all
    # by itself as a standalone). Please refer to the implementation!
    # In terms of scalability - it starts the application instance.
    # It is different from `boot` in that it continously spins it.
    task "forever-boot", "forever execute boot task", (options) ->
        assert col = process.stdout.columns or 80
        assert forever = require "forever-monitor"
        rep = (x) -> "boot" if x is "forever-boot"
        parameters = _.cloneDeep process.argv, rep
        assert parameters = _.drop parameters, 2
        assert command = ["cake"].concat parameters
        assert environment = _.clone process.env
        assert _.extend environment, forever: "boot"
        opts = env: environment, cwd: process.cwd
        assert _.isString opts.killSignal = "SIGINT"
        assert monitor = forever.start command, opts
        restart = ("-" for i in [0..col - 1]).join ""
        monitor.on "restart", -> puts restart.red
        process.on "SIGTERM", -> monitor.stop()
        process.on "SIGINT", -> monitor.stop()
