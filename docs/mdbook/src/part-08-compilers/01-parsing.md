# Parsing

## Compiler Directives

Up to this point, every construct we've introduced has described the computation itself. Definitions, places, invocations, and transform rules all become part of the association graph that ultimately realizes the computation.

Sometimes, however, we need to communicate with the compiler rather than with the computation.

MatterScript uses **compiler directives** for this purpose. Directives begin with the `@` character and provide information about how a program should be interpreted, analyzed, or realized. Unlike definitions or invocations, directives do not become part of the computational network. They exist only during compilation.

For example, a program may request a particular backend:

```matterscript
@target(posix, path="/dev/ttyS0", priority=100)
```

This directive tells the compiler that the resulting program should be realized using the POSIX backend and provides backend-specific configuration options. Another backend might instead target an FPGA, a GPU, or another execution environment without requiring any changes to the computational description itself.

Directives also establish the domain in which a program operates.

```matterscript
@domain(spatial3d)
```

A domain extends the language with concepts appropriate to a particular problem space. The `spatial3d` domain, introduced elsewhere in this book, provides geometric primitives and operations for constructing three-dimensional models while remaining fully integrated with MatterScript's computational model.

Because domains are selected explicitly, the core language remains intentionally small. New domains can introduce specialized vocabularies for geometry, signal processing, chemistry, biology, or other disciplines without complicating the language that every programmer must learn.

Compiler directives therefore separate **the description of the computation** from **the configuration of the toolchain**. The computation remains portable and backend-independent, while the directives provide the compiler with the context needed to realize that computation efficiently on a particular platform or within a particular domain.


*Drafting in progress...*
