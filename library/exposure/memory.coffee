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
filesize = require "filesize"
asciify = require "asciify"
connect = require "connect"
request = require "request"
logger = require "winston"
colors = require "colors"
async = require "async"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"

{Zombie} = require "../nucleus/zombie"
{OnlySsl} = require "../membrane/securing"
{Barebones} = require "../membrane/skeleton"
{Healthcare} = require "../membrane/health"

# The memory monitor service is a zombie services that tracks usage
# of the RAM by this process (ergo, by this node). The service drives
# from the kernel beacon and runs the monitoring on each heartbeat of
# the beacon. If the memory usage exceed the configurable max limit,
# this service should gracefully notify the kernel and reboot kernel.
module.exports.MemoryMonitor = class MemoryMonitor extends Zombie

    # A hook that will be called prior to instantiating the service
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    instance: (kernel, service, next) ->
        assert limit = try nconf.get "memory:limit"
        assert _.isNumber(limit), "got no memory limit"
        note = "Setting kernel memory limit to %s bytes"
        hits = "Kernel memory limit overflow detected: %s"
        logger.info note.red, try limit.toString().bold
        trap = (fn) -> kernel.on "mem-stat", fn; next()
        return trap (memory, humanized, parameters) ->
            overflow = try memory.heapTotal >= limit
            detected = "#{humanized.heapTotal}".bold
            return undefined unless overflow is yes
            logger.warn hits.toString().red, detected
            kernel.shutdownKernel undefined, no

    # A hook that will be called each time when the kernel beacon
    # is being fired. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    beacon: (kernel, timestamp, next) ->
        assert _.isObject mem = process.memoryUsage()
        h = (size) -> return filesize(size).toString()
        c = (value, k) -> return k and _.isNumber value
        humanize = (a, v, k) -> a[k] = h(v) if c(v, k)
        note = "memory: RESIDENT=%s; USED=%s; TOTAL=%s"
        assert humaned = try _.transform mem, humanize
        assert resident = humaned.rss.toString().bold
        assert used = humaned.heapUsed.toString().bold
        assert total = humaned.heapTotal.toString().bold
        logger.debug note.grey, resident, used, total
        kernel.emit "mem-stat", mem, humaned; next()