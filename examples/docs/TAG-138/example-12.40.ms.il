// linear: TAG-138 The invocation expression of the greatest common divisor

GCD(MN) ( GCD< > )

GCD[(M< > N< > ) ($GCD)

init< 0 >

LTsteer($M,$N)(inlesser< > ingreater< > )

dualfanin($incondition {inlesserremainder}{ingreatercyclelesser})

(lesser< > greater< > )

Mod(cyclelessercyclegreater)(remainder< > )

EQ0({lesserinit})(incondition< > outcondition< > )

dualfanout($outcondition lessergreater)
  ({cyclelesser< > cyclegreater< > } ( SINK< > GCD< >) )

dualfanin[(steer< > ){A< > B< >}{C< > D< >}]($out1 $out2)
   $steer( ) : True[out1< $A > out2<$B >]
               False[out1< $C > out2<$D >] ]

dualfanout[(steer< > A< > B< >)({$out1 $out2} {$out3 $out4})
   $steer( ) :  True[out1< $A > out2<$B >]
                False[out3< $B > out4<$A >] ]

EQ0[(A<>)($condition $condition)
  condition<Equal($A,0)>:]

LTsteer[(A< > B< >)
  LT($A $B) : True[out1< $A > out2<$B >
              False[out1< $B > out2<$A >] ] ]