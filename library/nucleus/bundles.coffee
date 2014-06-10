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

connect = require "connect"
logger = require "winston"
events = require "eventemitter2"
colors = require "colors"
nconf = require "nconf"
util = require "util"
fs = require "fs"

_ = require "lodash"
routing = require "./routing"
service = require "./service"
scoping = require "./scoping"

# One of the predefined scopes, baked into the framework. Scopes
# that are bundled with the framework are pretty standard and
# should generally cover 95% percent of the typical web needs.
# Of course you are free to define as much scopes as you need.
# The scope contains all the configuration defaults of Granite.
module.exports.PRODUCTION = new scoping.Scope "production", ->
    @synopsis = "Final production environment for end users"
    @overrides = layout: library: "library", config: "config"
    @defaults = new Object env: {},  server: {}, secure: {}
    @defaults.hub = host: "localhost", port: 1337, opts: {}
    @defaults.env = dirs: ["tmp", "var", "pub"], mode: 0o744
    @defaults.master = host: "localhost", http: 80, https: 443
    @defaults.server = host: "localhost", http: 80, https: 443
    @defaults.session = secret: "abcdef", cookie: maxAge: 3600000
    @defaults.redis = host: "localhost", port: 6379, options: {}
    @defaults.log = request: {format: "dev", level: "debug"}
    @defaults.secure.key = "#{__dirname}/../../keys/key.pem"
    @defaults.secure.cert = "#{__dirname}/../../keys/cert.pem"
    @defaults.central = enabled: yes, collection: "g-central"
    @defaults.central.options = capped: yes, size: 2147483648
    @defaults.session.key = "granite.session.identification"
    @defaults.scanner = dirs: [], force: yes, reboot: false
    @defaults.threshold = lag: 70, reason: "overloaded"
    @defaults.visual = compression: yes, beautify: no
    @defaults.memory = limit: 256 * 1024 * 1024
    @defaults.failures = exposeExceptions: no
    @defaults.balancer = sticky: yes, ttl: 60
    @defaults.kernel = crashOnException: yes
    @defaults.duplex = disconnectOnError: yes
    @defaults.session.enableExternal = yes
    @defaults.assets = dirs: [], opts: {}
    @defaults.beacon = interval: 60000
    @defaults.socket = "log level": 0
    @defaults.api = includeStack: no
    @defaults.env.preserve = ["pub"]
    @defaults.visual.logging = no

# One of the predefined scopes, baked into the framework. Scopes
# that are bundled with the framework are pretty standard and
# should generally cover 95% percent of the typical web needs.
# Of course you are free to define as much scopes as you need.
# The scope contains all the configuration defaults of Granite.
module.exports.STAGING = new scoping.Scope "staging", ->
    @synopsis = "An environment between staging and production"
    @overrides = layout: library: "library", config: "config"
    @defaults = new Object env: {},  server: {}, secure: {}
    @defaults.hub = host: "localhost", port: 1337, opts: {}
    @defaults.env = dirs: ["tmp", "var", "pub"], mode: 0o744
    @defaults.master = host: "localhost", http: 80, https: 443
    @defaults.server = host: "localhost", http: 80, https: 443
    @defaults.session = secret: "abcdef", cookie: maxAge: 3600000
    @defaults.redis = host: "localhost", port: 6379, options: {}
    @defaults.log = request: {format: "dev", level: "debug"}
    @defaults.secure.key = "#{__dirname}/../../keys/key.pem"
    @defaults.secure.cert = "#{__dirname}/../../keys/cert.pem"
    @defaults.central = enabled: yes, collection: "g-central"
    @defaults.central.options = capped: yes, size: 2147483648
    @defaults.session.key = "granite.session.identification"
    @defaults.scanner = dirs: [], force: yes, reboot: false
    @defaults.threshold = lag: 70, reason: "overloaded"
    @defaults.visual = compression: yes, beautify: no
    @defaults.memory = limit: 256 * 1024 * 1024
    @defaults.failures = exposeExceptions: no
    @defaults.balancer = sticky: yes, ttl: 60
    @defaults.kernel = crashOnException: yes
    @defaults.duplex = disconnectOnError: yes
    @defaults.session.enableExternal = yes
    @defaults.assets = dirs: [], opts: {}
    @defaults.beacon = interval: 60000
    @defaults.socket = "log level": 0
    @defaults.api = includeStack: no
    @defaults.env.preserve = ["pub"]
    @defaults.visual.logging = no

# One of the predefined scopes, baked into the framework. Scopes
# that are bundled with the framework are pretty standard and
# should generally cover 95% percent of the typical web needs.
# Of course you are free to define as much scopes as you need.
# The scope contains all the configuration defaults of Granite.
module.exports.DEVELOPMENT = new scoping.Scope "development", ->
    @synopsis = "Unstable working environment for developers"
    @overrides = layout: library: "library", config: "config"
    @defaults = new Object env: {},  server: {}, secure: {}
    @defaults.hub = host: "localhost", port: 1337, opts: {}
    @defaults.env = dirs: ["tmp", "var", "pub"], mode: 0o744
    @defaults.master = host: "localhost", http: 1080, https: 1043
    @defaults.server = host: "localhost", http: 1080, https: 1043
    @defaults.session = secret: "abcdef", cookie: maxAge: 3600000
    @defaults.redis = host: "localhost", port: 6379, options: {}
    @defaults.log = request: {format: "dev", level: "debug"}
    @defaults.secure.key = "#{__dirname}/../../keys/key.pem"
    @defaults.secure.cert = "#{__dirname}/../../keys/cert.pem"
    @defaults.central = enabled: yes, collection: "g-central"
    @defaults.central.options = capped: yes, size: 2147483648
    @defaults.session.key = "granite.session.identification"
    @defaults.scanner = dirs: [], force: yes, reboot: 100
    @defaults.threshold = lag: 70, reason: "overloaded"
    @defaults.visual = compression: yes, beautify: yes
    @defaults.memory = limit: 256 * 1024 * 1024
    @defaults.failures = exposeExceptions: yes
    @defaults.balancer = sticky: yes, ttl: 60
    @defaults.kernel = crashOnException: yes
    @defaults.duplex = disconnectOnError: no
    @defaults.session.enableExternal = yes
    @defaults.assets = dirs: [], opts: {}
    @defaults.beacon = interval: 60000
    @defaults.socket = "log level": 0
    @defaults.api = includeStack: no
    @defaults.env.preserve = ["pub"]
    @defaults.visual.logging = yes

# One of the predefined scopes, baked into the framework. Scopes
# that are bundled with the framework are pretty standard and
# should generally cover 95% percent of the typical web needs.
# Of course you are free to define as much scopes as you need.
# The scope contains all the configuration defaults of Granite.
module.exports.TESTING = new scoping.Scope "testing", ->
    @synopsis = "Isolated environment for running the tests"
    @overrides = layout: library: "library", config: "config"
    @defaults = new Object env: {},  server: {}, secure: {}
    @defaults.hub = host: "localhost", port: 1337, opts: {}
    @defaults.env = dirs: ["tmp", "var", "pub"], mode: 0o744
    @defaults.master = host: "localhost", http: 1080, https: 1043
    @defaults.server = host: "localhost", http: 1080, https: 1043
    @defaults.session = secret: "abcdef", cookie: maxAge: 3600000
    @defaults.redis = host: "localhost", port: 6379, options: {}
    @defaults.log = request: {format: "dev", level: "debug"}
    @defaults.secure.key = "#{__dirname}/../../keys/key.pem"
    @defaults.secure.cert = "#{__dirname}/../../keys/cert.pem"
    @defaults.central = enabled: yes, collection: "g-central"
    @defaults.central.options = capped: yes, size: 2147483648
    @defaults.session.key = "granite.session.identification"
    @defaults.scanner = dirs: [], force: yes, reboot: 100
    @defaults.threshold = lag: 70, reason: "overloaded"
    @defaults.visual = compression: yes, beautify: yes
    @defaults.memory = limit: 256 * 1024 * 1024
    @defaults.failures = exposeExceptions: no
    @defaults.balancer = sticky: yes, ttl: 60
    @defaults.kernel = crashOnException: yes
    @defaults.duplex = disconnectOnError: no
    @defaults.session.enableExternal = yes
    @defaults.assets = dirs: [], opts: {}
    @defaults.beacon = interval: 60000
    @defaults.socket = "log level": 0
    @defaults.api = includeStack: yes
    @defaults.env.preserve = ["pub"]
    @defaults.visual.logging = yes
