# VHDL Generation

![VHDL Generation](images/VHDL_Generation.png)

> *One-line thesis for the chapter: a definition's VHDL architecture is determined by one question — where does its output come from? — and the whole emitter is organized around answering it once.*

# 1. Why emission is a classification problem

The naive view of a compiler is a pipeline: source text goes in, an abstract syntax tree comes out, and then the emitter translates the AST into the target language. Each phase does one thing, and the phases are independent. Parsing is parsing, emission is emission, and never the twain shall meet.

That view is accurate about the *stages* and wrong about the *work*. Parsing a MatterScript definition produces an AST with a specific, non-obvious shape — contained rows, resolution statements, destination kinds, runtime annotations, domain specs, generate blocks — and the emitter's job is not "translate the AST into VHDL." The emitter's job is to translate the AST into *the right kind* of VHDL for *this* definition. Different definitions in the same file need structurally different architectures. The naive pipeline view has no place to put that decision, and so the pre-TAG-229 code scattered it across every phase: guards in the emitter, flags threaded through function signatures, conditionals inside the lookup writer, conditionals inside the transform-rule writer, and a small predicate in `value_transform.zig` that one of the emitters had to call.

TAG-229 replaced that scattering with one function. This chapter is about that function, and about why the question it answers — *where does a definition's output come from?* — is the right organizing principle for a VHDL emitter, and for the parser→VHDL pipeline in general.

## The wrong question

The wrong question is "what does this definition look like?" It invites syntactic answers. Does it have contained rows? Does its resolution start with `.pure_value`? Are the row names comma-separated? Does the destination have a group kind? Each question is answerable from the AST, and each has been used, at some point, as the dispatch condition for one of the three emission paths.

The problem with syntactic answers is that they are *local*. "Has contained rows" is a fact about the definition's syntax. It does not tell the emitter what to *do* with the definition. It certainly does not tell the emitter which of the three paths is correct. The pre-TAG-229 code was full of syntactic predicates that were used as proxies for the real question, and the real question was left implicit.

Two syntactic definitions can have the same surface shape and need different emissions. Two definitions can have different surface shapes and need the same emission. The syntactic predicate that picks one path for the first pair also picks it for the second, and one of the two is wrong. That is exactly the `fanout` problem — `fanout` and `fanin` are syntactic near-twins that need opposite emissions, and no syntactic predicate can distinguish them.

The right question is structural. It is not "what does this definition look like?" but "where does the output come from?" The answer is not a syntactic predicate. It is one of a small number of *kinds of answer*, each of which corresponds to a distinct emitter architecture.

## The four answers

Ask the question of every definition in the 32 examples, and a small number of answers emerge. The definitions fall into four groups.

**From a lookup on the inputs.** The definition maps a combination of its source values to an output symbol, and the mapping is expressed as a table. `AND@142` is the canonical case: two sources, one destination, four contained rows corresponding to the four input combinations, each row resolving to the output value for that combination. The output is a function of the inputs, and it is expressed directly as a lookup.

**From invoking sub-definitions.** The definition delegates to other definitions. `WRAP@218` is the simplest case: one source, one destination, one `.invoke` statement. The output is whatever the invoked definition produces, routed through the invoking definition's own ports. `4BITADD@211` is the same shape with four instances. The output is a composition of sub-outputs.

**From a constant.** The definition's output is fixed, independent of inputs. `MYCONST` and some geometry primitives are the cases in the 32. The output is a literal value or a synthesized place with a fixed token. There is no computation; there is a value.

**From nothing.** The definition has no output at all, or its output is entirely determined by something other than rule emission — geometry, directives, validation-only constructs. `fanout@147`'s shape, in its current form, is here: the definition has destinations, but the emitter has no template for its structure, and `.none` is the honest answer. Some geometry primitives are here too: their behavior is elaborated elsewhere and needs no architecture body.

Four answers. Not four emitters — three of the four answers are handled by existing emitters, and the fourth (`none`) is handled by emitting nothing. But four *kinds of output origin*, and every definition in the corpus has exactly one of them.

## Why four, and not three or five

The number is not arbitrary. It comes from the grammar itself.

Every MatterScript definition has the same four sections: `NAME[(sources)(destinations) resolution : rules]`. Each section has a natural role:

- **`sources`** — the inputs.
- **`destinations`** — the outputs, and their kinds (place, group, unnamed).
- **`resolution`** — the wiring: which sources feed which destinations, and via what computation.
- **`rules`** (after `:`) — the lookup table.

The four shapes are exactly the four ways `resolution` and `rules` can combine to produce the destinations:

- **Lookup** — `rules` is non-empty, and `resolution` says "route the inputs through the table." The output comes from a table over the inputs.
- **Invocation** — `resolution` contains `.invoke` statements (possibly plus fills wiring them together), and `rules` is empty or belongs to sub-definitions. The output comes from other definitions.
- **Constant** — `resolution` says "drive the output to this fixed value," and `rules` is empty. The output comes from a literal.
- **Nothing** — no destinations, or the shape is unrouted. The output comes from nothing the emitter needs to express.

That is the exhaust. There is no fifth way for a definition to combine `resolution` and `rules`, because those two sections are the only places a definition's output can come from, and their combination possibilities are constrained by the grammar's structure.

The five-shape enum in the classifier is the four answers, with lookup split into two emitter paths (`contained_lookup` and `lowered_rules`). That split is a refinement — both are the same answer, "from a lookup on the inputs," handled by two sub-emitters because the two sub-emitters have different preconditions and produce different (though similar) VHDL. The four-shape model is the conceptual frame; the five-shape enum is the implementation.

## Why this is the right level of classification

The classifier could go finer. It could distinguish `contained_lookup` with composed row names from `contained_lookup` with fill-keyed rows from `contained_lookup` with pure-value-keyed rows — and in fact the `LookupKey` refinement does exactly that, but at the sub-emitter level, not in the classifier's return type. It could distinguish `invocations_only` with one instance from `invocations_only` with a chain of instances. It could distinguish `transform_rules` with a single destination from `transform_rules` with multiple. All of those distinctions exist in the code.

The classifier does not make them, because none of them change the answer to "where does the output come from?" A `contained_lookup` by any key form still comes from a lookup on the inputs. An `invocations_only` by any chain length still comes from sub-definitions. A `transform_rules` definition by any destination count still comes from a formula over the inputs. The classification's purpose is to separate the *architectures*, and the architecture is determined by the origin, not by the details of how the origin is expressed.

The classifier could also go coarser. It could collapse `contained_lookup` and `lowered_rules` into one shape ("lookup"), and let the sub-emitter decide which path to take. That would mean the classifier returns four shapes instead of five, and one of them has two implementations under one label. The reason not to do this is that the choice between `contained_lookup` and `lowered_rules` is *not* a sub-emitter decision — it is decided by whether `decomposeRules` and `isLowerableShape` succeed, and those are not the sub-emitter's business. Making the classifier return a single `lookup` shape would move that decision back into the emitter, which is exactly what TAG-229 was built to avoid.

The five-shape model is the right level because it is the *minimum classification that separates the major code paths*. No finer classification changes which code path is taken; no coarser classification preserves the separation of concerns.

## What goes wrong without this

The pre-TAG-229 code is the empirical demonstration. Its three emission paths — `lowerRules`, `writeContainedLookupTable`, `writeTransformRules` — were coordinated by booleans threaded through function signatures and guards inside each writer. For definitions that satisfied exactly one path's preconditions, the code worked. For definitions that satisfied more than one, the code fired both and relied on the outputs agreeing. For definitions that satisfied none, the code emitted nothing, and the definition's behavior was whatever the emitter happened not to say.

The overlap set — `NOT@129`, `OR@129`, `fourstate@137`, `AND@142/143/190/212`, `OR@149`, `OR180@160`, `test@185`, `AND2`, `AND142` — is the concrete demonstration. Twelve definitions in the corpus had two paths firing. They passed because the two paths produced the same values on the same signals, and GHDL accepted the duplicate drivers as identical. A single rule change would have made them disagree; a single emitter refactor could have changed the emission order and produced a different last driver; a single new example could have added a thirteenth case where the two paths do not agree. The code was correct by accident, and the accident was load-bearing.

The classifier removes the accident. There is one decision per definition, one answer, and one emitter. The overlap set is now `contained_lookup` only — the `transform_rules` driver is shed, the VHDL is shorter, the netlist is unchanged, and the correct behavior is guaranteed by construction rather than by coincidence. The twelve definitions are still correct; they are now correct *on purpose*.

## The chapter's argument, in one paragraph

The rest of this chapter is the argument that one classification function can organize an entire VHDL emitter. The function answers one question — where does a definition's output come from? — with one of five shapes. The emitter translates each shape to one of five architectures. The parser produces an AST that the classifier can read; the runtime dispatches separately; the backend writes VHDL. Each layer has one job, and the classifier is the wall between the front end (parser, AST) and the back end (emitter, architecture). That wall is what makes "two paths both fire" and "no path fires for a shape that should be handled" structurally impossible. It is also what makes the chapter writable: five shapes, five templates, five architectures, one classifier, one question.

The remaining sections unpack that paragraph. §2 describes the AST the classifier sees. §3 walks the classifier's decision order. §4 presents the five templates. §5 uses the `fanout` case to make "shape is structural, not syntactic" concrete. §6 tells the overlap story. §7 says what the classifier deliberately does not decide. §8 walks one example through the whole pipeline. §9 looks forward.

# 2. The AST the classifier sees

The classifier's input is a `network.Definition` and the value-transform rules collected from its contained rows. That is the whole of its interface. It does not see the parser, the source text, the emitter, the target backend, or the writer. It sees a struct and a slice, and it returns an enum. Understanding the classifier therefore begins with understanding what the struct carries — which fields bear on the shape question, and which are along for the ride.

The struct is defined in `network.zig`. It is the parser's output and the classifier's input, and it is the boundary the rest of the pipeline is organized around: everything upstream of it produces `Definition`s, and everything downstream consumes them. The classifier sits at the boundary and asks its one question of the fields that matter.

## The fields that matter

Six fields of `network.Definition` bear on the shape question. The rest — `name`, `domain_spec`, `runtime_kind`, `generateBlock`, `constants` — are either orthogonal to shape or handled by the classifier's early checks before they can affect the answer.

```zig
pub const Definition = struct {
    name: []const u8,
    sources: []const Arg,
    destinations: []const Arg,
    domain_spec: ?DomainSpec = null,
    runtime_kind: ?RuntimeKind = null,
    generateBlock: ?GenerateBlock = null,
    resolution: []const Statement,
    constants: []const TableDef,
    contained: []const Definition = &.{},
};
```

The six shape-relevant fields are `sources`, `destinations`, `resolution`, `contained`, and — via the collected rules — the `pure_value` and `fill` statements inside `resolution` and `contained`. The remaining fields are either checked before the classifier commits to a shape (as `runtime_kind` is, in the bare-bracket ambiguity check) or not consulted by the classifier at all.

The AST is also *recursive*: a `Definition`'s `contained` field is a list of `Definition`s. This is the recursion that lets a definition carry a lookup table, a set of nested sub-networks, or a flat set of transform rules inside its own brackets. The classifier's `contained` checks are shallow — they look at the immediate children, not their descendants — because a contained row is either a lookup row or a nested definition, and its own contained children are not the classifier's concern. If a nested definition is present, the validation layer will reject it before the classifier is asked about the parent.

## `sources` and `destinations`: the shape's frame

`sources` and `destinations` are `[]const network.Arg`, and each `Arg` has a `kind` field:

```zig
pub const ArgKind = enum { place, literal, expression, group };
```

For the classifier, the relevant distinction is `place` versus `group`:

- A **place** is a single named port — `X<>`, `ms_result<>`, `$result`. It receives or emits one value.
- A **group** is a bundle, mutex, or arbitration set of places — `{out1<> out2<> out3<> out4<>}`, `[A0<> A1<> A2<> A3<>]`. It receives or emits a set of values, and the group's `kind` (bundle, mutex, arbitration) governs how those values compete or coexist.

The classifier consults `destinations` three times:

1. `destinations.len == 0` → `.none`. No destinations, no output to emit.
2. `destinations.len == 1 and def.contained.len > 0` → the lowering check. Lowering requires a single destination.
3. `destinations[0].kind == .group` → the group-destination refinement guard. If the destination is a group, the case selector must be buildable from the contained rows' names; if not, return `.none`.

`sources` is consulted less directly. It is used by `containedRowNamesAreComposedKeys`, which checks whether the contained rows' names have the same number of comma-separated segments as `def.sources.len`. If they do, the row names can be composed into a case selector over the sources. If not — as in `fanout`, where the row names are `A`, `B`, `C`, `D` and there are two sources — the selector cannot be built, and the group-destination guard fires.

The source count is also consulted by `decomposeRules` and `isLowerableShape`, which the classifier delegates to during the lowering check. Those functions compare `def.sources` against the rule set to determine whether the rules form a total function over the source value space. The classifier does not duplicate that check; it calls the same functions the emitter will call.

## `resolution`: the wiring

`resolution` is `[]const Statement`, and each `Statement` is one of four variants:

```zig
pub const Statement = union(enum) {
    fill: SourceFill,
    invoke: Invocation,
    pure_value: []const u8,
    directive: Directive,
};
```

The classifier's `hasInvoke` and `hasFillOrPure` helpers scan `resolution` for `.invoke` and `.fill` / `.pure_value` statements respectively, and their results drive the second and third checks:

- All `.invoke`, no `.fill` or `.pure_value`, no contained rows → `.invocations_only`.
- No `.fill`, no contained rows, no useful `.pure_value` composition → `.none`.

The distinction between `.fill` and `.pure_value` is one of the sub-classifications the classifier does *not* make at the shape level. Both contribute to "lookup on the inputs"; the difference between them is whether the lookup is expressed as a fill composition or a pure-value composition, and that difference is carried by `LookupKey`, not by `EmissionShape`. This is deliberate — §3 covered why — but it means the classifier's `resolution` checks are coarser than the AST's statement variants. The classifier sees "any `.fill` or `.pure_value`" where the AST distinguishes two kinds of statement.

The `.invoke` variant is consulted for its name in `checkInvocations` (in the validation layer), but the classifier only checks for the presence of `.invoke` statements, not their contents. If the definition is all invocations, the classifier returns `.invocations_only`; it does not inspect the invoked definitions. That is the validation layer's job, and by the time the classifier runs, the validation layer has already ensured the invoked definitions exist.

The `.directive` variant is not consulted by the classifier. Directives describe domain specs, generate blocks, runtime annotations, and other metadata; they do not affect the origin of the output. A definition with a generate block has the same shape as one without, if everything else is equal.

## `contained`: the table

`contained` is `[]const Definition` — a list of nested definitions. This is the field that most distinguishes MatterScript from a conventional language, and it is where the classifier's `contained_lookup` shape is born.

Each contained entry is a `Definition` with its own `name`, `sources`, `destinations`, and `resolution`. The classifier's `allContainedAnonymous` helper checks the `sources` and `destinations` of every entry: if any entry has a non-empty `sources` or `destinations`, it is not anonymous — it is a nested sub-network, not a lookup row. If every entry is anonymous, the list is a candidate for the contained-lookup shape.

The contained entries' `name` fields are also relevant. `containedRowNamesAreComposedKeys` splits each entry's name on commas and checks whether the segment count matches `def.sources.len`. If every entry's name has that many segments, the row names can be composed into a case selector; if not, the group-destination guard may fire. This is the check that distinguishes `fanout`'s row names from `AND@142`'s.

The `resolution` of a contained entry is scanned by `composedKeyPresent` for a `.fill` or `.pure_value` statement. A contained entry with no `.fill` and no `.pure_value` in its resolution is not a lookup row; the classifier does not need to know what it is, but it does need to know that it is not a key-value pair.

`collectValueTransformRules` walks the contained entries and produces the `[]const ValueTransformRule` slice that the classifier receives as its third argument. A `ValueTransformRule` has an `inputs` list and a `targets` list, both extracted from a contained entry's name and resolution. The collected rules are the classifier's third input, and their presence or absence — not the contained entries' raw `resolution` — drives the `.transform_rules` check.

## The fields that do not matter (and why)

Five fields are not consulted by the classifier at the shape level.

**`name`** — the definition's own name. Shape is about the definition's structure, not its identity. Two definitions with the same name and different shapes are both valid definitions (the validation layer rejects the duplicate, but that is a separate concern).

**`domain_spec`** — the spatial domain, if any. A domain spec says where the definition's computation happens, not where the output comes from. A definition with a domain spec has the same shape as one without.

**`runtime_kind`** — the runtime annotation. This is consulted in *one* place, the bare-bracket ambiguity check that the parser runs before it produces the definition. The classifier sees the result of that check (the definition either parsed or did not), and does not re-consult `runtime_kind` for shape decisions.

**`generateBlock`** — the generate block, if any. Generate blocks are a way of specifying rules parametrically; they are resolved into the same contained-row structure as explicit rules, and the classifier sees the result, not the block. A definition with a `generateBlock` and no `contained` rows has no rules to emit, and classifies as `.none` or `.invocations_only` depending on its resolution.

**`constants`** — the constant tables, if any. These are `$`-composed tables that the emitter handles separately from rule emission. The classifier does not consult them; a definition with constant tables and no rules classifies by its other fields.

The fact that these fields are not consulted is a design decision, not an omission. Each describes a feature orthogonal to "where does the output come from?" `domain_spec` and `generateBlock` describe *where* and *how*, not *what*; `runtime_kind` and `constants` describe *other emission paths* that the classifier routes elsewhere. The classifier's focus on the six shape-relevant fields is what keeps it under a hundred lines and testable in isolation. A classifier that consulted all eleven fields would be doing the emitter's job.

## The classifier's view of the AST

A reader who has followed this far can now picture the AST the classifier sees: a definition with six shape-relevant fields, each answering a specific question:

- `destinations.len` — does emission happen at all?
- `destinations[0].kind` — if emission happens, is the destination a single place or a group?
- `resolution` — is the output wiring, and if so, of what kind?
- `contained` — is there a table, and are its rows anonymous?
- `contained[].name` — can the rows' names compose a case selector?
- `transform_rules` — are there rules to emit?

The classifier's decision order is the sequence of questions that turns those fields into one of five shapes. It is a small state machine over a small set of inputs, and every input is a fact about the definition's structure. The classifier's output is deterministic — the same definition always produces the same shape — and pure — no emitter state, no backend, no writer.

That is the AST the classifier sees, and that is why the classifier is testable in isolation: the AST is a self-contained description of the definition's shape-relevant structure, and the classifier is a self-contained function over that structure. The next section walks the decision order that function implements.


# 3. `classifyEmissionShape` — the single decision point

By the time a definition reaches the emitter, the parser has already done its work. The `.ms.ipl` source has become a `network.Definition` — a struct with a name, a source list, a destination list, a resolution area, a set of contained rows, and a handful of directives. What the emitter needs to know, before it writes a single line of VHDL, is which of the five architecture templates this definition calls for.

That question is answered in one place. The function is `classifyEmissionShape`:

```rust
pub fn classifyEmissionShape(
    allocator: std.mem.Allocator,
    def: network.Definition,
    transform_rules: []const value_transform_analysis.ValueTransformRule,
) !EmissionShape
```

It takes a definition and the value-transform rules already collected from its contained rows, and returns exactly one of five shapes:

```rust
pub const EmissionShape = enum {
    contained_lookup,
    lowered_rules,
    transform_rules,
    invocations_only,
    none,
};
```

Each variant answers "where does this definition's output come from?" in a different way:

- **`contained_lookup`** — the output is a table indexed by the inputs. The table comes from the definition's contained rows, keyed either by a `.fill` composition or a `.pure_value` composition. One case block per destination.
- **`lowered_rules`** — the same idea, but the rules lower cleanly to a case block over `def.sources` with a single destination and no contained-row ambiguity. The output is still a table, but the emitter can go straight to a case statement without going through the contained-row machinery.
- **`transform_rules`** — the output is an OR-of-ANDs validity formula over the inputs. This is the fallback shape for multi-destination definitions and any other case the first two paths don't route.
- **`invocations_only`** — the output is whatever the sub-invocations produce. The definition's own resolution is wiring; no table, no formula, only component instantiation.
- **`none`** — nothing to emit. The definition has empty resolution, is pure geometry, is a constant with no emission, or is a shape the emitter does not yet route.

There is a sixth enum in the same module — `LookupKey { contained_rows, composed_fill, composed_pure_value }` — but it is *not* a shape. It is a refinement *within* `contained_lookup`, telling the sub-emitter which of three ways to key its case selector. The classifier never returns a `LookupKey`; it returns `contained_lookup` and lets the lookup writer pick the key form. The distinction matters because the shape question ("where does the output come from?") and the key question ("how is the table indexed?") are different questions, asked at different levels, and conflating them was one of the coordination bugs the classifier exists to prevent.

## The decision order

The classifier is a sequence of seven checks, each eliminating one possibility. The ordering is not arbitrary: each step is placed where it is because a later step would misinterpret a definition that the earlier step already answered correctly. Reading the order top to bottom is reading the reasons the classifier works.

**1. `destinations.len == 0` → `.none`.**

A definition with no destinations has no output to emit. This is the geometry primitives, the pure constants, the directive-only definitions. There is nothing to answer "where does the output come from?" for, because there is no output. First check, because every subsequent check assumes at least one destination to fill.

**2. All-invoke resolution, no fills, no contained rows → `.invocations_only`.**

If the resolution is entirely `.invoke` statements, and there are no `.fill` statements and no contained rows, then the definition's output comes from whatever the sub-invocations produce. There is no table to lower, no formula to synthesize — the whole definition is a wiring diagram, and the emitter's job is component instantiation. Second check, because a definition that is purely invocations should never reach the lookup machinery: with no contained rows, the lookup writer would have nothing to key on, and with no fills, there is no table to build.

The "no contained rows" clause is doing real work. A definition can have `.invoke` statements *and* contained rows — a lookup table that is populated by invocations, or an invocation whose result is then indexed. Those cases need lookup emission *plus* component instantiation, and they should reach the lookup paths, not the invocation-only path. The check excludes them.

**3. No contained rows and no fills → `.none`.**

At this point we know there are destinations, and we know the resolution is not purely invocations. If there are also no contained rows and no `.fill` statements, then there is nothing for any emitter to do: no table to lower, no formulas to synthesize, no fills to drive the outputs. This catches constants, pure `.pure_value` statements that the emitter does not route, and any geometry shape that slipped past check 1. Third, because it is the last cheap exit before the classifier commits to a lookup-shaped path.

**4. Single destination, contained rows, decomposable and lowerable → `.lowered_rules`.**

Now we are committed to some form of rule emission. The question is which form. The classifier checks the lowering path first:

```rust
if (def.destinations.len == 1 and def.contained.len > 0) {
    if (try rules.decomposeRules(allocator, def)) |rule_set| {
        if (value_transform_export.isLowerableShape(rule_set)) {
            return .lowered_rules;
        }
    }
}
```

This step calls *the same functions* the old dispatch used — `decomposeRules` and `isLowerableShape` — rather than reimplementing their conditions. That is deliberate: a `Definition`-level reimplementation of "is this lowerable?" diverges from the real answer in subtle cases (`CODE`, `NOT`), because lowering depends on the *rule set* produced by decomposition, not just on the shape of the definition. The classifier delegates to the same predicate the emitter will use, so the answer it gives is the answer the emitter would have reached.

Fourth, because the lowering path only fires for single-destination definitions with contained rows. A multi-destination definition cannot be `.lowered_rules` no matter what its rules look like — the case block needs a single destination to write to. If we checked this later, we would produce a `.lowered_rules` verdict for a shape that cannot lower, and the emitter would fail.

**5. Composed-key lookup with contained rows → `.contained_lookup`.**

If lowering did not apply, the classifier checks the contained-lookup path:

```rust
if (allContainedAnonymous(def.contained) and
    composedKeyPresent(def.contained) and
    def.contained.len > 0)
{
    if (def.destinations[0].kind == .group and
        !containedRowNamesAreComposedKeys(def))
    {
        return .none;
    }
    return .contained_lookup;
}
```

The three positive conditions are: every contained row is anonymous (no sources, no destinations of its own — a lookup row, not a nested sub-network); at least one row carries a `.fill` or `.pure_value` composition; and there is at least one row. These are the necessary and sufficient conditions for `writeContainedLookupTable` to have something to write.

The negative condition inside is the group-destination refinement guard. When the definition's destination is a *group* (a bundle, mutex, or arbitration set) and the contained rows' *names* are single tokens rather than composed keys over `def.sources`, the case selector cannot be built. The row names are the case labels; if they are `A`, `B`, `C`, `D` rather than `0,0`, `0,1`, `1,0`, `1,1`, there is no way to select on them. Returning `.contained_lookup` for such a shape would produce an empty-destination case block — exactly the bug the classifier exists to prevent. So the guard returns `.none` explicitly.

Fifth, after lowering has been ruled out, because a definition that *could* lower should lower — the lowered form is tighter and the VHDL is cleaner — and a definition that cannot lower but is lookup-shaped falls to this step as the next-best answer.

**6. `transform_rules.len > 0` → `.transform_rules`.**

If lowering failed and the contained-lookup shape did not match, but there are transform rules to emit, the classifier returns the OR-of-ANDs path. This is the multi-destination `.fill`-over-anonymous-rows shape (`FULLADD` in TAG-177/198/211), the shapes that have rules but no single destination to write them to as a case block, and the older fallback shapes. Sixth, because it is the fallback — the answer of last resort for a definition that has rules to emit but does not fit either of the more specific shapes.

**7. Else → `.none`.**

If none of the above matched, the definition has rules the emitter does not route, or no rules at all. Return `.none`. Seventh, as a total function — every possible input produces a shape, and every shape is the result of exactly one check succeeding.

## Why mutual exclusivity is the whole point

The classifier's return type is a single enum, not a struct of booleans. That is the entire design.

The pre-TAG-229 emitter had three dispatch paths coordinated by booleans: `lowered` threaded through `writeDestinationFills`, `lookup_shape` tested inside `writeContainedLookupTable`, `transform_rules` collected and passed to `writeTransformRules` independently. A definition could satisfy more than one condition. When it did, more than one path fired, and the outputs happened to agree — for now. When it didn't satisfy any condition, no path fired, and the definition emitted an empty architecture with no diagnostic. Both were coordination bugs, and both were invisible until an example happened to exercise the wrong combination.

The classifier eliminates both classes structurally. It returns exactly one shape. It cannot return two. It cannot return zero. The emitter dispatches on that shape and calls one sub-emitter — one, not two — and the definition's output is whatever that sub-emitter writes. "Two paths both fire" is not a condition the emitter can reach. "No path fires for a shape that should be handled" is not a condition either: the classifier returns `.none` for genuinely unrouted shapes, and `.none` is itself a decision the emitter respects, not an absence of decision.

The cost of this structure is that the classifier must be *complete* — every definition the emitter will ever be asked to emit must produce a shape that routes correctly. That is why the classifier is tested against all 32 examples in a table: the table is the proof of completeness, and any future shape addition is caught by the table's well-formedness test before it ships. The benefit is that the emitter can be read as five independent sub-emitters, none of which needs to know about the others. The classifier is the wall between them.


# 4. The five emission templates

The classifier returns one shape per definition. The emitter's job is now mechanical: for each shape, call one sub-emitter, and let that sub-emitter do the one thing its shape calls for. There are five shapes, so there are five templates. Each is presented here in the same form: a real example from the 32, the shape of the VHDL it emits, and what the template's characteristic structure is. The parallelism is the point — the five templates are not five unrelated bits of code; they are five ways of answering the same question, each with a distinct architecture.

The five templates are:

1. **`contained_lookup`** — a case block, one per destination.
2. **`lowered_rules`** — a case block, keyed directly on sources.
3. **`transform_rules`** — an OR-of-ANDs validity formula per target.
4. **`invocations_only`** — component instances only, no rule emission.
5. **`none`** — an empty architecture.

In the same order the classifier checks for them.

## 4.1 `contained_lookup` — the case block

**Example:** `AND@142`, `OR180@160`.

`AND@142` has two sources (`X`, `Y`), one destination (`ms_result`), a resolution area with one `.pure_value` statement (`$X$Y()`), and four contained rows: `0,0`, `0,1`, `1,0`, `1,1`, each resolving to a value. The row names are the composed key — two comma-separated values per row, matching `AND`'s two sources.

The emitted VHDL is a case block:

```vhdl
process(X, Y, complete) begin
  ms_result <= null_value;
  if complete = '1' then
    case X & Y is
      when "00" => ms_result <= data_value(0);
      when "01" => ms_result <= data_value(0);
      when "10" => ms_result <= data_value(0);
      when "11" => ms_result <= data_value(1);
      when others => null;
    end case;
  end if;
end process;
```

Three structural features. The **selector** is `X & Y` — the sources composed into a single value, matching the row names' segment structure. The **case arms** are the row names — `"00"`, `"01"`, `"10"`, `"11"` — each followed by the data value its row resolves to. The **completeness guard** (`if complete = '1'`) is the Fant completeness convention: the destination is only filled when the input side is complete, and the `null_value` default is what makes that explicit.

When the definition has *more than one destination* — `TAG163_TOP`'s case, with four destinations — the emitter writes *one case block per destination*, each with its own selector and its own set of case arms. The classifier returns `contained_lookup` regardless of destination count; the "one case block per destination" is a sub-emitter fact, carried by the `LookupKey` refinement.

The case-block template is the canonical lookup shape. It is what "output is a table indexed by inputs" *looks like* when translated to VHDL.

## 4.2 `lowered_rules` — the case block over sources

**Example:** `BINEQ@163`, `PARITY@217`.

`BINEQ@163` has two sources (`a`, `b`), one destination (`eq`), a resolution area with one `.pure_value` statement (`$a$b()`), and four contained rows: `FALSE,FALSE`, `FALSE,TRUE`, `TRUE,FALSE`, `TRUE,TRUE`, each resolving to `TRUE` or `FALSE`. This is the "set of definitions establishing correspondence" shape — the definition's contained rows are the entire truth table, keyed by the two sources.

`lowered_rules` looks like `contained_lookup` at the level of the emitted VHDL:

```vhdl
process(a, b, complete) begin
  eq <= null_value;
  if complete = '1' then
    case a & b is
      when "00" => eq <= data_value(0);  -- FALSE,FALSE
      when "01" => eq <= data_value(1);  -- FALSE,TRUE
      when "10" => eq <= data_value(1);  -- TRUE,FALSE
      when "11" => eq <= data_value(0);  -- TRUE,TRUE
      when others => null;
    end case;
  end if;
end process;
```

The selector, the arms, and the completeness guard are all the same shape as `contained_lookup`. The difference is *how the emitter got here*.

`lowered_rules` goes through `decomposeRules`, which converts the contained rows into a neutral `RuleSet` — the input symbol list per rule, the target symbol list per rule, with all the syntactic variation of the contained rows flattened out. Then `isLowerableShape` checks whether the `RuleSet` can be expressed as a case block over `def.sources` — single destination, no anonymous contained-row ambiguity, the rules form a total function over the source value space. When both succeed, `lowerRules` writes the VHDL.

`contained_lookup` skips `decomposeRules` and writes the case block directly from the contained rows, keyed by the `LookupKey` refinement. The two emit similar VHDL because they are solving the same problem — "the definition's output is a table" — through different paths. The classifier distinguishes them because `lowered_rules` has a stricter precondition (`decomposeRules` must succeed, and the rule set must be lowerable) and `contained_lookup` has a looser one (contained rows, composed key present, and — for group destinations — composed row names). When both paths could fire, `lowered_rules` is tried first, and `contained_lookup` picks up the definitions that lowering rejected.

The choice is not "which output looks nicer." It is "which path can the definition go through without being re-interpreted." `lowered_rules` proves that the definition is a case block over its sources; `contained_lookup` treats the definition's contained rows as a table without proving the table covers the source value space. For `BINEQ`, the proof succeeds, and `lowered_rules` is the honest template. For `AND@142`, the proof succeeds too — but `lowered_rules` would be less efficient than writing the case block directly from the four rows, and `contained_lookup` already has the right structure. The classifier returns whichever comes first in the decision order, and both are correct emissions of the definition's output.

## 4.3 `transform_rules` — the OR-of-ANDs

**Example:** `FULLADD@177`, `REACTION@201`.

`FULLADD@177` is a Boolean full adder expressed via value-transform rules. It has three sources, one destination group (`$SUM $CARRY` — two destinations), and 42 transform rules in its contained rows. The rules encode the full-adder's truth table as symbol assertions: "when symbols `A`, `g`, `k`, `o` are simultaneously present, assert `SUM` as `s`," and so on.

The emitted VHDL is a set of validity formulas, one per target:

```vhdl
SUM <= '1' when (A and g and k and o) or
                 (A and h and l and p) or
                 ... else '0';
CARRY <= '1' when (A and g and k and o) or
                   ... else '0';
```

Each rule becomes one AND-clause in the formula for its target; the target's formula is the OR of all its clauses. The output is a boolean expression that says "this target is high whenever any of its rules fire," which is a direct translation of the rule set into combinational logic.

The `transform_rules` template is the fallback. It fires when the definition's rules cannot lower (`decomposeRules` failed, or `isLowerableShape` rejected the rule set) and the definition does not fit the contained-lookup shape. The shapes that land here are the multi-destination definitions with rules over anonymous contained rows — `FULLADD`'s shape, and `REACTION@201`'s reaction rules — and the older shapes the emitter has not yet routed elsewhere.

The contrast with `contained_lookup` is the **destination count**. `contained_lookup` writes one case block per destination. `transform_rules` writes one formula per *target*, where a target may be a member of a multi-member destination. The two are not the same shape; the classifier distinguishes them because the destination structure drives the emission structure, and the two structures do not reduce to one another.

For a single-destination definition, `transform_rules` and `contained_lookup` would be near-synonyms — "output is high when any rule's inputs fire" versus "case block indexed by the inputs." For a multi-destination definition, they are not. `contained_lookup` would need one case block per destination; `transform_rules` needs one formula per target, and the formulas share their rule clauses. `FULLADD` is multi-destination, so it goes through `transform_rules`.

## 4.4 `invocations_only` — the component instantiator

**Example:** `WRAP@218`, `4BITADD@211`.

`WRAP@218` has one source (`A`), one destination (`Y`), and a resolution area with one `.invoke` statement: `INNER` instantiated with `A` on its source port and `Y` on its destination port. No contained rows, no rules, no fills. The definition's output is whatever `INNER` produces, routed to `Y`.

The emitted VHDL is a component instance:

```vhdl
u_inner: entity work.INNER
  port map (
    A => A,
    Y => Y
  );
```

No process, no case block, no formula. `WRAP`'s architecture is a port map, full stop. `INNER` was emitted separately as its own entity and architecture; `WRAP` just wires `INNER`'s ports to its own.

`4BITADD@211` is the same shape with four instances. Its resolution area invokes `FULLADDTEST211STEP4` four times, chaining them together — each instance's `SUM` output goes to one member of `4BITADD`'s group destination, and each instance's carry output feeds the next instance's carry input. The emitted VHDL is four component instances with their port maps chained.

`invocations_only` is the template for definitions whose output comes from *other definitions*. The emitter does not need to know what those definitions do — their entities are emitted independently, and the classifier has already confirmed that `WRAP` and `4BITADD` have nothing else to emit. The definition is a wiring diagram, and the VHDL is the wiring.

The contrast with `transform_rules` is direct. Both shapes can be multi-destination. Both can have complex resolution behavior. But `transform_rules` has rules to emit *in this definition's own architecture*, while `invocations_only` has no rules — the rules live in the invoked definitions, and they are emitted there. The classifier distinguishes them because the emitter's architecture body is a different thing for the two: a formula for `transform_rules`, a port map for `invocations_only`.

## 4.5 `none` — the empty architecture

**Example:** `MYCONST`, `fanout@147`.

`MYCONST` is a constant definition — no sources, no rules, no invocation, a fixed value on a synthesized destination. The classifier returns `.none`, and the emitter writes an empty architecture. There is nothing to emit.

`fanout@147` is the more interesting case, and §5 covers why: group destination, single-token row names, the case selector cannot be built. The classifier returns `.none`, and the emitter writes an empty architecture for the same reason — there is no template for this shape yet.

The empty-architecture template is not a placeholder for "we should emit something but don't." It is the correct emission for definitions that do not need architecture bodies. Some definitions are pure interfaces — their behavior is entirely in their port declarations. Some are geometry primitives, elaborated elsewhere. Some are constants that the emitter routes through a different path. For all of them, `.none` is the answer, and the emitter's correct action is to write nothing.

The temptation is to treat `.none` as a fallback — "we don't know what shape this is, so do nothing." That is exactly what `.none` is not. `.none` is the classifier's *decision* that this definition needs no architecture. The distinction between "no template applies, so fall through to nothing" (the pre-TAG-229 behavior) and "no template applies, and that is the correct answer" (the classifier's behavior) is the difference between accidental silence and deliberate silence. `MYCONST` needs no architecture; `fanout` needs one that the emitter does not yet have. Both classify as `.none`, and both emit an empty architecture, because both are shapes the emitter does not route — and routing nothing is the correct emission for a shape the emitter does not route. The classifier's comments say *why* each shape is `.none`, so that a future template can be added without ambiguity about which shape it is for.

## The template map

Five shapes, five templates, five architectures. In table form:

| Shape | Selector | Emits | Example |
|---|---|---|---|
| `contained_lookup` | Case on composed key | One case block per destination | `AND@142` |
| `lowered_rules` | Case on sources | One case block per destination | `BINEQ@163` |
| `transform_rules` | None (boolean) | OR-of-ANDs per target | `FULLADD@177` |
| `invocations_only` | None (port map) | Component instances | `WRAP@218` |
| `none` | None | Empty architecture | `MYCONST` |

The templates are not five variations on one theme. They are five distinct architectures, each corresponding to one answer to "where does the output come from?":

- A lookup answers "from a table over the inputs" — case block.
- A lowerable lookup answers "from a table the rules prove covers the inputs" — case block over sources, proven.
- A transform-rule definition answers "from a formula over the inputs" — OR-of-ANDs.
- An invocation-only definition answers "from a sub-definition's output" — component instance.
- Nothing answers "no output" — empty.

Each template is the direct VHDL translation of its answer. The classifier is what makes the translation *unique*: for each definition, exactly one answer is correct, and the emitter produces exactly one architecture. The five templates are the five architectures; the classifier is what selects among them.

That is the chapter's architecture, stated one more time. One classifier, five shapes, five templates, five architectures, all determined by one question: *where does the output come from?* The rest of this chapter walks the pipeline that implements it.


# 5. The `fanout` guard — shape is structural, not syntactic

Most of the classifier's decisions are unsurprising once you have the five-shape model in hand. A definition with contained rows and a single destination is a lookup; a definition with only invocations is invocations-only; a definition with rules that cannot lower is transform-rules. The classifier's logic reads like a restatement of what you already knew.

Then there is `fanout`.

`fanout` is the one definition in the 32 examples where the classifier's verdict is genuinely non-obvious. It has contained rows. One of them carries a `.fill`. Its resolution is a composed `.pure_value`. By any syntactic measure, it looks like a lookup-shaped definition, and the classifier should return `.contained_lookup`. Instead it returns `.none`.

Understanding why it returns `.none` — and why that is the *right* answer, not a fallthrough — is what separates "the classifier is a cleanup" from "the classifier is an architecture." `fanout` is the case that makes the difference visible.

## The definition

Here is `fanout` from TAG-147, abridged to its shape:

```
fanout[(select<> in<>)({out1<> out2<> out3<> out4<>})
  $select() $in:
  A[out1<$in>] B[out2<$in>] C[out3<$in>] D[out4<$in>]
]
```

The surface reading is straightforward. Two sources: `select` and `in`. A group destination with four members: `out1` through `out4`, bundled as a mutex. A resolution area with two `.pure_value` statements (`$select()` and `$in`). Four contained rows: `A`, `B`, `C`, `D`, each with a single `.fill` statement driving one of the group's members from `$in`.

A lookup, surely. The contained rows are a table; the row bodies route the input to one of four destinations based on the selector. This is what a lookup *is* — a mapping from a key to an output, expressed as rows. The classifier should classify it as `contained_lookup`.

It does not. The classifier's step 5 returns `.none`:

```rust
if (def.destinations[0].kind == .group and
    !containedRowNamesAreComposedKeys(def))
{
    return .none;
}
```

The reason is in the row *names*: `A`, `B`, `C`, `D`. Single tokens. Not composed keys.

## Why single-token row names matter

The contained-lookup emitter works by turning the contained rows into a `case` statement. The `when` arms are built from the row *names* — `when "00" =>`, `when "01" =>`, `when "10" =>`, `when "11" =>`. The case *selector* is built from the definition's sources — the inputs to the lookup.

For that to work, the row names must match the sources' value space. When `AND@142` has rows `0,0`, `0,1`, `1,0`, `1,1` and two sources `X`, `Y`, the selector is `X & Y`, and each row name is a valid value of that selector. The mapping is total: every input combination has a row, and every row has an input combination that selects it.

For `fanout`, the row names are `A`, `B`, `C`, `D`. These are not values of the source `select`. The source `select` has some value space — the definition does not say what — and the row names `A` through `D` do not name positions in it. They name cases. The `select` value is not `A`; it is some symbol that *selects* case `A`.

The emitter cannot build a case selector from that. It knows the row names (`A`, `B`, `C`, `D`), and it knows the sources (`select`, `in`), but it does not know how `select`'s values map to `A`, `B`, `C`, `D`. That mapping would have to come from somewhere — from a composed key in the resolution area, from a `.fill` composition, from a source declaration that says `select` takes values `A`, `B`, `C`, `D`. None of those are present. The definition is, from the emitter's point of view, underspecified: it says "when select is A, drive out1; when select is B, drive out2" without saying how `select` becomes A, B, C, D.

The pre-TAG-229 emitter did not know this. The `writeContainedLookupTable` guards had `destinations[0].kind == .place` to catch the group-destination case, but they did not check whether the row names could actually key the selector. For `fanout`, the group-destination guard fired, `writeContainedLookupTable` was skipped, and the definition fell through to `transform_rules`. The transform-rule path produced a set of OR-of-ANDs formulas for the fills — and those worked, because they did not need a case selector. They just said "when select is A, drive out1 from in" as a conditional formula.

That was correct behavior. But it was *accidental* correct behavior — the emitter did the right thing because two unrelated guards happened to align, not because it understood the shape of `fanout`.

## The structural reading

The classifier's reading is different. It says: `fanout` has a group destination, and its contained rows' names are single tokens. The case selector cannot be built from single-token names over an unspecified source value space. Therefore `fanout` is not a lookup in the sense the emitter's case-block template requires. It is a shape the emitter does not route. Return `.none`.

This is a *structural* claim, not a syntactic one. The syntax of `fanout` — contained rows, fills, pure values, a group destination — could belong to several shapes. The *structure* — the relationship between the row names and the source's value space — belongs to only one, and that one is not lookup. The classifier is answering "where does the output come from?" structurally: `fanout`'s output comes from routing an input to one of four destinations based on an unspecified selector, and the emitter has no template for that shape. `.none` is the honest answer.

Why does the answer matter, beyond correctness? Because `.none` is a *decision*, not a fallthrough. The classifier returns `.none` for `fanout` because of an explicit guard, and that guard documents a real structural condition: *group destination with single-token row names → the case selector is not buildable → the lookup template cannot apply.* If a future emitter *does* acquire a template for this shape — say, a selector enum derived from the source declaration — that template will have to be added as a new shape, and the guard will be the place it is introduced. The `.none` verdict is a placeholder for "unrouted shape, waiting for a template," not a shrug.

## The contrast with `fanin`

`fanin` — `fanout`'s dual, defined in the same examples — has the opposite shape, and the contrast is instructive.

```
fanin[(select<> in1<> in2<> in3<> in4<>)(out<>)
  $select() $in1 $in2 $in3 $in4:
  A[out<$in1>] B[out<$in2>] C[out<$in3>] D[out<$in4>]
]
```

Four sources, one destination. Row names `A`, `B`, `C`, `D`. The row bodies each route one of the four inputs to the single destination, selected by `select`. Same single-token row names; different shape.

`fanin` classifies as `.lowered_rules` — not `.contained_lookup`, not `.none`. The reason is that `fanin`'s rules lower cleanly to a case block over `def.sources` (specifically over `select`), with `out` as the single destination. The case arms are built from `select`'s value space, and the row names `A` through `D` are the *values* that `select` takes in the case — they are not lookup keys over `in1` through `in4`, they are the dispatch values of `select`.

The classifier's lowering step (step 4) sees this: single destination, contained rows, `decomposeRules` succeeds, `isLowerableShape` returns true. `fanin` classifies as `.lowered_rules`.

So `fanout` and `fanin` have the *same syntactic row names* (`A`, `B`, `C`, `D`) and the *same syntactic contained shape* (four rows, one fill each), but different shapes: `fanout` is `.none`, `fanin` is `.lowered_rules`. The difference is structural:

- `fanin`'s four rows map four inputs to one output via a selector. That is a case block over the selector, with the output as the destination. Lowerable.
- `fanout`'s four rows map one input to four outputs via a selector. That is *not* a case block — it is four separate drivers, each gated on a selector value, on a bundle of destinations. Not lowerable, and not lookup-shapeable (the destination is a group, and the row names cannot key the selector).

The classifier distinguishes the two because it asks "where does the output come from?" rather than "what does the syntax look like?" `fanin`'s output comes from a case selection over its inputs; the case arms are the input routes. `fanout`'s output comes from routing one input to one of four destinations based on a selector — a demultiplexer, not a table. The classifier's answer reflects that, and the answer drives different emission behavior.

## The general principle

`fanout` is the chapter's example of a general principle: **a shape is a structural claim, not a syntactic one.**

Syntactically, `fanout` and `fanin` are near-twins. They have the same row count, the same row names, the same number of fills per row, the same resolution shape. A syntactic classifier — one that checks `contained.len > 0`, `resolution[0] == .pure_value`, `row_names_have_commas` — would classify both the same way. It would get one of them wrong.

Structurally, `fanout` and `fanin` are opposite. `fanout` routes one input to N destinations; `fanin` routes N inputs to one destination. `fanout`'s selector value space is not expressible in the row names; `fanin`'s selector value space *is* the row names. The classifier gets both right because it asks the structural question — *where does the output come from?* — and the structural answers differ.

This is why the classifier's group-destination guard is not a heuristic. It is not "group destinations are usually non-lookup shapes, so reject them." It is "a group destination with single-token row names cannot have a case selector built for it, because there is no way to relate the row names to the destination members." That is a structural fact about the emitter's template, not a statistical observation about the examples.

The same principle explains why `fanout` returns `.none` rather than falling through to `transform_rules`. It *could* fall through — the transform-rule path would produce OR-of-ANDs formulas that work, as the pre-TAG-229 code did. But those formulas are not the shape's shape. They are a workaround: an emitter that happens to produce correct behavior on a shape it does not understand. The classifier returns `.none` because `.none` is the honest answer for "the emitter has no template for this structure," and returning a shape the emitter *does* have a template for, just because the template happens to work, is exactly the kind of accidental correctness that TAG-229 was built to eliminate.

If `fanout`'s shape becomes worth emitting in the future — if a selector-enum template is added, or if the parser learns to derive a selector value space from the source declaration — then `fanout` will classify as a new shape, the classifier will return that shape, and the emitter will have a template for it. Until then, `.none` says "unrouted, and we know why." That is a stronger statement than "falls through to whatever works."


# 6. The overlap story — why the classifier exists

The classifier's design is easiest to justify by looking at the problem it was built to solve. Not the theoretical problem — the actual, empirical one. Before TAG-229, the emitter ran a `zig build -Dverify=examples` pass that printed one line per definition:

```
[dispatch] {name}: lowered={} transform_rules={} lookup_shape={}
```

Three booleans. Each one said whether a particular emission path had decided the definition was *its* to handle. The classifier was designed against the answer to a simple question: for each of the 32 examples, which of the three booleans were true?

The answer was more interesting than expected.

## What the log showed

Most definitions were clean. About twenty fell into one of three unambiguous buckets:

- `lowered=true`, the other two false — the definition lowered cleanly to a case block. `fanin`, `BINEQ`, `BIGT`, `LAND`, `LNOT`, `IF`, `PARITY`, `INNER`, `AND` in TAG-192. One path fired, it was the right one, and the VHDL came out correct.
- `lowered=false`, `lookup_shape=true`, `transform_rules=0` — the definition was lookup-shaped but not lowerable. `CODE`, `FULLADD130`, `TAG163_TOP`, `FULLADD184`. One path fired (the contained-lookup writer), it was the right one, and the VHDL came out correct.
- `lowered=false`, `lookup_shape=false`, `transform_rules>0` — the definition had rules that must emit as OR-of-ANDs. `FULLADD177`, `FULLADD198`, `FULLADD211`, `REACTION`. One path fired, the right one, correct VHDL.

Then there was a fourth bucket. In it, **two booleans were true at once**:

```
NOT@129:    lowered=false  transform_rules=2  lookup_shape=true
OR@129:     lowered=false  transform_rules=4  lookup_shape=true
fourstate:  lowered=false  transform_rules=4  lookup_shape=true
AND@142:    lowered=false  transform_rules=4  lookup_shape=true
AND@143:    lowered=false  transform_rules=4  lookup_shape=true
AND@190:    lowered=false  transform_rules=4  lookup_shape=true
AND@212:    lowered=false  transform_rules=4  lookup_shape=true
OR@149:     lowered=false  transform_rules=4  lookup_shape=true
OR180@160:  lowered=false  transform_rules=4  lookup_shape=true
test@185:   lowered=false  transform_rules=2  lookup_shape=true
AND2:       lowered=false  transform_rules=4  lookup_shape=true
AND142:     lowered=false  transform_rules=4  lookup_shape=true
```

Twelve definitions. In every one of them, `writeTransformRules` and `writeContainedLookupTable` both ran, both decided the definition was theirs, and both emitted VHDL to the same signal.

## Why GHDL did not complain

The obvious question: if two emitters are driving the same destination, why did the VHDL compile? Why did the runtime vectors pass?

Because the two emitters were producing the *same value* on the same signal. `writeTransformRules` synthesized an OR-of-ANDs formula over the definition's rules; `writeContainedLookupTable` synthesized a case block over the same rules. Different VHDL, same semantics. When both signals resolve to the same value, GHDL treats the pair as duplicate drivers with identical values and accepts them. The runtime vectors passed because the *netlist behavior* was correct — there was simply twice as much logic as necessary, driving the same wire.

For `AND@142`, the OR-of-ANDs said "the output is high when X is high and Y is high, OR when X is high and Y is high, OR …" — once per rule. The case block said "`when "11" => data_value(1)`." Both produce the same output. Both compile. Both verify. The difference is that one of them is redundant.

## Why it was still a bug

A duplicate driver that happens to agree with its twin is not a working system. It is a working system *today*, with a latent bug that will manifest the moment the two drivers stop agreeing.

The moment arrives in one of several ways:

- A rule changes. The transform-rule emitter sees the change, the lookup emitter sees a different change (or misses one), and the two drivers disagree. Now the same wire is driven high by one and low by the other — a genuine multi-driver conflict, GHDL rejects it, and the user gets a VHDL compile error they cannot trace to anything they wrote.
- The shape gets extended. A new definition lands in the overlap set with rules the two paths interpret differently, and the same conflict occurs.
- A refactor changes emission order. The two emitters are independent; whichever fires second wins for the purposes of any subsequent analysis. If a future analysis pass depends on which emitter wrote the signal last, the behavior changes.

None of these require the user to do anything unusual. The bug is *latent* — it lives in the emitter's structure, waiting for a shape change to expose it.

This is exactly what the classifier exists to prevent. The bug class — "two paths both fire" — is not a class the post-TAG-229 emitter can reach. The classifier returns one shape, the emitter calls one sub-emitter, the definition's output has exactly one driver. The overlap set is the empirical proof that the old structure allowed this, and the corrected emitter is the proof that the new structure forbids it.

## The fix, and what it costs

The classifier picks `.contained_lookup` for all twelve overlap definitions. The transform-rule path does not fire; the `transform_rules` argument is still collected (it's cheap, and other shapes need it), but it is not passed to `writeTransformRules` for these definitions. The VHDL now carries one driver per destination instead of two.

The cost is that the emitted VHDL is not byte-identical to the pre-TAG-229 output. The case block remains, and the OR-of-ANDs block disappears. The two were producing the same value, so the netlist behavior is unchanged, but the VHDL text is different: shorter, cleaner, and free of the redundant driver.

That is why the acceptance criterion for TAG-229 was amended from "no change to emitted VHDL" to "no change to netlist behavior, and the VHDL may shed redundant drivers." The original criterion was based on the assumption that only one path was firing for every definition. The empirical map showed that assumption was wrong — twelve definitions had two paths firing, with coincidentally-compatible output. A classifier that picks one path for those definitions cannot leave the VHDL byte-identical, because *the whole point is to stop emitting the second driver*. The amended criterion names what the classifier is actually allowed to do.

The amendment was not a concession. It was the recognition that the pre-TAG-229 output was not the reference state — it was one state, with redundant drivers, that happened to pass. The classifier's job is to produce the *correct* state: one driver per destination, one path per definition, one shape per answer to "where does the output come from?".

## The lesson

The overlap set is the chapter's moral, made concrete. It is easy to read "consolidate the three rule-emission paths behind a single shape classifier" as a refactor of *scheduling* — a cleaner way to decide which of the existing paths to take. It was not. It was the identification and elimination of a whole class of bug — two paths firing — that the old structure silently permitted and the old test suite silently accepted, because the two paths happened to agree.

The classifier is not a cleaner way to make the same choice. It is the replacement of an *implicit* choice (whichever paths happen to satisfy their guards, possibly more than one) with an *explicit* choice (one classifier, one answer, one emitter). The distinction between those two is the difference between a system that is correct by accident and a system that is correct by construction.

# 7. What the classifier deliberately does not decide

The classifier answers one question: where does a definition's output come from? It answers it with one of five shapes, and the emitter dispatches on that answer. That is the whole of its responsibility.

Everything else — every other decision the emitter has to make — is somebody else's job. Naming those decisions, and explaining why they are *not* the classifier's, is the last step in understanding what the classifier is. A classifier that tries to answer every question is not a classifier; it is an emitter with a decision-shaped top layer. The purpose of this section is to draw the boundary firmly, so that future work knows which side of it a given concern lives on.

There are four concerns the classifier deliberately leaves alone. Each was a real temptation during the refactor, and each has a specific reason for being out of scope.

## 1. Which sub-emitter within `contained_lookup`

`contained_lookup` is one shape but three sub-shapes. The lookup key can come from:

- **contained rows** — the classic composed-key lookup, where the rows' *names* are the key values (`0,0`, `0,1`, `1,0`, `1,1`) and the case selector is built directly from them.
- **a composed fill** — the key comes from a `.fill` composition over `def.sources`, not from the row names.
- **a composed pure value** — the key comes from a `.pure_value` composition over `def.sources`, the shape used by `TAG163_TOP`.

The classifier returns `contained_lookup` for all three. It does not return which one. That refinement is carried by a separate enum, `LookupKey`, and the sub-emitter inside `writeContainedLookupTable` consults it to decide how to build the case selector.

Why is this not a shape? Because it does not change the answer to "where does the output come from?" All three sub-shapes are lookups. They differ in how the *table* is indexed, not in whether the output is a table. If the classifier enumerated `contained_lookup_by_rows`, `contained_lookup_by_fill`, and `contained_lookup_by_pure_value` as separate shapes, it would be encoding a sub-emitter detail in the shape enum, and the five-shape model would collapse into a nine-shape model with no corresponding gain in clarity. The right level for the classification is "lookup"; the right level for the key form is the sub-emitter.

This distinction matters because it tells future work where to add a new lookup key form. If a fourth way to key a lookup emerges, the classifier does not change — only `LookupKey` and `writeContainedLookupTable` do. The classifier stays at five shapes, and the shape enum stays the stable interface between the dispatch layer and the emitters. The refinement layer is free to grow underneath it.

## 2. Runtime dispatch

The runtime has its own dispatch logic, and it is not the classifier's concern.

The runtime dispatches on `buildRulesAtDepth` and `appendSelectRules` — functions that walk a definition's contained rows and produce a flat list of rules to fire at runtime. The classifier never enters this picture. It produces an `EmissionShape`, which the *VHDL emitter* consumes; the runtime consumes rules, not shapes. The two dispatches are answering different questions:

- **Classifier:** which VHDL architecture template does this definition need?
- **Runtime:** which rules does this definition contribute to the running network?

The pre-TAG-229 emitter had a third dispatch that overlapped with both: the `lowered` flag, threaded through `writeDestinationFills`, decided which rule-emission path the VHDL emitter would take. That dispatch is now gone — absorbed into the classifier. But the runtime's dispatch was already correct and stays untouched. TAG-229's scope is emission, not execution.

The temptation during the refactor was to see the runtime's dispatch and the emitter's dispatch as the same problem in two places, and to unify them. That would have been wrong. The runtime is a *model* of a definition's rule-firing behavior; the emitter is a *translation* of a definition into VHDL. They both walk the same AST, but they ask different questions of it, and the correct unification would be a shared "which rules does this definition assert?" function — a separate ticket, not part of TAG-229. For now, the classifier's scope is the emitter, and the runtime's scope is the runtime, and the boundary is the `network.Definition` they both consume.

## 3. Parser normalization

The classifier's decision is made at *emit* time, not at *parse* time. That is a deliberate choice, and it is worth stating why.

Several of the classifier's decisions could, in principle, be made at parse time. The clearest example is the `$A$B()` composed key in a definition's resolution. Currently, the parser leaves it as a `.pure_value` statement, and the classifier treats `.pure_value`-keyed definitions differently from `.fill`-keyed ones (though both classify as `contained_lookup` in the end). If the parser normalized `$A$B()` into `.fill { dest: "ms_result", expr: "$A$B()" }`, the two forms would collapse into one AST variant, and the classifier would have one fewer distinction to make.

The classifier does not do this, and does not ask the parser to. The reason is coupling. The parser's job is to produce an AST that faithfully represents the source. Moving the decision "what does this composed key *mean* for emission?" into the parser would make the parser depend on emitter concerns — it would have to know that `ms_result` is the synthesized destination name, that fills and pure values are interchangeable for emission purposes, and that the two are equivalent for keying a lookup. None of those are parser facts. They are emitter facts. Coupling the parser to them means a future emitter change (new synthesized destination name, new key form) requires a parser change, and vice versa.

The classifier's purity — it does not mutate the AST, does not call the parser, does not depend on any backend — is what allows it to be tested in isolation, and that purity depends on the decision being made *late*, at the point where all the AST's structure is available and no emitter-specific normalization has been baked in.

There is a threshold here. If the classifier grows past roughly a hundred lines of decision logic, that is a sign that the language's forms are not collapsing enough at parse time — that too many syntactic variants are surviving to the emitter and forcing the classifier to distinguish them. At that point, the right move is to revisit parser normalization, not to keep growing the classifier. We are not at that threshold. The classifier is around a hundred lines, most of it comments, and it handles the five shapes cleanly. If a sixth shape emerges and the classifier needs a sixth branch with new syntactic distinctions, that is the signal to look at the parser. Until then, the classifier stays at emit time.

## 4. The `none` shapes

The classifier returns `.none` for several distinct cases, and it does not distinguish among them:

- **Empty resolution** — the definition has destinations but no rules to fill them, no fills, nothing. (`MYCONST`.)
- **Pure geometry** — the definition is a spatial primitive with no rule emission. (`ca2d`, `ca100`.)
- **Unrouted shape** — a definition whose shape the emitter does not yet handle. (`fanout` with a group destination and single-token row names.)
- **Constant** — a definition with a fixed output value the emitter routes through a different path. (Some geometry primitives.)

All four return `.none`, and the emitter does nothing for all four. The classifier could return `none_empty`, `none_geometry`, `none_unrouted`, `none_constant`, and the emitter could switch on the more specific answer — but it would do the same nothing in each case. The distinction is not useful to the emitter, so it is not in the shape enum.

The distinction *is* useful to someone debugging why a definition emits nothing. If `fanout` emits an empty architecture and the user wants to know why, the answer is not "`.none`" — the answer is "group destination with single-token row names, so the case selector cannot be built." That answer is in the classifier's *guard* (the explicit `if` that returns `.none` for that shape), not in the `none` enum variant. The debugging answer comes from reading the classifier's logic, not from the shape it returns.

This is why `none` is one variant, not four. The enum says what the emitter does; the classifier's comments say why. Conflating the two — adding `none_unrouted` to the enum because it's interesting to debug — would confuse the enum's purpose, which is to tell the emitter what to emit, not to tell the reader why a shape is unemitted.

The `fanout` case is the sharpest example. It is the only `.none` shape where the classifier's *decision* is non-trivial: a shape that looked like it should be `.contained_lookup` (it has contained rows, one of them carries a fill, it has a composed `.pure_value`) returns `.none` because of a single structural condition — the group destination's members cannot be selected on from single-token row names. The classifier does not return a shape for "unrouted because of a group-destination guard"; it returns `.none`, and the guard's presence in the code is the answer. This is deliberate. The shape enum is for the emitter, and the emitter's action for `.none` is "skip." The debugging information lives in the classifier, where the question "why is this `.none`?" is answered by reading one paragraph of code.

The `.none` shapes illustrate the classifier's design principle one last time: **the classifier answers the emitter's question, and only the emitter's question.** What the answer *means* — which sub-shape, which reason, which debugging path — is a separate concern, and belongs either in the sub-emitter or in the classifier's own code, not in the shape enum.

## The boundary

Four concerns, four reasons for being out of scope, one principle:

- The classifier decides *which emitter* handles a definition.
- The sub-emitter decides *how* to emit, once chosen.
- The runtime decides *when* rules fire, entirely separately.
- The parser decides *what the AST looks like*, before the classifier sees it.
- The classifier's comments decide *why* a shape is what it is, for the reader.

These five layers are distinct. Conflating any two of them was, in the pre-TAG-229 code, the source of every bug the classifier was built to eliminate. The classifier's value is not just that it consolidates the three emission paths — it is that it establishes a boundary, and everything on the other side of the boundary is allowed to be simple because the boundary is firm.

That is what "consolidate the three rule-emission paths behind a single shape classifier" actually meant, in the end. Not a refactor of scheduling. Not a cleaner way to make the same choice. An architecture: one classifier, five shapes, five sub-emitters, and a boundary that holds because the classifier refuses to do anything but answer its one question.


# 8. The pipeline, end to end

The chapter has described the classifier, the five templates, the `fanout` guard, the overlap story, and the boundary between the classifier and everything it does not decide. Each section has been about one part of the pipeline. This section puts them together: one definition, from source text to emitted VHDL, walked through every stage.

The example is `OR180@160` — a two-input OR gate expressed as a lookup table. It is small enough to fit in one page and complex enough to exercise the interesting parts of the classifier: contained rows, a composed key, a `pure_value` resolution, a single place destination. It is also one of the overlap-set definitions — before TAG-229, both `writeTransformRules` and `writeContainedLookupTable` fired for it — so walking it end-to-end shows the classifier's effect, not just the classifier's operation.

## Stage 1: source text

The definition's `.ms.ipl` source, abridged to its shape:

```
OR180[(a<> b<>)($result)
  $a$b():
  0,0[0] 0,1[1] 1,0[1] 1,1[1]
]
```

Two sources (`a`, `b`), one destination (`$result`), a resolution area with one `.pure_value` statement (`$a$b()`), and four contained rows keyed by the four input combinations. Each row resolves to the OR of its inputs — `0` for `0,0`, `1` for the other three.

This is the canonical lookup shape. The reader who has followed §1 can already predict the classifier's verdict: `contained_lookup`. The rest of this section shows how the pipeline gets there.

## Stage 2: parse

The parser reads the source and produces a `network.Definition`. Abridged:

```
Definition {
  name: "OR180",
  sources: [place "a", place "b"],
  destinations: [place "$result"],
  resolution: [pure_value "$a$b()"],
  contained: [
    Definition { name: "0,0", sources: [], destinations: [], resolution: [fill { dest: "0", expr: "0" }] },
    Definition { name: "0,1", sources: [], destinations: [], resolution: [fill { dest: "1", expr: "1" }] },
    Definition { name: "1,0", sources: [], destinations: [], resolution: [fill { dest: "1", expr: "1" }] },
    Definition { name: "1,1", sources: [], destinations: [], resolution: [fill { dest: "1", expr: "1" }] },
  ],
}
```

Three things are worth noting about this AST.

First, the contained rows' resolutions are `.fill` statements, not `.pure_value` statements. The parser's `parseContainedSection` converts `0,0[0]` into a `Definition` with a single `.fill { dest: "0", expr: "0" }` statement. The `0` inside the brackets is a fill of a synthesized destination named `"0"`, not a pure value. This is a parser-side normalization: the two forms are equivalent for emission purposes, and the parser normalizes the contained form to the fill form because the fill form carries the destination information that `writeContainedLookupTable` needs.

Second, the contained rows' `sources` and `destinations` are empty. The parser's `parseDefinitionAsContainedEntry` mode ensures that contained rows are parsed as key-value pairs, not as nested definitions. This is what `allContainedAnonymous` checks, and it is what makes the four rows lookup-table rows rather than nested sub-networks.

Third, the contained rows' names are `0,0`, `0,1`, `1,0`, `1,1` — comma-separated, with two segments each. `containedRowNamesAreComposedKeys` splits on commas and checks segment count against `def.sources.len`; both are `2`, so the check passes. The row names can be composed into a case selector over `a` and `b`.

The parser also runs the bare-bracket ambiguity check (`dest_is_ambiguous`). `OR180` has one destination, and that destination is a place, not a group, so the check does not fire. If `OR180` had two destinations or a group destination, the check would have rejected it, and the pipeline would have stopped before the classifier ran. For `OR180`, the definition parses successfully.

## Stage 3: collect transform rules

Before the classifier runs, the caller collects the value-transform rules from the definition's contained rows:

```zig
const transform_rules = try value_transform_analysis.collectValueTransformRules(arena, def);
```

`OR180`'s contained rows each have a `.fill` resolution, not a `.pure_value`, so `isValueTransformRule` returns false for all four. The collected slice is empty. This matters for the classifier's step 6: the `.transform_rules` path will not fire for `OR180`, because there are no rules to emit.

The pre-TAG-229 code would have collected the same empty slice, but it would have fired the transform-rule path anyway for `.pure_value`-resolution definitions, using the `.pure_value` composition as a rule source. The classifier does not do this — it checks `transform_rules.len > 0`, which is false for `OR180`, so the transform-rule path is ruled out before the classifier commits to it. That is the structural difference: the classifier checks the *collected rules*, not the resolution shape.

## Stage 4: classify

The classifier walks its decision order:

1. **`destinations.len == 0`?** No — `destinations.len == 1`.
2. **All invocations, no fills, no contained rows?** No — `resolution[0]` is `.pure_value`, and `contained.len > 0`.
3. **No contained rows and no fills?** No — `contained.len == 4`.
4. **Single destination, contained rows, decomposable and lowerable?** `destinations.len == 1` is true. `def.contained.len > 0` is true. `decomposeRules(allocator, def)` returns a rule set. `isLowerableShape(rule_set)` — this is where `OR180` differs from `BINEQ`. `OR180`'s contained rows are `.fill` statements, and `decomposeRules` converts them into a rule set whose inputs are the row names and whose targets are the fill destinations. `isLowerableShape` checks whether the rule set can be expressed as a case block over `def.sources`. For `OR180`, the rule set's inputs are `0,0`, `0,1`, `1,0`, `1,1` — the row names, two segments each — and `def.sources` is `a`, `b`. The shape check passes: the rule set is a total function over the source value space, and the destination is a single place. **`.lowered_rules`** would be the verdict.

But wait — the log shows `OR180: shape=contained_lookup`, not `shape=lowered_rules`. Why?

Because the pre-TAG-229 dispatch log for `OR180` was `lowered=false transform_rules=4 lookup_shape=true`, not `lowered=true`. The `lowered` flag was false, which means `isLowerableShape` returned false for `OR180` at the time the log was collected. That is consistent with the classifier's current code: `isLowerableShape` requires `decomposeRules` to succeed *and* the rule set to be lowerable. For `OR180`, `decomposeRules` may succeed, but `isLowerableShape` may reject the rule set — the reason is in `value_transform_export.isLowerableShape`'s implementation, not in the classifier's logic. The classifier's behavior matches the empirical log: `OR180` is not `.lowered_rules`, so it falls to the next check.

5. **Composed-key lookup with contained rows?** `allContainedAnonymous(def.contained)` — all four rows have empty `sources` and `destinations`, so yes. `composedKeyPresent(def.contained)` — the rows' resolutions contain `.fill` statements, so yes. `def.contained.len > 0` — yes. `def.destinations[0].kind == .group` — no, the destination is a place. So the group-destination guard does not fire. **`.contained_lookup`**.

The classifier returns `.contained_lookup`. The decision order reached step 5 because steps 1–4 did not commit. Step 4 was tried and did not fire, not because the classifier's logic is wrong, but because the lowering predicate rejected `OR180` for reasons specific to the predicate. The classifier's job is to reflect that predicate's verdict, not to override it.

## Stage 5: emit

The emitter dispatches on the shape:

```zig
switch (shape) {
    .contained_lookup => try signal.writeDestinationFills(allocator, writer, def),
    .lowered_rules => try value_transform_export.lowerRulesFromDef(allocator, writer, def),
    .transform_rules => try value_transform_export.writeTransformRules(allocator, writer, transform_rules),
    .invocations_only, .none => {},
}
```

`writeDestinationFills` calls `writeContainedLookupTable`, which builds a case block from the contained rows. The emitted VHDL:

```vhdl
process(a, b, complete) begin
  result <= null_value;
  if complete = '1' then
    case a & b is
      when "00" => result <= data_value(0);
      when "01" => result <= data_value(1);
      when "10" => result <= data_value(1);
      when "11" => result <= data_value(1);
      when others => null;
    end case;
  end if;
end process;
```

One case block, one destination, four arms, one default. The selector is `a & b` — the two sources composed into a single value, matching the row names' two-segment structure. The arms are the row names, and the arm bodies are the row resolutions. The `null_value` default and the `complete = '1'` guard are the Fant completeness convention, inherited from the emitter's case-block template.

In the pre-TAG-229 code, `writeTransformRules` also fired for `OR180` (it had `transform_rules=4`), producing four OR-of-ANDs formulas for the same `result` signal. The classifier now picks `.contained_lookup` only, so the transform-rule formulas are not emitted. The netlist behavior is identical — both drivers produced the same values — but the VHDL is shorter, and the destination has one driver instead of two. This is the overlap-set fix (§6) applied to a single definition: `OR180` was one of the twelve, and the classifier's verdict for it is `.contained_lookup` on purpose.

## Stage 6: the entity

The definition also produces a VHDL entity:

```vhdl
entity OR180 is
  port (
    a : in symbol_t;
    b : in symbol_t;
    result : out symbol_t
  );
end entity OR180;
```

The entity is generated from `def.sources` and `def.destinations`, not from the shape. Every definition gets an entity, regardless of which emission template its architecture uses. `.none` definitions get an entity with no architecture body; `invocations_only` definitions get an entity and a port-map architecture; `contained_lookup` definitions get an entity and a case-block architecture. The entity is the same across shapes; the architecture is what differs.

## The pipeline, as a diagram

Put the stages together:

```
.ms.ipl source (Stage 1)
       │
       ▼
      parser
       │
       ▼
  network.Definition (Stage 2)
       │
       ├─ collectValueTransformRules (Stage 3)
       │       │
       │       ▼
       │   []ValueTransformRule
       │       │
       ▼       ▼
 classifyEmissionShape (Stage 4)
       │
       ▼
   EmissionShape
       │
       ▼
   switch on shape (Stage 5)
       │
       ├─ writeDestinationFills ─┐
       ├─ lowerRules            ─┤
       ├─ writeTransformRules   ─┼─► architecture
       ├─ (component instancer) ─┤
       └─ (nothing)             ─┘
       │
       ▼
   VHDL entity + architecture (Stage 6)
```

The classifier sits at the boundary between the AST (Stage 2–3) and the emitter (Stage 5–6). It is the only place the shape question is asked; the emitter's switch is a *mechanical* dispatch on the classifier's answer, not a second decision. The whole point of the pipeline is that once the classifier returns a shape, the emitter's behavior is determined — no further decisions, no further predicates, no further guards.

## The one-sentence version

The chapter has been building toward one sentence, and this section makes it concrete:

**A shape is where the output comes from — lookup, invocation, constant, or nothing — and every other distinction in the grammar is either a refinement of one of those four or orthogonal to them.**

For `OR180`, the output comes from a lookup on the inputs. Everything else about `OR180` — its two sources, its one destination, its four contained rows, its `.pure_value` resolution, its comma-separated row names — is either a refinement of "lookup" (which key form, which selector) or orthogonal to shape (the entity's port list, the completeness convention). The classifier's verdict is `.contained_lookup` because that is the shape of "the output comes from a lookup," and the emitter's VHDL is the case-block template because that is the architecture the shape calls for.

The pipeline is the classifier's decision applied once per definition, at the one point where the decision is unambiguous, with the result consumed mechanically by five templates. That is the chapter. The rest is details.


# 9. Where this goes next

The chapter has described one classifier, five shapes, five templates, and the pipeline that connects them. That is the whole of what TAG-229 built, and it is enough to explain how a MatterScript definition becomes VHDL. But the classifier's architecture is not specific to VHDL. The same four answers — lookup, invocation, constant, nothing — organize every backend the compiler has, and the remaining chapters of Part VIII are, in one way or another, applications of the same model to different targets.

This section is short. It names the forward pointers, says what the classifier's shape model means for each, and stops.

## The other backends

The compiler has four backends in various stages of maturity: VHDL, WGSL, C, and (via the C backend) the POSIX runtimes. Each one consumes the same AST and answers the same question — *where does the output come from?* — but produces a different target language.

**WGSL generation** (chapter 07) is the most direct application. WGSL is a compute language, and a MatterScript definition maps to a WGSL compute shader in a way that is structurally parallel to the VHDL mapping: lookups become lookup tables (or, in WGSL's case, switch statements over an index buffer), invocations become shader invocations, constants become uniform bindings. The classifier's five shapes are not a VHDL-specific model; they are a model of "what kind of computation is this definition," and WGSL is a second expression of the same model. The chapter on WGSL generation will not re-derive the classifier; it will take the classifier as given and show how each shape is expressed in a different target language.

**C and POSIX code generation** (chapter 08) is the same story at a lower level. A lookup becomes a function with a switch statement; an invocation becomes a function call; a constant becomes a `static const`; nothing becomes an empty stub. The C backend's dispatch is the classifier's dispatch, with the five shapes expressed as five C idioms rather than five VHDL templates.

**FPGA synthesis** (chapter 07) is the VHDL backend's downstream consumer. The classifier does not change; what changes is that the emitted VHDL is fed to a synthesis tool, and the synthesis tool's output is a bitstream. The classifier's correctness matters more here, because synthesis is where the duplicate drivers from §6 would have become real hardware conflicts if the classifier had not eliminated them.

**POSIX runtimes** (chapter 09) and **embedded NuttX** (chapter 09) are the C backend's execution targets. The classifier's output is a C source file, and the runtime executes it. Same story, one level down.

The point of listing them is not to preview their content but to establish a claim: **the classifier is a backend-agnostic model.** It is not a VHDL-specific heuristic. The four shapes are the four answers to "where does the output come from?", and every target language has a natural expression for each. The classifier is the compiler's *shape model*, and the backends are the compiler's *shape translators*.

## The runtime's dispatch

The runtime (`runtime/rules.zig`) is the other consumer of the AST, and it has its own dispatch. This chapter's §7 noted that the runtime's dispatch is separate from the classifier's, and that separation is worth restating here: the runtime answers "when do rules fire?", the classifier answers "which architecture template applies?" The two questions are independent, and the runtime's dispatch is not affected by the classifier's existence.

The runtime's `buildRulesAtDepth` and `appendSelectRules` functions walk a definition's contained rows and produce a flat list of rules to fire. They do not consult the classifier; they do not need to. A definition with rules to fire has rules to fire regardless of whether it is emitted as a case block or an OR-of-ANDs formula. The runtime's job is to execute the definition's semantics; the classifier's job is to translate the definition into VHDL. The two are orthogonal.

This orthogonality is worth stating because it is sometimes surprising. A reader might expect the runtime to have been simplified by TAG-229, or the classifier to have absorbed some of the runtime's logic. Neither is true. The classifier is an *emission* model; the runtime is an *execution* model. They share the AST, and nothing else. The next chapter on runtime execution models (chapter 02.1) covers the runtime's dispatch in detail; this section only notes that it is not the classifier's concern.

## Parser normalization

§7 discussed parser normalization as something the classifier deliberately does not do, and it is worth restating the forward pointer here. The parser currently produces several AST variants that the classifier could have distinguished but does not — `.fill` versus `.pure_value` in composed keys, contained-row fills versus contained-row pure values, synthesized destinations versus explicit ones. Each of those distinctions is a *potential* shape refinement that the classifier does not make, and a future normalization pass in the parser could collapse some of them.

The most concrete example is the `$A$B()` resolution shape. Currently, the parser produces a `.pure_value` statement for `$A$B()`, and the classifier treats `.pure_value`-keyed definitions as one of the contained-lookup variants (via `LookupKey`). If the parser normalized `$A$B()` into `.fill { dest: "ms_result", expr: "$A$B()" }`, the two forms would collapse into the same AST variant, and the classifier's `LookupKey` refinement would have one fewer case. That is a future simplification, not a current need, and it belongs in a parser chapter rather than here.

The larger point is that the classifier's shape model is *stable* under parser normalization. If a parser change collapses two AST variants into one, the classifier's decision order still produces the same shapes for the same definitions — the definitions that were `contained_lookup` before the normalization are still `contained_lookup` after, because the shape is about where the output comes from, not about which AST variant expresses it. The classifier's stability under normalization is a consequence of its structural (rather than syntactic) model, and it is one more reason the four-shape model is the right level of abstraction.

## What this chapter did not cover

A few things are adjacent to the classifier and not covered here, in case the reader is looking for them:

- **The runtime's rule-firing algorithm.** Chapter 02.1 covers `buildRulesAtDepth` and `appendSelectRules` in detail.
- **The VHDL backend's process and signal model.** The VHDL chapter (06) covers the process structure, the completeness convention, and the symbol encoding in detail; this chapter's §4 showed one process block per template and moved on.
- **The WGSL, C, and synthesis backends.** Part VIII chapters 07–08 and Part IX cover these in full.
- **The parser's normalization pass.** Part VIII chapter 01 and chapter 02 cover the parser's output shape; the normalization question is one of the topics a future parser chapter could address.
- **The verification process.** Part VIII chapter 02.2 and chapter 10 cover the `zig build -Dverify=examples` pipeline that produced the empirical dispatch log this chapter's §6 cites.

This chapter is a description of one classifier, not a survey of the compiler. The reader who wants the rest of the pipeline has the rest of Part VIII.

## The one-sentence version, again

The chapter opened with a question — *where does a definition's output come from?* — and a claim: that this question organizes the VHDL emitter, and that the answer determines the emitted architecture. The claim was made in §1, argued in §3 through §7, and demonstrated in §8. The five shapes are the five answers, the five templates are the five architectures, and the classifier is the wall between the front end and the back end that makes the whole structure possible.

The one-sentence version is the same sentence §8 ended with: **a shape is where the output comes from — lookup, invocation, constant, or nothing — and every other distinction in the grammar is either a refinement of one of those four or orthogonal to them.**

The classifier is the function that answers the question. The templates are the emitters that express the answers. The pipeline is the path from source to VHDL that the question and the answers together define. That is the chapter, and it is the whole of TAG-229.


*Drafting in progress...*
