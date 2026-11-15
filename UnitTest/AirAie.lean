import Veir.Air.AieCert

/-! The axioms the C6 exploration's certificate theorems rest on (`Veir.Air.AieCert`). -/

open Veir.Air.Aie

/--
info: 'Veir.Air.Aie.Cert.parents_sound' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in
#print axioms Cert.parents_sound

/--
info: 'Veir.Air.Aie.Cert.closed_complete' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in
#print axioms Cert.closed_complete

/--
info: 'Veir.Air.Aie.Cert.exact' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in
#print axioms Cert.exact
