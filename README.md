## Overview
Granite is a web development framework for Node.js. The focus of
the framework is providing the foundation for building enterprise
level applications and services. This is achieved by providing the
well designed OOP architecture with solid structural and behavioral
guidelines and enforcements. Granite takes it seriously, therefore
provides an out of the box support for the broad spectrum of service
lifecycle management techniques that allows to bundle each service
with things like documentation, testing and a slew of other aspects.
This unique architecture outlines services as the primary entities
that encompass not only the service implementation but also all the
things that come with it, such as documentation, tests and so on.
These things are well integrated with the framework which allows for
a very rapid creation of extremely well designed and well decoupled
services with a rock solid architecture. Granite also bundles some
unique approaches and systems, such as the class composition system
along with a unique, code driven approach for crafting UI/UX interfaces.

##Concepts
The Granite framework is built around the concept of being entirely
code driven. That means it diverts from the modern ideas of heavily
using markup languages and declarative techniques, such as HTML, CSS,
QML and other of a kind. Instead, it provides a powerful foundation
for expressing everything in terms of coding, objects and events in
an asynchronous fashion, mostly, in order to match the Node.js idioms.
The Granite was engineered for perfectly matching the one-man-show
scenario, when one or more programmers have to do the job of an entire
team. The framework provides a unique way of the client/server site
integration that allows for entirely transparent data, event and code passing.
The overall architecture of Granite makes it perfect for engineers.
Granite makes hard emphasis on the decomposed objective architecture
in order to provide enterprise level design and make the factor of
the reusable code sky high. It also embeds in or provides support for
the community standard sort of toolkits, such as NPM and Bower package managers.

##Highlights
In this paragraph we will give you a brief overview of the features
that make Granite what it is. Most of the highlights will refer to
the files containing source code, either as a part of implementation
or as a usage example; please bear with us on this one, as it is the
most up-to-date sort of documentation that we have, due to the fact
that our project is young and its design changes and evolves rapidly.
Below follows a bullet-list of highlights currently implemented. We
also strongly encourage you to browse over the project source codes
and discover more pieces there, ones that haven't been documented yet.
Use http://ts33kr.github.io/granite for browsing.

  + Highly advanced code emission platform that is taking care of
  doing all the processing necessary to transfer the relevant code
  to the client site. The entire method hierarchies are transferred,
  so that you can always access all the possibly overridden methods
  in the base classes. On top of that, there is a special mechanism
  implemented that allows you to override type implementations that
  are used in the parent classes, without having to override any of
  the base classes coding (as long as types have similar interfaces).
  And last, but not least - all of the code that is emitted into the
  client site is being taken apart and re-translated, using either
  obfuscation or the code beautification toolkit, depending on config.

  + A unique extension to the object system, written using pure
  CoffeeScript that allows for completely transparent and dynamic
  multiple inheritance, modelled similar to the mixin concept. It
  allows you to build modular pieces of functionality that can be
  reused in any class. The system is unobtrusive and makes use of
  declarative style to keep the syntax clean, when you have a lot
  of different building blocks mixed into your class. Please see
  [nucleus/compose.coffee](library/nucleus/compose.coffee) for
  the composition system implementation coding.

  + Natively keeping client-side and server-side code within the
  same class, naturally co-existing and interacting between two
  remote scopes. Allows for a massively superior way of building
  abstractions that abstract away the whole patterns and protocols
  that hide or carry away the interactions between the client and
  the server. It completely frees your of routine and allows to
  focus only on what matters, not on the code required for code.
  See [membrane/visual.coffee](library/membrane/visual.coffee)
  and the related for an implementation boilerplate.

  + A bi-directional and real time communication channel that is
  entirely transparent to a developer - it looks just like a usual
  method invocation, with all the guts: parameters, callbacks and
  so on. All of the client/server transportation complexities are
  hidden under the hood, without the need of every touching them.
  The channel uses latest, state-of-the-art technologies, such as
  [Socket.IO](http://socket.io) to implement it. Please refer to
  [membrane/duplex.coffee](library/membrane/duplex.coffee) and
  [membrane/bilateral.coffee](library/membrane/bilateral.coffee)
  for the reference coding and info.

  + A strong layer for implementing conventional application APIs.
  The REST architecture is shipped out of the box, with possibility
  of deep customization to fit in any architecture on top of HTTP.
  Has a built in support for advanced features, like the embedded
  declarative documentation and testing subsystems wired into it.
  Everything is built around an exceptionally strong object model
  and makes uses of an automatic wiring that requires zero level
  configuration for creating and discovering new services. See
  [exposure/inventory.coffee](library/exposure/inventory.coffee).

  + A production grade load balancing and failover clustering
  provided right out of the box. Delivered by technology called
  [Seaport](https://github.com/substack/seaport) it provides a
  lot of advanced functionality, such as the node auto-discovery
  and no need for initial configuration. It allows to dynamically
  create star-like topologies in a matter of seconds, supporting
  any order of bringing nodes up (master and slaves). The shipped
  balancing algorithm is a simple, session-sticky round robin. See
  [nucleus/scaled.coffee](library/nucleus/scaled.coffee) file for
  the scalable kernel implementation.

  + Due to the strong objective design principles, it is extremely
  easy to write components (classes) that contain the client side
  coding as well as the server side coding. A frontend package manager
  [Bower](http://bower.io) is built right into the framework in order
  to provide the flexible ability to embed the frontend dependencies
  directly into your components. The dependencies are intelligently
  resolved and automatically satisfied during the node bootloaing;
  in a configurable manner. For the implementation coding see
  [membrane/bower.coffee](library/membrane/bower.coffee).

  + An out of the box configuration system allows you to consume
  configuration data (files) right away, without setting up any
  sort of boilerplate. The system is based on a well known package
  called [NConf](https://github.com/flatiron/nconf). Refer to the
  [nucleus/scoping.coffee](library/nucleus/scoping.coffee) to get
  some idea about the implementation. On top of this, there are a
  set of tools shipped out of the box that make good use of this,
  such as [MongoDB](http://mongodb.org) and [Redis](http://redis.io)
  clients (components) that can be mixed into your service and
  used right away, without having to think about configuration.

  + Extremely viable kernel built into the framework. An application
  (node) is automatically reloaded in case of an unexpected crash or
  error and has extensive configuration capabilities as to reacting
  to the unexpected conditions. The technology is based on something
  called [forever](https://github.com/nodejitsu/forever). On top of
  this, the framework has a built in memory monitor that watches an
  application to not exceed the configured limit and reloads an app
  if it does so. See [exposure/memory.coffee](library/exposure/memory.coffee)
  for the monitor implementation coding and information.

  + Convenient and practical message translation (internationalization)
  platform. It is built on top of the client/server communication tools
  built into the framework, therefore requires virtually no configs at
  all; it just works out of the box. The system uses YAML file format
  to keep its translation tables. This allows for the tables to be very
  human-oriented and therefore are extremely easy and fun to work with.
  Please see [exposure/localized.coffee](library/exposure/localized.coffee)
  source code to familiarize yourself with the platform implementation.
  Also take a look at [locale/tracked.yaml](locale/tracked.yaml) for
  the real world example of translation tables for the specific service.

  + Centralized mechanism for application level events publishing and
  book keeping. Basically, allows you to publish an application event
  that will be automatically propagated to all application nodes, via
  Redis pub/sub mechanism, and then the event and all its metadata will
  be stored in a capped collection in MongoDB. This toolkit gives you
  an ability to keep an effective application log and stream events
  from a tailable MongoDB cursor, receiving the real time information.
  Please see [exposure/central.coffee](library/exposure/central.coffee)
  source code for the centralized messaging system implementation and
  all the available there relevant documentation.

##Disclaimer
Before considering using Granite framework, you should be well aware
of some of the specifics regarding its usage. The first and foremost
is the fact that Granite design and architecture is fluctuating at
a very rapid rate. In order to achieve the clean and effective design
we change different aspects of the architecture and experimentally
verify the viability of one or another approach. For this very reason
the framework is not covered by any tests at the time of writing this.
But rest assured, once the architecture is solid enough, framework
will be covered with all sorts of test cases that ensure its internal
integrity. One other thing to consider is that you must be prepared to
traverse the framework code in order to discover functionality and a
way of usage. The entire code base is 100% documented. But materials
targeted towards the end users, such as user guide or manual are not
there just yet. So you have to be ready to go digging deep into code.
What should be also mentioned is that framework is under the active
development and we would appreciate the feedback very much. So you
can always count on a friendly support ready to give you a hand with it!
