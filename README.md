## Overview
Flames is an experimental web development framework. It bears the
unconventional approaches to web development that are conceptually
different from the widely adopted approaches and techniques for the
modern web development. The concepts that make up the Flames are
aimed to simplify and speed up the process of developing any web
application from scratch, yet enforcing the application to be well
designed in terms of the core architecture. This architecture helps
to define logic and UI/UX in terms of well structured and reusable
components, each of those exhibiting predictable, defined behavior.

## What Makes It Different
The framework destroys the distinction between the server side and
the client side once and for all. All parts of your web application
is kept and run on the server. This includes logic as well as UI/UX.
No HTML, CSS or JavaScript have to be written anymore. While that
being said, you still posess all of the necessary abilities to do
anything you want to the Document Object Model of the client side.
That includes executing arbitrary code on the site of the client.
The approach Flames takes is a lot from the world of the desktop
application development, where the user interface is expressed as
and interacted with in terms of widgets and events. Flames takes
this approach further and improves on it in many different ways.

## How is This Working
All of the client side is being handled by the interpreter that
establishes a connection to your web application and transfers the
control to it, while the interpreter is doing all the dirty work
of transfering data, logic and events between the server side and
the client side, relieving your from having to take care of that.
The interpreter synchronizes the real client and the reflection of
the client that exist in the backend, where your code is running.
And it tries to do this in a close to real time mode, as much as
this possible, as well as ensuring the integrity of the states.
The Flames framework is built on top of the Node.js platform, so it
natuarally provides you with enourmous performance and scalability.
We also bundle the UI controls built on top of Twitter Bootstrap,
which also gives you awesome eye-candy looks and the responsiveness.
You can customize or create from scratch the controls of your own.

## Disclaimer
Unlike a whole slew of other web development frameworks, Flames
is not meant to solve the problems of the whole world by providing
loosely coupled components to suite all and any kinds of needs.
Instead, Flames is a well engineered and strictly designed core
for rapid development of modern web applications. By saying modern
web application, we assume that it is an application with two faces.
One face is clean, interactive and eye candy UI/UX for the end user.
The second face is the service provider layer, such as REST, for the
application to be able to talk to the outer world, not just a user.
