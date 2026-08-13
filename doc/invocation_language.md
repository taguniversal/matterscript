THE INVOCATION LANGUAGE This chapter presents a symbol string language of direct association relationships that embodies the invocation model.

12.1 THE NATURE OF SYMBOL STRING EXPRESSION The essential property of a symbol string is that it exists in an inherently limiting one-dimensional expression space. A symbol in the string can associate with its direct neighbors but cannot directly associate with more remote places in the string. Contrast this to the expression of an electronic circuit in three-dimensional space in which any place in the circuit can directly associate with any other place in the circuit via a wire connecting the two places. A symbol string expression must be mappable to higher dimensional forms of expression. So there must be a means of expressing higher dimensional relationships in the one-dimensional string, a means of delimiting places within the string, and a means of associating these places from anywhere in the string to anywhere else in the string. This is accomplished with syntax structure and with name correspondence. Of the available symbols a small set is reserved for expressing syntax structures, and the rest can be used for expressing correspondence names and the content that flows through the expression. Syntax structure can express delimitation of places and their local association in terms of nesting and contiguity, but it cannot associate one place in the expression with any other arbitrary place in the expression. This is accomplished with name correspondence association. Each syntax structure has a unique name. Remote syntax structures with identical names are associated by the correspondence of their names. Another consequence of the one-dimensionality of the symbol string is that there is not enough dimensionality for a symbol string expression to autonomously resolve in the context of the string. A symbol string expression can be mapped into an expression with sufficient dimensionality, or it can be interpreted within an expression of sufficient dimensionality. However, a symbol string cannot spontaneously behave on its own merits. A symbol string expression is a purely referential form of expression. Since a symbol string is purely referential, it can indulge in expressional efficiencies that are not available to expressions that autonomously resolve. It can express just the necessary relationships of a process and defer as universal conventions many of the details of process behavior. The deferred expressivity can be added back in during mapping to autonomy or during interpretation.
12.2 A LANGUAGE OF ASSOCIATION RELATIONSHIPS The invocation language embodies the invocation model. It expresses association relationships among places in an expression in contrast to a sequence of operations on a state space. It expresses distributed concurrency in contrast to centralized sequentiality. It expresses locally autonomous behavior in contrast to centrally controlled behavior. It expresses distributed data maintenance in contrast to centralized data maintenance. Expression in the language is uniform and consistent from primitive expressions such as logic functions or protein interactions through all levels of hierarchical composition. There are several familiar notions of expressivity that the language does not include. There is no predefined set of symbols, no predefined set of primitive operators, no predefined data types

or structures, and no predefined control operators. There is no concept of sequence or of any time referent, no concept of explicit control, no concept of explicitly addressable memory, and no concept of state space. Expressions in the invocation language can be mapped into any form of implementation from a fully distributed and concurrent pipeline structure to a contemporary sequential processor and onto any intermediate flavor of distributed processing such as multiple core sequential processors, DSPs, and programmable gate arrays. Uncluttered with conventions and confusions the invocation language captures the elegant simplicity of expressing concurrent and distributed behavior encompassing all forms of process expression from mathematical computation to biological metabolism.

12.3 THE SYNTAX STRUCTURES There are four syntax structures: the source place, the destination place, the invocation, and the definition. A source place anywhere in the string is laterally associated by name correspondence to one or more destination places. Boundaries within the network are expressed with an invocation. One or more destination places are associated as an input boundary, and one or more source places are associated as an output boundary. The invocation boundaries laterally associate with other invocations and hierarchically associate by name correspondence to a definition that contains the expression between the input and output boundaries of the invocation.
12.3.1 Lateral Composition: Place-to-Place Association Non-neighbor places in the string are associated by name correspondence between a source place and one or more destination places. Sourcename is the correspondence name of the source place and destinationname is the correspondence name of the destination place.
Source place: sourcename< content >
 Destination place: $destinationname A source place will associate with all destination places with an identical correspondence name. The behavior model is that the content of a source place flows to each destination place of the same name. In Figure 12.1a place flows to each destination place of the same name. Source place Abel< AGXST > is the content of a source place named Abel. Source place Abel< AGXST > is associated with one destination place $Abel by name correspondence. The AGXST will flow from source Abel< > to destination place $Abel. Figure 12.1b shows a source place named Baker with a content NGRYU with a fan-out association by name correspondence to three destination places named Baker. The content, NGRYU, will flow to all three destination places. A single correspondence name can span only one association. There cannot be two source places of the same name. Figure 12.2a illustrates the ambiguity of identically named source places.

Figure 12.1 Source to destination association expressions.

Figure 12.2 Daisy chaining associations.
 To extend a path of association, a destination place associates with a differently named source place by syntax association. Figure 12.2b shows a source place first< > with a content FSZPQ that is associated with destination first place first< > with a content FSZPQ that is associated with destinationfirst by name correspondence association. Destination place $first is associated with source place second< > by syntax structure association. Source place second< > is associated with destination place $second by name correspondence association. Destination place $second is associated with source place third< > by syntax structure association. Source place third< > is associated with destination place $third by name correspondence association. The FSZPQ in source place first< > ultimately flows through the associations to destination place $third. Different syntax structures are associated by name correspondence, and different correspondence names are associated by syntax structure. Extended paths of association are expressed by alternating name correspondence association and syntax structure association, weaving a tapestry of arbitrarily complex association relationships in a one-dimensional string of symbols.
12.3.2 Hierarchical Composition: The Invocation and Definition

The invocation and definition express the boundaries of both lateral and hierarchical composition. The Invocation The invocation associates destination places to form an input boundary and associates source places to form an output boundary. The behavior model is that the boundaries are completeness boundaries and that the invocation expresses completeness criterion behavior between its input and output boundaries. When the content at the output boundary is complete, the content presented to the input is complete, and the output is the correct resolution of the content presented to the input boundary. Invocation boundaries are the boundaries of the expression. They are composition boundaries, coordination boundaries, and partition boundaries. An invocation is a named syntax structure of two parenthesized lists. Invocationname is the correspondence name of the invocation. The destination list is the input boundary for the invocation, in which the content to be resolved is received, and the source list is the output boundary for the invocation, through which the result content is distributed.

Figure 12.3 The invocation syntax and external associations.

Figure 12.3 shows the syntax structure of the invocation and its external association

relationships. ProcX is the correspondence name of the invocation that associates with a definition of the same name.

The Definition : The definition expresses the network of associations between the boundaries of the associated invocation. A definition is a named syntax structure delimited by brackets containing a source list delimited by parenthesis, a destination list delimited by parenthesis, a place of resolution terminated by a colon followed by a place of contained definitions. Definitionname is the correspondence name of the definition. The source list is the input for the definition through which a formed name is received, and the destination list is the output for the definition through which the results are delivered. The place of resolution is best understood as a bounded pure value expression that can contain association expressions. definition

definitionname[(source list)(destination list) place of resolution : contained definitions]

A definition associates to an invocation by name correspondence. The place of resolution contains the expression between the boundaries that resolves the presented input to an asserted output. The source list receives the input contents by correspondence of syntax structure from an invocation destination list and associates them to destination places in the resolving expression in the place of resolution. The resolving expression contains source places that associate to the output destination places. The destination list receives the results from the source places of the resolving expression and returns them by correspondence of syntax structure to the invocation source list.

Figure 12.4 shows the syntax structure of the definition and its internal association relationships.

ProcX is the correspondence name of the definition and associates with an invocation of the same name.

12.3.3 The Association of Invocation and Definition An invocation associates by name correspondence to an identically named definition. The lists of the invocation associate with the lists of the definition by syntactic structure. The source list of the definition associates to the destination list of the invocation by order correspondence. The destination list of the definition associates to the source list of the invocation by order correspondence. This might seem somewhat confusing at first, but the rationale is straightforward. In Figure 12.5a the invocation ABC associates by name correspondence to definition ABC. Destination places of the invocation destination list associate by order with the source places of the definition source list. Source places of the invocation source list associate by order with the destination places of the definition destination list. The destination list of the invocation is places to where contents flow to form the content to be resolved. The source list of the definition is the places from which the content flows to the resolving expression. The destination list of the definition is the places to where the results of the resolving expression will flow, and the source

list of the invocation is the places from which results will flow to their destinations. Figure 12.5b gives a graphic representation of the invocation-definition syntactic interface. The interface relationships can also be understood in terms of daisychaining. Figure 12.5c shows the invocation and definition lists with destination places merged into their associated source places showing the relationship of the invocation and definition boundaries in terms of syntactic daisychaining. Because its interface of association places with the external expression is purely syntactic, a definition forms an isolated correspondence name domain for source places and destination places. Internal names can be chosen without concern that there will be ambiguity with the external expression.

Na H ATA TURES
Invocation so
Definition OAC
a symb trigrretion
Destination list

| Invocation | place1 | place2 |  | Source list |  |
| --- | --- | --- | --- | --- | --- |
|  | S | S | place3 |  |  |
|  |  |  | S | placeA | placeB |
|  |  |  |  | <> | <> |

Definition

| くン | <> |  |  |  |
| --- | --- | --- | --- | --- |
| A | B | <> C | S |  |
|  |  | result1 |  | result2 |

Source list Destination list
b. Graphic representation
ABC[(A<$place1>B<$place2>C<$place3>)(placeA<Sresult1>placeB<Sresult..
c. Merged string representation
Figure 12.5 The syntactic association of invocation to definition.
invocation FULLADD(., 1 )0< CARRYOUT<).SCARRYOUT
FULLADDI(X<>Y<>C<>)(SUM$CARRY)
definition
Exicin
and De nition

12.3.4 Abbreviated Forms of the Invocation and Definition The invocation and definition syntax structures can be abbreviated to express simpler association relationships and also to accommodate familiar forms of symbol string expression. Return a Content to Place of Invocation An unnamed source place in the source place list of an invocation associates by implicit name correspondence to the place of the invocation and no other place. The invocation itself becomes the single destination place for the returned result. In Example 12.1 the first source place in the source list of the invocation is unnamed. The destination place $SUM in the destination list of the definition associates to the unnamed source place. The content flowing through $SUM will associate to the unnamed source place and flow to the place of the invocation. Single Return to Place of Invocation If an invocation receives a single result in its own place, there is no need of a source list. The corresponding Here is the extracted text from the image: definition can express the single return with the absence of a destination list and with the presence of a single unnamed source place in the place of resolution. An expression like Example 12.2 can be further abbreviated to the form of Example 12.3.
This abbreviation supports the familiar expressional form of functional nesting. In Example 12.4 each invocation has only a destination list and is part of the destination list of another invocation or is within a source place.

**The Conditional Invocation Name** If an invocation has an empty destination list, i.e. no input, then the invocationname itself must express the variable part of the invocation. The conditional invocationname is the mechanism of content transformation in the language. The invocation correspondence name is formed from the content of one or more contiguous destination places. Content emerges from flow paths to interact by forming the correspondence name of an invocation. All content flowing through the association paths eventually emerges to form an invocation correspondence name. This is how value transform rules are invoked to transform the flowing content of the expression.

$place1$place2$place3()

**The Constant Definition** If a definition does not contain a source list and does not contain a definition list, it is a constant definition. With no input associations there is no content flow into the definition to resolve, no need for internal definitions, and no need for the colon. A constant definition contains only a place of resolution between the brackets, which contains a constant content and can be abbreviated as shown below: definitionname[constant]

Since there is no destination list, the constant content is returned to the place of invocation.

A constant definition expresses a value transform rule. Example 12.5 shows the value transform rule definitions for the AND function. The content values 1 or 0 will propagate through A< > and B< >, and a two-value name will be formed by $A$B() that will invoke one of the contained definitions. The constant of the invoked definition will return to the place of the invocation, entering a flow path in the unnamed source place, and will flow through the unnamed source place back to the invocation of AND. The set of constant definitions—value transform rule definitions—expresses the truth table of the AND function. One can think of the content forming the invocationname that transforms into the content of the definition. A constant definition can also contain a fragment of expression including an invocation that will be returned to the place of invocation. The formation of an invocationname in a place of resolution results in the fragment of expression in the corresponding constant definition being returned to the place of invocation in the place of resolution and consequently being resolved. Example 12.6 the content of select< > will be A or B. This content flows to $select and forms the invocation A( ) or B( ), invoking one of the two contained definitions. The content of the named definition is returned to the place of invocation in the place of resolution and resolved directing the input to one of two possible output association paths.

**The Pure Value Expression** If there are no list parenthesis in a place of resolution, then there are no explicit invocations. The contents flowing into a place of resolution are assumed to be freely associating values of a pure value expression that will form names of contained definitions. The contained definitions are value transform rules, or they contain association expression fragments to be inserted into the place of resolution. definitionname[(A< >B< >C< >)(... ) $A$B$C :.. .]

The place of resolution of Example 12.26, as seen later in this chapter, contains a pure value expression.

12.4 THE COMMA The comma is a general separator. There can be cases of separate places that must be syntactically separated but that are not separated by the syntax defined so far such as two constants in the destination list of an invocation. Example 12.7 illustrates two constants, NT and EW, in the destination list of an invocation delimited by a comma. Without the first comma, NT would be confused with the B of $B. Without the second comma, NT and EW would appear as a single constant. Because the destination places are not syntactically isolated, in an invocation destination list the meaning can become ambiguous if a destination place is followed by a conditional invocation. In Example 12.8 the destination places $C$D form an invocationname. If the comma did not separate $B and $C the four destination places would be considered to form the invocationname. Commas can be used freely as a redundant separator for convenience or readability. In Example 12.8 the string "$A, $B" is identical to the string "$A $B".
12.5 COMPLETENESS RELATIONS The language does not express the details of coordination. It assumes completeness criterion behavior between the boundaries of each invocation and between source and destination

places. The language must, however, express what constitutes completeness for each invocation boundary.

12.5.1 Full Completeness The simplest completeness relation is that content be present at all places of each list. An invocation begins when there is content in all of its destination places. An invocation is completed when there is content in all of its source places. A list with no additional syntax implies full completeness.
12.5.2 Mutually Exclusive Completeness Relations
in pure association expression with multi-path representation where a group of places mutually exclusively assert a value. This is expressed by enclosing the mutually exclusive group of places in braces. In the definition given in Example 12.9 content in exactly one of A0< >, or A1< > and one of B0< >, or B1< > is completeness for the source list and content in one of $0, or $1 is completeness for the destination list.

## 12.5.3 Conditional Completeness

Conditional completeness is expressed when the content of one place in a list, which must always be complete, determines the completeness relations of other places in the list delimited by braces. **Conditional Input** Conditional input is shown in Example 12.10. The invocation of fan-in will pass $in1, $in2, $in3, or $in4 depending on the content of $select, which can be A, B, C, or D.

The content of select< > will form an invocation name in the place of resolution. The invoked definition will return an expression fragment that directs the content of one of the input places to the output destination place. Only one of $in1, $in2, $in3, or $in4 needs content for completeness. The braces explicitly express this completeness relation. Input completeness is a $select content and content of the selected source place. The mutually exclusive completeness relationships are also reflected in the definition lists. The unselected places may or may not have content. If a place has content and is not selected, its content will be retained until a presentation occurs that does select it. **Conditional Output** Conditional output can also be expressed as shown in Example 12.11. The invocation of fan-out will pass $input to output1< >,

Na H ATA TURES
Invocation so
Definition OAC
a symb trigrretion
Destination list

| Invocation | place1 | place2 |  | Source list |  |
| --- | --- | --- | --- | --- | --- |
|  | S | S | place3 |  |  |
|  |  |  | S | placeA | placeB |
|  |  |  |  | <> | <> |

Definition

| くン | <> |  |  |  |
| --- | --- | --- | --- | --- |
| A | B | <> C | S |  |
|  |  | result1 |  | result2 |

Source list Destination list
b. Graphic representation
ABC[(A<$place1>B<$place2>C<$place3>)(placeA<Sresult1>placeB<Sresult..
c. Merged string representation
Figure 12.5 The syntactic association of invocation to definition.
invocation FULLADD(., 1 )0< CARRYOUT<).SCARRYOUT
FULLADDI(X<>Y<>C<>)(SUM$CARRY)
definition
Exicin
and De nition

output2< >, output3< >, or output4< > depending on the content of select< >. Output completeness is exactly one of output1< >, output2< >, output3< >, or output4< >. The braces explicitly express this completeness criterion. The mutually exclusive completeness relationships are also reflected in the definition lists. **Serial Bus**: Fan-in/Fan-out Expression Example 12.12 is a serial bus expressed by two invocations associating the output of a fan-in with the input of a fan-out. **Parallel Bus**: Fan-out/Fan-in Expression Example 12.13 is a parallel bus expressed by associating the output of multiple fan-outs with the input of multiple fan-ins. The outA's and outB's of the fan-out invocations associate to the inputs of the fan-in invocations.

## 12.5.4 Arbitration Completeness

Arbitration manages the content flow of two or more places of uncoordinated flow into a single coordinated flow. If all the arbitrated places have content simultaneously, the places will compete for the privilege of flowing through the arbiter. It cannot be predetermined which content will flow. Contents that lose the competition will remain and wait their turn or participate in the next competition. If only one place has content, the content will flow through the arbiter without competition. The arbitrated places are encompassed with double braces in the invocation destination list. The double-braced list of destination places associates to a single-source place in the definition source list. Example 12.14 is an expression that arbitrates the content flow of $place1 and $place2. The arbitrated content flows into placeB< >, through the expression in the place of resolution and out through $pass back to next< >. The uncoordinated flow into Place1 and place2 becomes a coordinated flow out of next< >.

12.5.5 Complex Completeness Relationships There can arise circumstances of more complex completeness relationships. An ALU is one of these. The ALU is a locality of multiple possibilities associated by a single command content. While this is an artifact of sequentiality, the language should encompass it. Each function in the ALU can take different configurations of input and assert different configurations of output. Not all inputs of the ALU are always used, and not all outputs are always asserted. What needs to be expressed in the context of the definition is the completeness relationships for each possible configuration of the ALU. The questions to be answered are, What are the completeness relations for each list, and how does the completeness relations of the destination list relate to the completeness relations of the source list? This is the critical information to configure a coordination protocol between the source list (the output of the invocation) and the destination list (the input of the invocation). With these relationships expressed, any form of coordination from cycles to clocks can be automatically added to the expression. Example 12.15 shows the definition for an ALU that receives a command whose content is always complete and one to three other inputs. There are seven commands: shift left(SL), shift right(SR), NOT, AND, OR, XOR, and ADD. Each command can involve a different input and output completeness

Na H ATA TURES
Invocation so
Definition OAC
a symb trigrretion
Destination list

| Invocation | place1 | place2 |  | Source list |  |
| --- | --- | --- | --- | --- | --- |
|  | S | S | place3 |  |  |
|  |  |  | S | placeA | placeB |
|  |  |  |  | <> | <> |

Definition

| くン | <> |  |  |  |
| --- | --- | --- | --- | --- |
| A | B | <> C | S |  |
|  |  | result1 |  | result2 |

Source list Destination list
b. Graphic representation
ABC[(A<$place1>B<$place2>C<$place3>)(placeA<Sresult1>placeB<Sresult..
c. Merged string representation
Figure 12.5 The syntactic association of invocation to definition.
invocation FULLADD(., 1 )0< CARRYOUT<).SCARRYOUT
FULLADDI(X<>Y<>C<>)(SUM$CARRY)
definition
Exicin
and De nition

relation. The shifts and NOT take one input and assert one output, the logic functions take in two inputs and assert one output, and the ADD takes in three inputs and asserts two outputs. Each completeness relation is expressed as a sublist of places enclosed in parenthesis. All of the places of a sublist must have content for completeness. The seven sublists are enclosed in braces, indicating that only one of the sub-lists will have content. Each sublist is then labeled with the enabling command content. Completeness for the source list is content in the command place and complete content in one of the sublists. Completeness for the destinationlist is complete content in one of the sublists. The destination list is structured identically to the source list with a corresponding order of sublists.

## 12.5.6 The Occasional Output

An expression might resolve a multitude of presentations before asserting an output. A code detector, for instance, might only occasionally assert "detect." Consider that an expression always asserts a "yes" or a "no" and that only the "yes" is to be passed on. A response filter expression, shown in Example 12.16, can receive an answer containing "yes" or "no" and only pass on the "yes" content. When the content is "no", an empty content is returned to the place of resolution, to $NO and to NO< >,which expresses completeness for the invocation but does not

associate with any destination place in the expression. NO< > is a dead-end association. When a "yes" is received, a "yes" content is returned, passed on through $YES to OK< > in the invocation, and continues to $OK.

Here is the extracted text from the image:

Example 12.16 Example with occasional source place.

relation. The shifts and NOT take one input and assert one output, the logic functions take in two inputs and assert one output, and the ADD takes in three inputs and asserts two outputs.

Each completeness relation is expressed as a sublist of places enclosed in parenthesis. All of the places of a sublist must have content for completeness. The seven sublists are enclosed in braces, indicating that only one of the sub-lists will have content. Each sublist is then labeled with the enabling command content.

Completeness for the source list is content in the command place and complete content in one of the sublists. Completeness for the destinationlist is complete content in one of the sublists. The destination list is structured identically to the source list with a corresponding order of sublists.

### 12.5.6 The Occasional Output

An expression might resolve a multitude of presentations before asserting an output. A code detector, for instance, might only occasionally assert "detect." Consider that an expression always asserts a "yes" or a "no" and that only the "yes" is to be passed on. A response filter expression, shown in Example 12.16, can receive an answer containing "yes" or "no" and only pass on the "yes" content. When the content is "no", an empty content is returned to the place of resolution, to $NO and to NO< >,which expresses completeness for the invocation but does not associate with any destination place in the expression. NO< > is a dead-end association. When a "yes" is received, a "yes" content is returned, passed on through $YES to OK< > in the invocation, and continues to $OK.

12.6 BUNDLED CONTENT Bracket pairs nested within a source list of a definition indicate unbundling of content from a single destination place in the invocation destination list. Each bracket pair associates with a single destination place of an invocation. Bracket pairs nested within a destination list of a definition indicate bundling of content into a single source place in the invocation source list. Each bracket pair associates with a single source place in the invocation source list. Bundling is a convenient convention when many association relationships follow an identical flow path as with a multi-value paths of a pure association expression or digits of place-value numbers.

Example 12.17 shows an example of bundling and mutual exclusion. The definition of the OR is in terms of dual-rail coding. The two rails are bundled in places A and B of the invocation. The two bracket pairs in the source list of the definition associate with the $A and $B of the invocation. A0< > A1< > are unbundled from $A. B0< > B1< > are unbundled from $B. A0< > and A1< > enclosed in braces are mutually exclusive as are B0< > and B1< >. $0 and $1 in the destination list of the definition are bundled and associate with Y< > in the source list of the invocation.

The multi-rail representations are bundled and conveniently expressed as a single place at the next higher composition level. Later in this chapter Example 12.27, a pure association expression of a full-adder, shows this usage. At the Boolean function level the expression is in terms of paths with bundled content. In the definition of each Boolean function the paths are unbundled and expressed as explicitly dual-rail paths.

Bundling can be used for any common association path. Example 12.18 shows the bundling and unbundling of a four-digit number. The places in the

invocation are bundled, and the places in the definition are unbundled. The source places A0 through A3 are unbundled from $A. The sum destination places SUM0 through SUM3 are

bundled into SUM< >. The Ax's and Bx's might be dual-rail representation and might be further unbundled into their dual-rail components as in Example 12.17.

The bundling brackets follow the bundled content delimiting the content into nested levels of bundling. Each level of bundling adds outermost brackets. Each level of unbundling strips the outermost brackets from the bundled content.

12.7 EXPRESSION STRUCTURE
Figure 12.6 shows the component structures of an example expression. There are some
 outlying source places and destination places. They associate with an invocation of ProcX. There is a definition of ProcX with a source list and a destination list. The resolution place of the definition contains an invocation of ProcA within a source place named result2. The place of contained definitions contains the definition of ProcA that itself contains a set of value transform rule definitions. The arrows show the association relationships and the flow of content. The content 1, 0, 1 is formed in the destination list of the invocation of ProcX flowing from source places place1< >, place2< >, and place3< > to destination places $place1, $place2, and $place3. The content flows into the definition of ProcX through source places A< >, B< >, and C< > and into the destination

places $A, $B, and $C in the invocation of ProcA in the place of resolution. The contents then flow into the source places X< >, Y< >, and Z< >, of the ProcA definition, and then into the destination places $X, $Y, and $Z in the place of resolution of ProcA forming the invocation 101(), which invokes the definition 101[1], which returns the value 1, which then flows out of the definition of ProcA to the place of the ProcA invocation becoming the content of the source place result2< >, then to the destination place $result2, to the source place placeB< > in the invocation of ProcX, and on to the destination place $placeB.

The gray arrows indicate name correspondence associations, and the black arrows indicate syntax structure associations. The black ring is neighbor association. The alternating shades along association paths show the alternation between name correspondence association and syntax structure association, each extending the reach of the other and weaving a network of association pathways through the invocations and definitions.

12.7.1 Name Correspondence Search The language assumes a search behavior to match correspondence names. Some name correspondence association relationships are static, and the search for corresponding names in the string can be carried out by a language processor and mapped to a direct association

relationship such as a wire in the autonomous expression. For some association relationships the correspondence name is not expressed until the time of resolution when a name emerges from a content path. So the search must be integral to the resolution behavior. These searches can be mapped to efficient search expressions in the autonomous expression such as a combinational logic expression, a MUX, the addressing behavior of a conventional memory, or a shaking bag.

12.7.2 Scope of Correspondence Name Reference A definition forms a syntactically isolated correspondence name domain for source places and destination places. To maintain the integrity of association relationships and content flow, all content flow into and out of a definition must flow through the syntactic interface with an invocation. Place correspondence names do not cross definition boundaries. However, the correspondence of invocationnames to definitionnames can have a larger scope of reference. It is convenient to assume hierarchical scope of reference rules for invocationnames. The search for the corresponding definitionname can progress up the hierarchy of nested definitions until a match is found. No matter where in the hierarchy a definition is found, it can be considered to be instantiated at the place of the invocation. This allows the expression and invocation of common definitions in the language.