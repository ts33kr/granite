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
along with a unique, code driven approach for crafting UI/UX.

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
integration that allows for entirely transparent data and event passing.
The overall architecture of Granite makes it perfect for engineers.
Granite makes hard emphasis on the decomposed objective architecture
in order to provide enterprise level design and make the factor of
the reusable code sky high. It also embeds in or provides support for
the community standard sort of toolkits, such as NPM and Bower managers.

##Highlights
In this paragraph we will give you a brief overview of the features
that make Granite what it is. Most of the highlights will refer to
the files containing source code, either as a part of implementation
or as a usage example, please bear with us on this one, as it is the
most up-to-date sort of documentation that we have, due to the fact
that our project is very rapidly evolving and enhancing, changing.
Below follows a bullet-list of highlights currently implemented. We
also strongly encourage you to browse over the project source codes
and discover missing pieces there that are missing from documentation.
Use http://ts33kr.github.io/granite for browsing.

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
  for the reference coding.

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
can always can on a friendly support ready to give you a hand with it!
