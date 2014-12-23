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

url = require "url"
http = require "http"
events = require "eventemitter2"
colors = require "colors"
logger = require "winston"

_ = require "lodash"
extendz = require "./extends"
routing = require "./routing"
service = require "./service"

{RestfulService} = require "./restful"

# An abstract base class with all of the HTTP methods, defined in
# the HTTP specification and covered by the base implementation
# stubbed with default implementations. By default, the methods
# will throw the 405, method not allowed HTTP error status code.
# The methods have implementations, but marked as the unsupported.
# The ABC also provides stubbed implementation for the API hooks.
module.exports.RestfulStubs = class RestfulStubs extends RestfulService

    # This is a marker that indicates to some internal subsystems
    # that this class has to be considered abstract and therefore
    # can not be treated as a complete class implementation. This
    # mainly is used to exclude or account for abstract classes.
    # Once inherited from, the inheritee is not abstract anymore.
    @abstract yes

    # A hook that will be called once the Connect middleware writes
    # off the headers. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    headers: (request, response, resource, domain, next) -> next()

    # A hook that will be called prior to invoking the API method
    # implementation. Please refer to this prototype signature for
    # information on the parameters it accepts. Beware, this hook
    # is asynchronously wired in, so consult with `async` package.
    # Please be sure invoke the `next` arg to proceed, if relevant.
    processing: (request, response, resource, domain, next) -> next()

    # This method should generally be used to obtain HTTP methods that
    # are allowed on this resources. This is not the only possible way
    # of implementing this method, because it usually can have a lot of
    # different interpretations other than the one in the HTTP spec.
    # The method is an HTTP verb, coherent with the REST interface.
    OPTIONS: @prototype.unsupported

    # Delete the contents of the resources at the establushed path. It
    # generally should destroy the contents of the resource for good.
    # Be sure to provide enough protection for your API for destructive
    # HTTP methods like this one. Apply it to indicate destruction.
    # The method is an HTTP verb, coherent with the REST interface.
    DELETE: @prototype.unsupported

    # Alter the contents of the resources at the established path. It
    # usually means partial replacing contents with the new contents.
    # This HTTP method nicely maps to UPDATE method of the storages.
    # Use this method to partially replace the contents of resources.
    # The method is an HTTP verb, coherent with the REST interface.
    PATCH: @prototype.unsupported

    # Append the contents to the resources at the established path. It
    # usually means adding new content in addition to the old one. This
    # HTTP method nicely maps to INSERT method of the storage engines.
    # Use this method to successively append new contents to resources.
    # The method is an HTTP verb, coherent with the REST interface.
    POST: @prototype.unsupported

    # Alter the contents of the resources at the established path. It
    # usually means replacing the old contents with the new contents.
    # This HTTP method nicely maps to UPDATE method of the storages.
    # Use this method to repetidely replace the contents of resources.
    # The method is an HTTP verb, coherent with the REST interface.
    PUT: @prototype.unsupported

    # Get the contents of the resources at the established path. It
    # is a good idea for this HTTP method to be idempotent. As the
    # rule, this method does not have to alter any contents or data
    # of the resource. Use for unobtrusive retrieval of resources.
    # The method is an HTTP verb, coherent with the REST interface.
    GET: @prototype.unsupported
