// linear: TAG-137 Four-value sequencer
fourstate($value)(value< 0 >) . . .$value

fourstate[(curvalue < >)($nextvalue)
  nextvalue <$curvalue( )> : 0[1] 1[2] 2[3] 3[0] ] 