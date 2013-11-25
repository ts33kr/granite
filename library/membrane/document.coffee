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
# So this class is basically a typed, programmatic data storage.
module.exports.Document = class Document extends Archetype

    # Either get or set the argument information of the method that
    # is being described by this document. If you do no supply any
    # arguments this method will return already described arguments.
    # Argument consists of name, approximate type and description.
    # The information is being stored as a structured data object.
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
    # arguments this method will return already described Github.
    # Each consists of a username, the repository name and the path.
    # The information is being stored as a structured data object.
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
    # The information is being stored as a structured data object.
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
    # arguments this method will return already described produces.
    # The mimes should be args that contains a valid MIME types.
    # The invocation signature is splat, to natually suport vector.
    produces: (produces...) ->
        return @$produces or [] if arguments.length is 0
        internal = "an internal, implementational error"
        typ = "all of elements must be MIME type strings"
        assert produces and _.isArray(produces), internal
        assert _.all(produces, _.isString), typ.toString()
        @$produces = (@$produces or []).concat produces
        @$produces = _.toArray _.unique @$produces or []
        @emit.call @, "produces", @$produces, arguments
        assert _.isArray @$produces; return @$produces

    # Either get or set the consumes information of the method that
    # is being described by this document. If you do no supply any
    # arguments this method will return already described consumes.
    # The mimes should be args that contains a valid MIME types.
    # The invocation signature is splat, to natually suport vector.
    consumes: (consumes...) ->
        return @$consumes or [] if arguments.length is 0
        internal = "an internal, implementational error"
        typ = "all of elements must be MIME type strings"
        assert consumes and _.isArray(consumes), internal
        assert _.all(consumes, _.isString), typ.toString()
        @$consumes = (@$consumes or []).concat consumes
        @$consumes = _.toArray _.unique @$consumes or []
        @emit.call @, "consumes", @$consumes, arguments
        assert _.isArray @$consumes; return @$consumes

    # Either get or set the relevant information of the method that
    # is being described by this document. If you do no supply any
    # arguments this method will return already described failures.
    # The relevant should be a string that contains a valid URL.
    # The invocation signature is splat, to natually suport vector.
    relevant: (relevant...) ->
        return @$relevant or [] if arguments.length is 0
        internal = "an internal, implementational error"
        typ = "all of the elements must be valid strings"
        assert relevant and _.isArray(relevant), internal
        assert _.all(relevant, _.isString), typ.toString()
        @$relevant = (@$relevant or []).concat relevant
        @$relevant = _.toArray _.unique @$relevant or []
        @emit.call @, "relevant", @$relevant, arguments
        assert _.isArray @$relevant; return @$relevant

    # Either get or set the markings information of the method that
    # is being described by this document. If you do no supply any
    # arguments this method will return already described failures.
    # The markings should be an object of `marking: level` values.
    # All supplied markings will be concatenated with a previous.
    markings: (markings) ->
        return @$markings or {} if arguments.length is 0
        external = "the method signature expects an object"
        type = "all of the elements must be valid strings"
        assert markings and _.isObject(markings), external
        assert _.all(_.values(markings), _.isString), type
        assert previous = _.clone @$markings or new Object
        @$markings = try _.extend previous or {}, markings
        @emit.call @, "markings", @$markings, arguments
        assert _.isObject @$markings; return @$markings

    # Either get or set the description of the method that is being
    # described by this document. If you do not supply description
    # this method will return you one, assuming it was set before.
    # Synopsis is a brief story of what this service method does.
    # The argument could be a function, see coding for that one.
    synopsis: (synopsis) ->
        fn = _.isFunction(x = @$synopsis) and x
        auto = => if fn then x.call this else x
        assigns = => assert @$synopsis = synopsis
        return auto() if arguments.length is 0
        return assigns() if _.isFunction synopsis
        noSynopsis = "the synopsis is not a string"
        assert _.isString(synopsis), noSynopsis
        @emit.call this, "synopsis", arguments...
        return @$synopsis = synopsis.toString()

    # Either get or set the version information of the method that
    # is being described by this document. If you do no supply any
    # arguments this method will return already described failures.
    # The version should be a string with an arbitrary contents.
    # The argument could be a function, see coding for that one.
    version: (version) ->
        fn = _.isFunction(x = @$version) and x
        auto = => if fn then x.call this else x
        assigns = => assert @$version = version
        return auto() if arguments.length is 0
        return assigns() if _.isFunction version
        noVersion = "the version is not a string"
        assert _.isString(version), noVersion
        @emit.call this, "version", arguments...
        return @$version = version.toString()

    # Either get or set the outputs of the method that is being
    # described by this document. If you do not supply outputs
    # this method will return you one, assuming it was set before.
    # Outputs is a description of data returned by the method.
    # The argument could be a function, see coding for that one.
    outputs: (outputs) ->
        fn = _.isFunction(x = @$outputs) and x
        auto = => if fn then x.call this else x
        assigns = => assert @$outputs = outputs
        return auto() if arguments.length is 0
        return assigns() if _.isFunction outputs
        noOutputs = "the outputs is not a string"
        assert _.isString(outputs), noOutputs
        @emit.call this, "outputs", arguments...
        return @$outputs = outputs.toString()

    # Either get or set the inputs of the method that is being
    # described by this document. If you do not supply inputs
    # this method will return you one, assuming it was set before.
    # Inputs is a description of the body that method expects.
    # The argument could be a function, see coding for that one.
    inputs: (inputs) ->
        fn = _.isFunction(x = @$inputs) and x
        auto = => if fn then x.call this else x
        assigns = => assert @$inputs = inputs
        return auto() if arguments.length is 0
        return assigns() if _.isFunction inputs
        noInputs = "the inputs is not a string"
        assert _.isString(inputs), noInputs
        @emit.call this, "inputs", arguments...
        return @$inputs = inputs.toString()

    # Either get or set the remark to the method that is being
    # described by this document. If you do not supply example
    # this method will return you one, assuming it was set before.
    # Notes are warning/beware messages about the implementation.
    # The argument could be a function, see coding for that one.
    remark: (remark) ->
        fn = _.isFunction(x = @$remark) and x
        auto = => if fn then x.call this else x
        assigns = => assert @$remark = remark
        return auto() if arguments.length is 0
        return assigns() if _.isFunction remark
        noRemark = "the remark is not a string"
        assert _.isString(remark), noRemark
        @emit.call this, "remark", arguments...
        return @$remark = remark.toString()
