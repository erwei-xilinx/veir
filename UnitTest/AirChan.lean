import Veir.Air.ChanFast

/-! Tests for the channel semantics (`Veir.Air.ChanSem`, `Veir.Air.ChanMem`): small programs whose
answer is known, and the axioms the theorems rest on. -/

open Veir.Air Veir.Air.Chan

/-- D51 (confirmed 2026-11-14). An async put of 4 elements; a sync get takes elements 0-1; an
async get after it in program order takes elements 2-3. Elements 0-1 are buffered (their get is
sync), 2-3 meet. It completes. -/
private def d51 : Prog where
  graph := ⟨#[[], [], [1]]⟩
  elems := #[⟨some 0, [some 1], none, true⟩, ⟨some 0, [some 1], some 0, true⟩,
             ⟨some 0, [some 2], some 1, false⟩, ⟨some 0, [some 2], some 2, false⟩]

#guard check d51 == some true

/-- AIR-011's shape: an async put and an async get on one subchannel, and a token making the get
wait for the put. Unbuffered (D30): the put cannot finish before the get starts. -/
private def air011 : Prog where
  graph := ⟨#[[], [0]]⟩
  elems := #[⟨some 0, [some 1], none, false⟩]

#guard check air011 == some false

-- The same with the get sync: buffered (D30), so it completes.
#guard check { air011 with elems := #[⟨some 0, [some 1], none, true⟩] } == some true

/-- D34: an async put with an element no get takes cannot finish; a sync one can. -/
private def orphan (b : Bool) : Prog where
  graph := ⟨#[[]]⟩
  elems := #[⟨some 0, [none], none, b⟩]

#guard check (orphan false) == some false
#guard check (orphan true) == some true

-- A get waiting for an element no put provides never finishes.
#guard check { graph := ⟨#[[]]⟩, elems := #[⟨none, [some 0], none, true⟩] } == some false

/-! ### Axioms

Nothing depends on `sorryAx` or on `Lean.ofReduceBool`. -/

/--
info: 'Veir.Air.Chan.completes_from_anywhere' depends on axioms: [propext, Quot.sound]
-/
#guard_msgs in
#print axioms completes_from_anywhere

/--
info: 'Veir.Air.Chan.check_true' depends on axioms: [propext, Quot.sound]
-/
#guard_msgs in
#print axioms check_true

/--
info: 'Veir.Air.Chan.check_false' depends on axioms: [propext, Quot.sound]
-/
#guard_msgs in
#print axioms check_false

/--
info: 'Veir.Air.Chan.deterministic' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in
#print axioms Veir.Air.Chan.deterministic

/--
info: 'Veir.Air.Chan.outcome_unique' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in
#print axioms outcome_unique

/--
info: 'Veir.Air.Chan.checkH_true' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in
#print axioms checkH_true

/--
info: 'Veir.Air.Chan.checkH_false' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in
#print axioms checkH_false

/--
info: 'Veir.Air.Chan.raceFree_of_racesOk' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in
#print axioms raceFree_of_racesOk

/--
info: 'Veir.Air.Chan.outcome_uniqueH' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in
#print axioms outcome_uniqueH

-- The fast check agrees with the reference check on the examples above.
private def fastCheck (p : Prog) : Option Bool := checkH p (buildIndex p) (genTrace p (buildIndex p))
#guard fastCheck d51 == some true
#guard fastCheck air011 == some false
#guard fastCheck (orphan false) == some false
#guard fastCheck (orphan true) == some true

/-- D29: an async put broadcast to two async gets. Unbuffered: one transfer reaches both at once,
so if one get waits for the other to finish, nothing moves. -/
private def bcast (dep : Bool) : Prog where
  graph := ⟨#[[], [], if dep then [1] else []]⟩
  elems := #[⟨some 0, [some 1, some 2], none, false⟩]

#guard check (bcast false) == some true
#guard check (bcast true) == some false
#guard fastCheck (bcast false) == some true
#guard fastCheck (bcast true) == some false
