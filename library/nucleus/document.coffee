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
events = require "events"
colors = require "colors"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"

# Describe the supplied method of arbitrary service, in a structured
# and expected way, so that it can later be used to programmatically
# process such documentation and do with it whatever is necessary.
# This approach gives unique ability to build self documented APIs.
module.exports.describe = (method, descriptor) ->
    validated = _.isFunction descriptor
    missing = "The #{descriptor} is not a descriptor"
    throw new Error missing unless validated
    method.document ?= new Document
    method.document.descriptor = descriptor

# Traverse all of the services that are registered with the router
# and collect the documentation for each method, then given this
# information, build a hierarhical tree object of all the methods
# and the services that implement them and return to the invoker.
module.exports.collect = (kernel) ->
    services = kernel.router.registry
    logger.debug "Collecting API documentation"
    _.map services, (service) -> do (service) ->
        constructor = service.constructor
        supported = constructor.SUPPORTED
        unsupported = service.unsupported
        implemented = (m) -> service[m] isnt unsupported
        doc = (m) -> service[m].document or new Document
        filtered = _.filter supported, implemented
        methods = _.object filtered, _.map(filtered, doc)
        args = (method) -> [method, service, kernel]
        doc.descriptor args(m)... for m, doc of methods
        service: service, methods: methods

# Descriptor of some method of arbitrary service, in a structured
# and expected way, so that it can later be used to programmatically
# process such documentation and do with it whatever is necessary.
# This approach gives unique ability to build self documented APIs.
module.exports.Document = class Document extends events.EventEmitter

    # Either get or set the example of the method that is being
    # described by this document. If you do not supply example
    # this method will return you one, assuming it was set before.
    # Notes are warning/beware messages about the implementation.
    notes: (notes) ->
        return @$notes if arguments.length is 0
        isNotes = _.isString notes
        noNotes = "The notes is not a string"
        throw new Error noNotes unless isNotes
        @emit "notes", arguments...
        @$notes = notes.toString()

    # Either get or set the example of the method that is being
    # described by this document. If you do not supply example
    # this method will return you one, assuming it was set before.
    # Example is a URL with query that shows example invocation.
    leads: (leads) ->
        return @$leads if arguments.length is 0
        isLeads = _.isString leads
        noLeads = "The leads is not a string"
        throw new Error noLeads unless isLeads
        @emit "leads", arguments...
        @$leads = leads.toString()

    # Either get or set the inputs of the method that is being
    # described by this document. If you do not supply inputs
    # this method will return you one, assuming it was set before.
    # Inputs is a description of the body that method expects.
    inputs: (inputs) ->
        return @$inputs if arguments.length is 0
        isInputs = _.isString inputs
        noInputs = "The inputs is not a string"
        throw new Error noInputs unless isInputs
        @emit "inputs", arguments...
        @$inputs = inputs.toString()

    # Either get or set the outputs of the method that is being
    # described by this document. If you do not supply outputs
    # this method will return you one, assuming it was set before.
    # Outputs is a description of data returned by the method.
    outputs: (outputs) ->
        return @$outputs if arguments.length is 0
        isOutputs = _.isString outputs
        noOutputs = "The outputs is not a string"
        throw new Error noOutputs unless isOutputs
        @emit "outputs", arguments...
        @$outputs = outputs.toString()

    # Either get or set the description of the method that is being
    # described by this document. If you do not supply description
    # this method will return you one, assuming it was set before.
    # Synopsis is a brief story of what this service method does.
    synopsis: (synopsis) ->
        return @$synopsis if arguments.length is 0
        isSynopsis = _.isString synopsis
        noSynopsis = "The synopsis is not a string"
        throw new Error noSynopsis unless isSynopsis
        @emit "synopsis", arguments...
        @$synopsis = synopsis.toString()

    # Either get or set the argument information of the method that
    # is being described by this document. If you do no supply any
    # arguments this method will return already described arguments.
    # Argument consists of name, approximate type and description.
    argument: (identify, typeable, description) ->
        return @$argument if arguments.length is 0
        isIdentify = _.isString identify
        isTypeable = _.isString typeable
        isDescription = _.isString description
        noIdentify = "The identify is not a string"
        noTypeable = "The typeable is not a string"
        noDescription = "The description is not a string"
        throw new Error noIdentify unless isIdentify
        throw new Error noTypeable unless isTypeable
        throw new Error noDescription unless isDescription
        @emit "argument", arguments...
        (@$argument ?= []).push
            description: description
            identify: identify
            typeable: typeable

    # Either get or set the failure information of the method that
    # is being described by this document. If you do no supply any
    # arguments this method will return already described failures.
    # Each failure consists of the expected code and reason for fail
    failure: (code, reasoning) ->
        return @$failure if arguments.length is 0
        isCode = _.isNumber code
        isReasoning = _.isString reasoning
        noCode = "The code is not a number"
        noReasoning = "The reasoning is not a string"
        throw new Error noCode unless isCode
        throw new Error noReasoning unless isReasoning
        @emit "failure", arguments...
        (@$failure ?= []).push
            reasoning: reasoning
            code: code
