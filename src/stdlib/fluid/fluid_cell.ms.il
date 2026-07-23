// stdlib/fluid/fluid_cell.ms.il
// Models a single coolant channel segment.
// Destinations: upstream pressure $p_in, upstream velocity $v_in
// Sources: downstream pressure p_out<>, downstream velocity v_out<>
//
// The lookup table encodes simplified Bernoulli flow:
// higher inlet pressure and velocity produce proportional outlet values.
// Channel resistance is encoded by the table entries — narrow channels
// map high inlet values to lower outlet values.

FluidCell[($p_in $v_in)(p_out<> v_out<>)
  p_out<$p_in$v_in()>
  v_out<$v_in$p_in()>
|
  // pressure out: function of inlet pressure and velocity
  // key: p_in (0-7) concatenated with v_in (0-7)
  // value: outlet pressure after channel resistance
  $p_in$v_in() :
    00:0 01:0 02:1 03:1 04:2 05:2 06:3 07:3
    10:1 11:1 12:2 13:2 14:3 15:3 16:4 17:4
    20:2 21:2 22:3 23:3 24:4 25:4 26:5 27:5
    30:3 31:3 32:4 33:4 34:5 35:5 36:6 37:6
    40:4 41:4 42:5 43:5 44:6 45:6 46:7 47:7
    50:4 51:5 52:5 53:6 54:6 55:7 56:7 57:7
    60:5 61:5 62:6 63:6 64:7 65:7 66:7 67:7
    70:6 71:6 72:7 73:7 74:7 75:7 76:7 77:7

  // velocity out: function of velocity and pressure gradient
  $v_in$p_in() :
    00:0 01:1 02:1 03:2 04:2 05:3 06:3 07:4
    10:1 11:1 12:2 13:2 14:3 15:3 16:4 17:4
    20:1 21:2 22:2 23:3 24:3 25:4 26:4 27:5
    30:2 31:2 32:3 33:3 34:4 35:4 36:5 37:5
    40:2 41:3 42:3 43:4 44:4 45:5 46:5 47:6
    50:3 51:3 52:4 53:4 54:5 55:5 56:6 57:6
    60:3 61:4 62:4 63:5 64:5 65:6 66:6 67:7
    70:4 71:4 72:5 73:5 74:6 75:6 76:7 77:7
]