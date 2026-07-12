
// add.ms.il
// Simple adder in MatterScript Invocation Language
// Based on Karl Fant's Invocation Language from Computer Science Reconsidered
//
// add takes two 2-bit integers (0-3) and produces their sum (0-6)
// The result flows out as a source place once both inputs are complete.
//
// Name composition: $a and $b are bound to their values at invocation time,
// so $a$b() with a=1 and b=3 composes the name "13" and looks it up
// in the constant table, returning 4.
//
// Completeness: result<> remains NULL until $a$b() resolves.
// If either $a or $b is NULL the composition never fires — correct NCL behavior.

add[($a $b)(result<>)
  result<$a$b()>
|
  $a$b() : 00:0 01:1 02:2 03:3
            10:1 11:2 12:3 13:4
            20:2 21:3 22:4 23:5
            30:3 31:4 32:5 33:6
]

// entry invocation: add 1 + 3, result flows into x<>
add((1 3)(x<>))

