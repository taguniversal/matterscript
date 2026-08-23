// linear: TAG-147 Parallel bus
fanout($seloutA $srcA)({outA1< > outA2< > outA3< > outA4< > outA5<

     >)

fanout($seloutB $srcB)({outB1< > outB2< > outB3< > outB4< > outB5< >})
fanin($selin1 {$outA1 $outB1})(dest1< >)
fanin($selin2 {$outA2 $outB2})(dest2< >)
fanin($selin3 {$outA3 $outB3})(dest3< >)
fanin($selin4 {$outA4 $outB4})(dest4< >)
fanin($selin5 {$outA5 $outB5})(dest5< >)