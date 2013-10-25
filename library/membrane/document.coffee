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
colors = require "colors"
assert = require "assert"
nconf = require "nconf"
https = require "https"
http = require "http"
util = require "util"

{Archetype} = require "../nucleus/archetype"

# Descriptor of some method of arbitrary service, in a structured
# and expected way, so that it can later be used to programmatically
# process such documentation and do with it whatever is necessary.
# This approach gives unique ability to build self documented APIs.
module.exports.Document = class Document extends Archetype

    # Either get or set the argument information of the method that
    # is being described by this document. If you do no supply any
    # arguments this method will return already described arguments.
    # Argument consists of name, approximate type and description.
    argument: (identify, typeable, description) ->
        return @$argument if arguments.length is 0
        noIdentify = "the identify param is not a string"
        noTypeable = "the typeable param is not a string"
        noDescription = "the description is not a string"
        assert _.isString(description), noDescription
        assert _.isString(identify), noIdentify
        assert _.isString(typeable), noTypeable
        @emit.call this, "argument", arguments...
        return (@$argument ?= []).push
            description: description
            identify: identify
            typeable: typeable

    # Either get or set the Github information of the method that
    # is being described by this document. If you do no supply any
    # arguments this method will return already described failures.
    # Each consists of a username, the repository name and the path.
    github: (username, repository, path) ->
        return @$github if arguments.length is 0
        noUsername = "the username must be a string"
        noRepository = "the repository must be a string"
        noPath = "the path name must be a valid string"
        assert _.isString(username), noUsername
        assert _.isString(repository), noRepository
        assert path and _.isString(path), noPath
        @emit.call this, "github", arguments...
        return (@$github ?= []).push
            repository: repository
            username: username
            path: path

    # Either get or set the failure information of the method that
    # is being described by this document. If you do no supply any
    # arguments this method will return already described failures.
    # Each failure consists of the expected code and reason for fail
    failure: (code, reasoning) ->
        return @$failure if arguments.length is 0
        noCode = "the supplied code is not a number"
        noReasoning = "the reasoning is not a string"
        assert _.isString(reasoning), noReasoning
        assert  code and _.isNumber(code), noCode
        @emit.call this, "failure", arguments...
        return (@$failure ?= []).push
            reasoning: reasoning
            code: code

    # Either get or set the produces information of the method that
    # is being described by this document. If you do no supply any
    # arguments this method will return already described failures.
    # The mimes should be args that contains a valid MIME types.
    produces: (produces...) ->
        return @$produces if arguments.length is 0
        notString = "elements must be MIME type strings"
        assert _.all(produces, _.isString), notString
        @$produces = (@$produces or []).concat produces
        @emit.call @, "produces", @$produces, arguments
        assert _.isArray @$produces; return @$produces

    # Either get or set the consumes information of the method that
    # is being described by this document. If you do no supply any
    # arguments this method will return already described failures.
    # The mimes should be args that contains a valid MIME types.
    consumes: (consumes...) ->
        return @$consumes if arguments.length is 0
        notString = "elements must be MIME type strings"
        assert _.all(consumes, _.isString), notString
        @$consumes = (@$consumes or []).concat consumes
        @emit.call @, "consumes", @$consumes, arguments
        assert _.isArray @$consumes; return @$consumes

    # Either get or set the relevant information of the method that
    # is being described by this document. If you do no supply any
    # arguments this method will return already described failures.
    # The relevant should be a string that contains a valid URL.
    relevant: (relevant) ->
        return @$relevant if arguments.length is 0
        notString = "a relevant should be a string"
        assert _.all(relevant, _.isString), notString
        @$relevant = (@$relevant or []).concat relevant
        @emit.call @, "relevant", @$relevant, arguments
        assert _.isArray @$relevant; return @$relevant

    # Either get or set the markings information of the method that
    # is being described by this document. If you do no supply any
    # arguments this method will return already described failures.
    # The markings should be an object of `marking: level` values.
    markings: (markings) ->
        return @$markings if arguments.length is 0
        noMarkings = "the markings should be a object"
        assert _.isObject(markings), noMarkings
        assert _.extend @$markings ?= {}, markings
        @emit.call @, "markings", arguments...
        assert @$markings; return @$markings

    # Either get or set the schemas information of the method that
    # is being described by this document. If you do no supply any
    # arguments this method will return already described failures.
    # The schemas should be an object of `slot: schema` values.
    schemas: (schemas) ->
        return @$schemas if arguments.length is 0
        noSchemas = "the schemas should be a object"
        assert _.isObject(schemas), noSchemas
        assert _.extend @$schemas ?= {}, schemas
        @emit.call this, "schemas", arguments...
        assert @$schemas; return @$schemas

    # Either get or set the version information of the method that
    # is being described by this document. If you do no supply any
    # arguments this method will return already described failures.
    # The version should be a string with an arbitrary contents.
    version: (version) ->
        return @$version if arguments.length is 0
        noVersion = "version should be a string"
        assert _.isString(version), noVersion
        @emit.call this, "version", arguments...
        return @$version = vesrion.toString()

    # Either get or set the remark to the method that is being
    # described by this document. If you do not supply example
    # this method will return you one, assuming it was set before.
    # Notes are warning/beware messages about the implementation.
    remark: (remark) ->
        return @$remark if arguments.length is 0
        noRemark = "the remark is not a string"
        assert _.isString(remark), noRemark
        @emit.call this, "remark", arguments...
        return @$remark = remark.toString()

    # Either get or set the inputs of the method that is being
    # described by this document. If you do not supply inputs
    # this method will return you one, assuming it was set before.
    # Inputs is a description of the body that method expects.
    inputs: (inputs) ->
        return @$inputs if arguments.length is 0
        noInputs = "the inputs is not a string"
        assert _.isString(inputs), noInputs
        @emit.call this, "inputs", arguments...
        return @$inputs = inputs.toString()

    # Either get or set the outputs of the method that is being
    # described by this document. If you do not supply outputs
    # this method will return you one, assuming it was set before.
    # Outputs is a description of data returned by the method.
    outputs: (outputs) ->
        return @$outputs if arguments.length is 0
        noOutputs = "the outputs is not a string"
        assert _.isString(outputs), noOutputs
        @emit.call this, "outputs", arguments...
        return @$outputs = outputs.toString()

    # Either get or set the description of the method that is being
    # described by this document. If you do not supply description
    # this method will return you one, assuming it was set before.
    # Synopsis is a brief story of what this service method does.
    synopsis: (synopsis) ->
        return @$synopsis if arguments.length is 0
        noSynopsis = "the synopsis is not a string"
        assert _.isString(synopsis), noSynopsis
        @emit.call this, "synopsis", arguments...
        return @$synopsis = synopsis.toString()
