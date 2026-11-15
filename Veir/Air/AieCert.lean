module

public import Veir.Air.Aie
public import Std.Data.HashMap

namespace Veir.Air.Aie

@[expose] public section

/-! # C6: what the AIE exploration proves

The AIE model's semantics (`AIE_SEMANTICS.md`, T1-T10) is the step function `Model.steps`, each
step followed by the moves with no effect (`Model.settle`). A state is final once a core faulted
or the runtime sequence finished (the host then reads its memory). `Reach` is the set of states an
execution reaches.

An exploration answers with a certificate, checked here:
- **every listed state is reachable** (`parents_sound`): each state but the first names a listed
  parent and which of its successors it is, and that is recomputed;
- **every reachable state is listed** (`closed_complete`), when the list is closed under
  successors: each listed state's successors are listed. Membership is decided by equality of
  states, bucketed by `St.key`; a hash collision cannot make the check pass.

Together: the outcomes and deadlocks read off the listed states are exactly those of the model.
With partial-order reduction (`Model.stubborn`) the list is not closed, and only the first
statement holds: every reported outcome, deadlock or fault is real, but there may be more. The
reduction itself is not proven.

What is not proven: that `Model.steps`, `Model.settle` and `Model.extract` say what T1-T10 say.
They are the definitions.
-/

/-- The successors of a state: none once it is final. -/
def Model.post (m : Model) (s : St) : Array St :=
  if s.fault.isSome || s.rtPc ≥ m.runtime.size then #[]
  else (m.steps s).map fun (_, s') => m.settle s'

def Model.start (m : Model) : St := m.settle m.init

/-- The states an execution reaches. -/
inductive Reach (m : Model) : St → Prop
  | init : Reach m m.start
  | step {s : St} {i : Nat} {s' : St} : Reach m s → (m.post s)[i]? = some s' → Reach m s'

/-- An exploration's answer: the states, and for each but the first, its parent and which
successor of the parent it is. -/
structure Cert where
  states : Array St
  parent : Array (Nat × Nat)

/-- The first state is the start; every other is a successor of an earlier one. -/
def Cert.parentsB (m : Model) (c : Cert) : Bool :=
  c.states.size > 0 && decide (c.states[0]! = m.start) && c.parent.size == c.states.size &&
  (List.range c.states.size).all fun i =>
    i == 0 ||
      match c.parent[i]?, c.states[i]? with
      | some (p, j), some s => decide (p < i) && match c.states[p]? with
        | some sp => decide ((m.post sp)[j]? = some s)
        | none => false
      | _, _ => false

theorem Cert.parents_sound {m : Model} {c : Cert} (h : c.parentsB m = true) :
    ∀ (i : Nat) (s : St), c.states[i]? = some s → Reach m s := by
  simp only [Cert.parentsB, Bool.and_eq_true, decide_eq_true_eq, beq_iff_eq, List.all_eq_true,
    List.mem_range, Bool.or_eq_true] at h
  obtain ⟨⟨⟨hpos, h0⟩, _⟩, hall⟩ := h
  intro i
  induction i using Nat.strongRecOn with
  | ind i ih =>
    intro s hs
    have hi : i < c.states.size := by
      rcases Nat.lt_or_ge i c.states.size with h' | h'
      · exact h'
      · simp [Array.getElem?_eq_none h'] at hs
    rcases hall i hi with h' | h'
    · subst h'
      have : c.states[0]! = s := by
        rw [getElem!_pos c.states 0 hpos]
        simp only [Array.getElem?_eq_getElem hpos, Option.some.injEq] at hs
        exact hs
      rw [← this, h0]
      exact .init
    · split at h'
      · next p j s' hp hs' =>
        rw [hs] at hs'
        cases hs'
        simp only [Bool.and_eq_true, decide_eq_true_eq] at h'
        obtain ⟨hpi, h'⟩ := h'
        split at h'
        · next sp hsp =>
          simp only [decide_eq_true_eq] at h'
          exact .step (ih p hpi sp hsp) h'
        · simp at h'
      · simp at h'

/-! ### Membership, by key then equality -/

def bucketStep (b : Std.HashMap UInt64 (List St)) (s : St) : Std.HashMap UInt64 (List St) :=
  b.insert s.key (s :: b.getD s.key [])

def buckets (ss : List St) : Std.HashMap UInt64 (List St) := ss.foldl bucketStep {}

theorem buckets_sub (ss : List St) (b₀ : Std.HashMap UInt64 (List St)) (k : UInt64) :
    ∀ t ∈ (ss.foldl bucketStep b₀).getD k [], t ∈ b₀.getD k [] ∨ t ∈ ss := by
  induction ss generalizing b₀ with
  | nil => intro t ht; exact Or.inl ht
  | cons s ss ih =>
    intro t ht
    rcases ih (bucketStep b₀ s) t ht with h | h
    · simp only [bucketStep, Std.HashMap.getD_insert] at h
      split at h
      · simp only [List.mem_cons] at h
        rcases h with rfl | h
        · exact Or.inr (List.mem_cons_self ..)
        · next hk => simp only [beq_iff_eq] at hk; rw [hk] at h; exact Or.inl h
      · exact Or.inl h
    · exact Or.inr (List.mem_cons_of_mem _ h)

def memB (b : Std.HashMap UInt64 (List St)) (s : St) : Bool :=
  (b.getD s.key []).any fun t => decide (t = s)

theorem memB_sound {ss : List St} {s : St} (h : memB (buckets ss) s = true) : s ∈ ss := by
  simp only [memB, List.any_eq_true, decide_eq_true_eq] at h
  obtain ⟨t, ht, rfl⟩ := h
  rcases buckets_sub ss {} t.key t ht with h | h
  · simp at h
  · exact h

/-- Every listed state's successors are listed, and so is the start. -/
def Cert.closedB (m : Model) (c : Cert) : Bool :=
  let b := buckets c.states.toList
  memB b m.start && c.states.all fun s => (m.post s).all (memB b)

theorem Cert.closed_complete {m : Model} {c : Cert} (h : c.closedB m = true) :
    ∀ s, Reach m s → s ∈ c.states.toList := by
  simp only [Cert.closedB, Bool.and_eq_true, Array.all_eq_true] at h
  obtain ⟨h0, hall⟩ := h
  intro s r
  induction r with
  | init => exact memB_sound h0
  | @step s i s' _ hs' ih =>
    have hsa : s ∈ c.states := by simpa using ih
    obtain ⟨k, hk, hks⟩ := Array.getElem_of_mem hsa
    have := hall k hk
    rw [hks] at this
    have hi : i < (m.post s).size := by
      rcases Nat.lt_or_ge i (m.post s).size with h' | h'
      · exact h'
      · simp [Array.getElem?_eq_none h'] at hs'
    have hmem := this i hi
    simp only [Array.getElem?_eq_getElem hi, Option.some.injEq] at hs'
    rw [hs'] at hmem
    exact memB_sound hmem

/-- **What a checked, closed certificate buys**: its states are exactly the reachable ones. -/
theorem Cert.exact {m : Model} {c : Cert} (hp : c.parentsB m = true) (hc : c.closedB m = true)
    (s : St) : Reach m s ↔ s ∈ c.states.toList := by
  constructor
  · exact c.closed_complete hc s
  · intro hs
    obtain ⟨i, hi, rfl⟩ := List.getElem_of_mem hs
    exact c.parents_sound hp i _ (by simp)

/-! ### Producing a certificate (not proven; checked above) -/

/-- Explore depth first, keeping every distinct state with its parent, up to `limit` states.
With `por`, only a stubborn set of successors is followed. Returns the certificate and whether
the limit was hit. -/
partial def Model.exploreCert (m : Model) (limit : Nat := 200000) (por : Bool := true) :
    Cert × Bool := Id.run do
  let feet := m.feet
  let s0 := m.start
  let mut states : Array St := #[s0]
  let mut parent : Array (Nat × Nat) := #[(0, 0)]
  let mut index : Std.HashMap UInt64 (List Nat) := ({} : Std.HashMap UInt64 (List Nat)).insert s0.key [0]
  let mut stack : List Nat := [0]
  let mut hitLimit := false
  while !stack.isEmpty do
    let i := stack.head!
    stack := stack.tail
    let s := states[i]!
    let post := m.post s
    if post.isEmpty then continue
    -- With partial-order reduction, follow a stubborn subset (by position among `post`).
    let chosen : List Nat :=
      if por then
        let all := m.steps s
        let keep := m.stubborn feet s all
        (List.range all.size).filter fun j => keep.any fun (_, t) =>
          decide (m.settle t = post[j]!)
      else List.range post.size
    for j in chosen do
      let s' := post[j]!
      let k := s'.key
      if (index.getD k []).any fun q => decide (states[q]! = s') then continue
      if states.size ≥ limit then
        hitLimit := true
        break
      index := index.insert k (states.size :: index.getD k [])
      parent := parent.push (i, j)
      stack := states.size :: stack
      states := states.push s'
    if hitLimit then break
  return ({ states, parent }, hitLimit)

/-- The labels from the start to state `i`, through the parents. -/
partial def Cert.traceTo (m : Model) (c : Cert) (i : Nat) : Array String := Id.run do
  let mut path : List String := []
  let mut j := i
  for _ in [0:c.states.size] do
    if j == 0 then break
    let (p, k) := c.parent[j]!
    let sp := c.states[p]!
    let labels := (m.steps sp).map (·.1)
    path := (match labels[k]? with | some l => m.showLabel l | none => "?") :: path
    j := p
  return path.toArray

end

end Veir.Air.Aie
