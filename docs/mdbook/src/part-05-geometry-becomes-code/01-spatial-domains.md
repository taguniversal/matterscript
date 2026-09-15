# Spatial Domains: Geometry Construction Inside IPL

## 1. Motivation

The Invocation Language describes causal relationships — completeness, fills,
invocations — with no inherent notion of space. 
Some definitions, however, need to describe *where* things are: point coordinates, connectivity between
points, and eventually surfaces and volumes. 
Rather than inventing a second language for this, MatterScript introduces the `@domain` directive so
that a definition can bring a set of domain specific functions into scope, in this case for geometry-construction, and lets those functions build up a **parallel, loosely linked geometry graph** alongside the definition's ordinary causal-network AST.

The two ASTs are kept deliberately separate:

- The **IPL network AST** (`network.Definition`, `network.Statement`, ...)
  is unchanged by any of this. No new grammar, no new statement kinds.
- The **spatial graph** (`spatial.SpatialGraph` — points, edges, loops,
  faces) is built by a resolution pass that walks an already-parsed
  definition and interprets certain fills as geometry calls.

How the two ASTs are eventually drawn together at emission time (VHDL or
otherwise) is future work and is explicitly out of scope for this document.
This article covers parsing and resolution only.

## 2. Scoping: `@domain` brings functions into scope

A definition already declares its domain once, in its header:

```
Shape[
  ()
  ()
  @domain(spatial3d)
  ...
]
```

`@domain(spatial2d | spatial3d)` is existing IPL syntax
(`network.parseDomainSpec`), previously used only to parametrize
cellular-automata generate blocks. It now does double duty: when a
definition's `domain_spec.kind` is `spatial2d` or `spatial3d`, that
definition's resolution body is understood to have a set of
domain-specific geometry functions in scope — currently `point` and
`edge` (see §5 for what's deliberately not covered yet).

This means there is no per-statement annotation to sprinkle through a
definition's body. The domain is declared once, at the top, exactly like
any other `@domain` usage already in the language.

`spatial1d` is **not** a geometry domain — it remains scoped to its
existing cellular-automata usage and has no function registry. Declaring
`@domain(spatial1d)` and then calling `point(...)` inside it is treated as
an ordinary (undefined-function) fill, not a geometry binding.

## 3. Binding: geometry calls are ordinary fills

No new syntax was introduced for defining a geometry entity. This is
already-legal IPL:

```
p0<point(0.0, 0.0, 0.0)>
```

This is parsed today as an ordinary `Statement.fill`:

```
dest_name: "p0"
expr:      "point(0.0, 0.0, 0.0)"
parsed_expr: Expr{ kind: .call, func: "point", args: [...] }
```

The IPL parser (`expressions.parseILExpr`) already recognizes
`name(args...)` inside `<...>` and produces a structured `.call`
expression — this was true before any of the spatial-domain work began.
The resolution pass (§6) is what gives that structure new meaning when
the enclosing definition is domain-scoped to `spatial2d`/`spatial3d` and
the call's function name matches something in the registry; outside that
context, the exact same syntax continues to behave exactly as it always
has.

## 4. Reference: `$name` connects to an existing binding

To connect a new geometry call to a point (or other entity) defined
earlier in the same definition, use `$name` — the same sigil IPL already
uses everywhere else to mean "look this up" rather than "declare this"
(composed table keys, generate-block variables, ordinary fill
expressions):

```
p0<point(0.0, 0.0, 0.0)>
p1<point(1.0, 0.0, 0.0)>
e0<edge($p0, $p1)>
```

`$p0` and `$p1` parse as `.variable` expression nodes (distinct from the
`.constant` nodes that plain numeric literals produce — see §7), and the
resolution pass looks them up in the definition's geometry-binding table
built so far.

## 5. Binding semantics: define once, reference many times

A name may be bound to a geometry handle **exactly once**. After that
first binding, it is immutable — later statements may reference it via
`$name` as many times as needed (to build further edges, and eventually
loops and faces through it), but nothing may redefine what `p0` refers to.

Concretely:

- The first `p0<point(...)>` encountered binds `p0` to a new
  `spatial.PointId` in the resolution pass's binding table.
- Any later `$p0` reference resolves to that same handle.
- A second `p0<point(...)>` statement — an attempt to rebind an
  already-bound name — is rejected with `error.DuplicateGeometryBinding`,
  not silently overwritten and not silently ignored.

This mirrors ordinary single-assignment conventions and matches how a
geometry graph is naturally authored: declare the points that matter,
then wire connectivity between them by reference, without ever having to
worry that a later statement quietly changed what an earlier name meant.

## 6. Resolution: a single top-to-bottom pass

Geometry binding happens in a dedicated resolution pass
(`spatial_domain.resolveSpatialBindings`), run over an already-parsed
`network.Definition` — it does not run during parsing, and it does not
alter the parser's output. The pass:

1. Confirms `def.domain_spec` is `spatial2d` or `spatial3d` (returns
   `error.UnsupportedSpatialDomain` for `spatial1d`, `error.MissingDomainSpec`
   if there's no domain at all).
2. Walks `def.resolution` in source order. For each `.fill` statement
   whose `parsed_expr` is a `.call` matching a name in the domain's
   function registry, it dispatches to that function's handler, which
   builds the corresponding entity in a `spatial.SpatialGraph` and
   returns a `GeometryHandle`.
3. Records the handle against the fill's `dest_name` in a
   `std.StringHashMapUnmanaged(GeometryHandle)` binding table — this
   table, together with the `SpatialGraph`, is the definition's
   "geometry AST," addressed by the same names the IPL source uses.
4. Fill statements whose call name isn't in the registry are left
   untouched, for ordinary fill-resolution logic elsewhere to handle.

Because this is a single forward pass, **a name must be bound before it
is referenced**. `edge($p0, $p1)` written before either point is defined
is a forward reference and is not currently supported — `$p0` would
resolve against an empty binding table and fail with
`error.UndefinedGeometryReference`. This matches how CAD/geometry source
is naturally written (points, then the things that connect them), so in
practice it isn't a real constraint on authoring — just documented here
since it isn't enforced by any grammar rule, only by pass order.

## 7. Argument shapes

Two argument shapes matter for the currently-implemented functions:

- **Numeric literals** (`point(0.0, 0.0, 0.0)`'s arguments) arrive as
  `Expr{ .kind = .constant, .name = "0.0" }` — the raw text, not a
  pre-parsed number. `resolveCoord` parses this with
  `std.fmt.parseFloat(f64, ...)`. This is a property of
  `parseILCallArgument`, not something specific to the spatial domain —
  worth knowing if you add a function whose arguments need different
  types.
- **Name references** (`edge($p0, $p1)`'s arguments) arrive as
  `Expr{ .kind = .variable, .name = "p0" }`. `resolvePointRef` looks the
  name up in the binding table and type-checks that the bound handle is
  the kind the function expects (e.g. `edge` requires two `.point`
  handles, not `.edge` handles).

## 8. Current scope and what's deliberately not decided yet

Implemented today: `point` and `edge`, for `spatial2d` and `spatial3d`
domains, with the binding/reference/immutability rules above.

```matterscript
  mobius_strip[()($f0, $f1, $f2, $f3) 
    @domain(spatial3d)
    // 1. Instantiating internal point sources (p0..p7)
    p0< point(1.0, 0.0, -0.2) >
    p1< point(1.0, 0.0, 0.2) >
    p2< point(0.0, 1.0, -0.2) >
    p3< point(0.0, 0.2, 0.0) >
    p4< point(-1.0, 0.0, -0.2) >
    p5< point(-1.0, 0.0, 0.2) >
    p6< point(0.0, -1.0, 0.0) >
    p7< point(0.0, -0.2, -0.2) >

    e1<edge($p0, $p1)>
    e2<edge($p1, $p3)>
    e3<edge($p3, $p2)>
    e4<edge($p2, $p0)>

    l0<loop($e1, $e2, $e3, $e4)>
    f0<face($l0)>
    :
]
```

- **`loop` and `face`** are implemented, following the exact same
  `name<func(...)>` define / `$name` reference discipline as `point` and
  `edge` — no exceptions, no inline/nested form. `loop` takes
  `$`-references to already-bound edges (`loop($e0, $e1, $e2)`); `face`
  takes a single `$`-reference to an already-bound loop (`face($l0)`).
  Every geometric element, at every level, is addressable the same way.

Explicitly **not yet designed**:

- **Emission.** Nothing here produces VHDL or any other output yet. The
  geometry graph exists purely as an in-memory resolution artifact
  alongside the IPL network AST. How (or whether) the two get drawn
  together for hardware emission is separate, later work.
- **Cross-definition references.** The binding table is scoped to a
  single definition's resolution pass; there's no mechanism yet for one
  definition's geometry to reference another's.

## 9. Example: a unit square

```
Shape[
  ()
  ($result)
  @domain(spatial2d)

  p0<point(0.0, 0.0)>
  p1<point(1.0, 0.0)>
  p2<point(1.0, 1.0)>
  p3<point(0.0, 1.0)>

  e0<edge($p0, $p1)>
  e1<edge($p1, $p2)>
  e2<edge($p2, $p3)>
  e3<edge($p3, $p0)>
]
```

After resolution, `SpatialGraph` holds 4 points and 4 edges, and the
binding table maps `p0`–`p3` and `e0`–`e3` to their respective handles —
ready for a future `loop`/`face` pass to close this into a boundary, once
that design is settled.


*Drafting in progress...*
