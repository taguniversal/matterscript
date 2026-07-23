
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
  $a$b() : generate {
    clamp($a + $b, 0, 6)
    inputs: $a 0..3, $b 0..3
    output: 0..6
  }
]

add((1 3)(x<>))