# Abstract Syntax Trees

Every MatterScript program begins life as text.

```matterscript
FULLADD($A $B $C)(SUM<> CARRY<>)
```

To a human, this is a readable description of a computation.

To a compiler, it is only a sequence of characters.

Before the compiler can reason about the program, it must recover its structure.

That structure is represented internally as an **Abstract Syntax Tree**, or AST.

---

## The Program Beneath the Text

An AST ignores formatting and punctuation that exist only to help humans read the language.

For example,

```matterscript
AND($A $B)(RESULT<>)
```

might be represented internally as something conceptually similar to

```text
Invocation
 ├── Name: AND
 ├── Destination List
 │     ├── $A
 │     └── $B
 └── Source List
       └── RESULT<>
```

This tree captures the meaning of the program without preserving its exact textual representation.

Whitespace disappears.

Comments disappear.

Formatting disappears.

Only structure remains.

---

## The AST Is Not the Computation

One of the easiest mistakes to make when thinking about compilers is to imagine that the AST somehow *is* the program.

It isn't.

The AST is simply the compiler's understanding of the source text.

It exists only long enough for the compiler to analyze the language.

The computational model appears later.

```text
Source Code
        │
        ▼
Abstract Syntax Tree
        │
        ▼
Association Graph
        │
        ▼
Backend Realization
```

This distinction is important.

The AST understands syntax.

The association graph understands computation.

---

## A Stable Foundation

Almost every later stage of the compiler builds upon the AST.

Semantic analysis verifies that names are valid.

Definitions are connected to invocations.

Domains introduce additional syntax.

Compiler directives are interpreted.

Geometry expressions are recognized.

Errors are reported against the original source.

Because every feature is represented in a common tree structure, the compiler can grow without constantly rewriting its earlier stages.

---

## Trees Give Way to Graphs

MatterScript begins as a tree because people write text one line at a time.

But computation is not a tree.

It is a graph.

One invocation may feed many others.

Names connect distant parts of a program.

Definitions reference other definitions.

Causal relationships span the entire design.

The compiler therefore performs a fundamental transformation.

It converts the tree describing the **syntax** into a graph describing the **computation**.

This is where MatterScript begins to diverge from conventional programming languages. In many compilers, the AST remains the central representation throughout optimization and code generation. In MatterScript, it is only a stepping stone. Once the association graph has been constructed, the compiler has recovered the true structure of the program, and from that point onward every optimization, transformation, and backend operates on relationships rather than on source code.


In later chapters, when we introduce the `spatial3d` domain, we will discover that geometry is parsed into the same abstract syntax tree as every other MatterScript construct. The compiler makes no fundamental distinction between a logic gate, a chemical transform rule, or a geometric primitive. They are all simply structured descriptions waiting to be transformed into a common association graph.

*Drafting in progress...*
