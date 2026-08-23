// linear: TAG-151 Bundling mutually exclusive path into a single path
OR($A $B)(Y< >)
  : OR[( [{A0< > A1< >}] [{B0< > B1< >}] ) ( [{$0 $1}] )
     1< 3of6($A1 $A1 $A0 $B0 $B1 $B1) >
     0< 2of2($A0 $B0) > : ]