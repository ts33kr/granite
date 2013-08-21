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

uuid = require "node-uuid"
asciify = require "asciify"
connect = require "connect"
logger = require "winston"
events = require "events"
colors = require "colors"
nconf = require "nconf"
https = require "https"
paths = require "path"
http = require "http"
util = require "util"
fs = require "fs"

_ = require "lodash"
extendz = require "./../nucleus/extends"
routing = require "./../nucleus/routing"
service = require "./../nucleus/service"
kernel = require "./../nucleus/kernel"

# Deposit instance is a manager that represents a storage of the
# arbitraty objects addresses by UUID that are being stored in
# the kernel. This is important because the kernel never reloads.
# Provide the rudimentary garbage collection support for objects.
module.exports.Deposit = class Deposit extends events.EventEmitter

    # Create an instance of the deposit, attached to the supplied
    # kernel instance to usage as a storage facility. Multiple
    # deposists can be created on the same kernel without making
    # any interference to other possible instances of the deposit.
    constructor: (@kernel, @tag = uuid.v1()) ->
        isKernel = @kernel instanceof kernel.Generic
        noKernel = "The instance of kernel is invalid"
        noTagging = "The supplied tagging is not valid"
        throw new Error noTagging unless _.isSring tag
        throw new Error noKernel unless isKernel
        @storage = @kernel[@tag] = {}

    # Spawn the keepalive watcher that runs after the specified amount
    # of time, expressed at milliseconds, and if such an entry still
    # exists in the kernel storage, remove it using the get method. If
    # the entry does not exist at the point of call, it throws errors.
    keepalive: (tag = uuid.v1(), mseconds) ->
        noSubject = "Cannot locate entry at #{tag}"
        throw new Error noSubject unless tag of @storage
        timeout = (s, f) => setTimeout f, s
        timeout mseconds, (parameters...) =>
            @emit "expired", tag, mseconds
            get tag, yes if tag of @storage

    # Associate the supplied subject with the supplied UUID tag and
    # store the pair in the kernel driven storage. If the UUID tag
    # is not supplied, it will be automatically issued and returned
    # to the invoker for the purpose of having the subject reference.
    set: (subject, tag = uuid.v1()) ->
        isSubject = "Entry already exists at #{tag}"
        noTagging = "The supplied tagging is not valid"
        throw new Error noTagging unless _.isString tag
        throw new Error isSubject if tag of @storage
        @storage[tag] = subject; return tag

    # Try finding the subject in the kernel driver storage by looking
    # it up using the supplied UUID tag. Altough this method does not
    # require you to supply a tag, please do this as it is necessary.
    # If the record is not found at the storage, exception is thrown.
    get: (tag = uuid.v1(), destroy) ->
        noSubject = "Cannot locate entry at #{tag}"
        noTagging = "The supplied tagging is not valid"
        throw new Error noTagging unless _.isString tag
        throw new Error noSubject unless tag of @storage
        preempt = -> delete @storage[tag] if destroy
        value = @storage[tag]; preempt(); value
