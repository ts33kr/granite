augment = require "./nucleus/augment"
augment.Augment.installServiceMethods @
augment.Augment.installStubMethods @

module.exports.test = @GET "/api/test", (request, response) ->
    response.send test: 123

@resource "/api/test", "/api2/test"
