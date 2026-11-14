module

public import Veir.Air.Events
public import Veir.Air.Race

namespace Veir.Air

@[expose] public section

/-! # Race-free programs are deterministic

Memory is a function from locations (buffer, element) to values. Each event's effect is a
function on memory, applied when it finishes; starting does nothing. The effects are *framed* by
the footprint: an event changes only what it declares it writes, and what it writes depends only
on what it declares it reads.

`deterministic`: if no two unordered events conflict, every complete execution ends with the same
memory, whatever the schedule. This is checklist C3 for memory, and the event-level half of D7.
D7 itself, about interleavings *inside* event bodies, is not proven here.

The proof: two events with no token path between them, in a race-free program, do not conflict,
so their effects commute (`effects_commute`). Any two finishing orders the graph allows are then
related by swapping adjacent unordered events (`runEffects_eq`).
-/

variable {V : Type}

abbrev Loc := Nat × Int
abbrev Mem (V : Type) := Loc → V

def Footprint.Reads (fp : Footprint) (v : Nat) (l : Loc) : Prop :=
  ∃ a ∈ fp v, a.kind = .read ∧ a.buf = l.1 ∧ l.2 ∈ a.elems

def Footprint.Writes (fp : Footprint) (v : Nat) (l : Loc) : Prop :=
  ∃ a ∈ fp v, a.kind = .write ∧ a.buf = l.1 ∧ l.2 ∈ a.elems

/-- `eff v` writes only `v`'s write set, and what it writes there depends only on its read set. -/
structure Framed (fp : Footprint) (eff : Nat → Mem V → Mem V) : Prop where
  outside : ∀ v m l, ¬ fp.Writes v l → eff v m l = m l
  inputs : ∀ v m m', (∀ l, fp.Reads v l → m l = m' l) → ∀ l, fp.Writes v l → eff v m l = eff v m' l

theorem not_conflict_ww {fp : Footprint} {u v : Nat} {l : Loc} (h : ¬ EventsConflict fp u v)
    (hu : fp.Writes u l) (hv : fp.Writes v l) : False := by
  obtain ⟨a, ha, hak, hab, hax⟩ := hu
  obtain ⟨b, hb, hbk, hbb, hbx⟩ := hv
  exact h ⟨a, ha, b, hb, hab.trans hbb.symm, Or.inl hak, l.2, hax, hbx⟩

theorem not_conflict_wr {fp : Footprint} {u v : Nat} {l : Loc} (h : ¬ EventsConflict fp u v)
    (hu : fp.Writes u l) (hv : fp.Reads v l) : False := by
  obtain ⟨a, ha, hak, hab, hax⟩ := hu
  obtain ⟨b, hb, _, hbb, hbx⟩ := hv
  exact h ⟨a, ha, b, hb, hab.trans hbb.symm, Or.inl hak, l.2, hax, hbx⟩

theorem not_conflict_rw {fp : Footprint} {u v : Nat} {l : Loc} (h : ¬ EventsConflict fp u v)
    (hu : fp.Reads u l) (hv : fp.Writes v l) : False := by
  obtain ⟨a, ha, _, hab, hax⟩ := hu
  obtain ⟨b, hb, hbk, hbb, hbx⟩ := hv
  exact h ⟨a, ha, b, hb, hab.trans hbb.symm, Or.inr hbk, l.2, hax, hbx⟩

/-- **Non-conflicting effects commute.** -/
theorem effects_commute {fp : Footprint} {eff : Nat → Mem V → Mem V} (hfr : Framed fp eff)
    {u v : Nat} (hnc : ¬ EventsConflict fp u v) (m : Mem V) :
    eff u (eff v m) = eff v (eff u m) := by
  funext l
  by_cases hu : fp.Writes u l
  · have hv : ¬ fp.Writes v l := fun hv => not_conflict_ww hnc hu hv
    rw [hfr.outside v _ l hv]
    exact hfr.inputs u _ _ (fun l' hr => hfr.outside v m l' fun hw => not_conflict_rw hnc hr hw) l hu
  · by_cases hv : fp.Writes v l
    · rw [hfr.outside u _ l hu]
      exact (hfr.inputs v _ _ (fun l' hr => hfr.outside u m l' fun hw => not_conflict_wr hnc hw hr)
        l hv).symm
    · rw [hfr.outside u _ l hu, hfr.outside v _ l hv, hfr.outside v _ l hv, hfr.outside u _ l hu]

def runEffects (eff : Nat → Mem V → Mem V) (l : List Nat) (m : Mem V) : Mem V :=
  l.foldl (fun m v => eff v m) m

/-! ### Finishing orders -/

/-- `Valid g done l`: after the events in `done`, the events of `l` can finish in order, each
after everything it waits for. -/
inductive Valid (g : DepGraph) : List Nat → List Nat → Prop
  | nil (done : List Nat) : Valid g done []
  | cons {done : List Nat} {v : Nat} {l : List Nat} :
      v < g.size → v ∉ done → (∀ u ∈ g.predsOf v, u ∈ done) → Valid g (v :: done) l →
      Valid g done (v :: l)

/-- Everything a member of `done` waits for is in `done`. -/
def Closed' (g : DepGraph) (done : List Nat) : Prop :=
  ∀ v ∈ done, ∀ u ∈ g.predsOf v, u ∈ done

namespace Valid

variable {g : DepGraph}

theorem not_mem_done {done l : List Nat} (h : Valid g done l) : ∀ x ∈ l, x ∉ done := by
  induction h with
  | nil => simp
  | cons _ hnd _ _ ih =>
    intro x hx
    simp only [List.mem_cons] at hx
    rcases hx with rfl | hx
    · exact hnd
    · exact fun hd => ih x hx (List.mem_cons_of_mem _ hd)

theorem nodup {done l : List Nat} (h : Valid g done l) : l.Nodup := by
  induction h with
  | nil => exact List.nodup_nil
  | @cons done v l _ _ _ hl ih =>
    refine List.nodup_cons.mpr ⟨fun hv => ?_, ih⟩
    exact hl.not_mem_done v hv (List.mem_cons_self ..)

theorem lt {done l : List Nat} (h : Valid g done l) : ∀ x ∈ l, x < g.size := by
  induction h with
  | nil => simp
  | cons hlt _ _ _ ih =>
    intro x hx
    simp only [List.mem_cons] at hx
    rcases hx with rfl | hx
    · exact hlt
    · exact ih x hx

theorem congr_done {done done' l : List Nat} (h : Valid g done l)
    (heq : ∀ y, y ∈ done ↔ y ∈ done') : Valid g done' l := by
  induction h generalizing done' with
  | nil => exact .nil _
  | cons hlt hnd hp _ ih =>
    refine .cons hlt (fun hd => hnd ((heq _).mpr hd)) (fun u hu => (heq u).mp (hp u hu)) ?_
    apply ih
    intro y
    simp only [List.mem_cons]
    exact or_congr Iff.rfl (heq y)

/-- Take `a` out of an order and run it first instead: everything still runs after what it waits
for, since nothing before `a` waits for it. -/
theorem remove {done xs ys : List Nat} {a : Nat} (h : Valid g done (xs ++ a :: ys)) :
    Valid g (a :: done) (xs ++ ys) := by
  induction xs generalizing done with
  | nil =>
    cases h with
    | cons _ _ _ hl => exact hl
  | cons x xs ih =>
    cases h with
    | cons hlt hnd hp hl =>
      have hne : x ≠ a := by
        intro hxa
        subst hxa
        exact hl.not_mem_done x (List.mem_append_right _ (List.mem_cons_self ..))
          (List.mem_cons_self ..)
      refine .cons hlt ?_ (fun u hu => List.mem_cons_of_mem _ (hp u hu)) ?_
      · simp only [List.mem_cons, not_or]
        exact ⟨hne, hnd⟩
      · apply (ih hl).congr_done
        intro y
        simp only [List.mem_cons]
        constructor <;> intro h <;> rcases h with h | h | h <;> simp [h]

/-- Appending an event that is ready after `done` and `l`. -/
theorem append_single {done l : List Nat} {v : Nat} (h : Valid g done l) (hlt : v < g.size)
    (hnd : v ∉ done) (hnl : v ∉ l) (hp : ∀ u ∈ g.predsOf v, u ∈ done ∨ u ∈ l) :
    Valid g done (l ++ [v]) := by
  induction h with
  | nil =>
    exact .cons hlt hnd (fun u hu => by simpa using hp u hu) (.nil _)
  | @cons done w l hwlt hwnd hwp _ ih =>
    refine .cons hwlt hwnd hwp ?_
    apply ih
    · simp only [List.mem_cons, not_or]
      exact ⟨fun h => hnl (h ▸ List.mem_cons_self ..), hnd⟩
    · exact fun h => hnl (List.mem_cons_of_mem _ h)
    · intro u hu
      rcases hp u hu with h | h
      · exact Or.inl (List.mem_cons_of_mem _ h)
      · simp only [List.mem_cons] at h
        rcases h with h | h
        · exact Or.inl (h ▸ List.mem_cons_self ..)
        · exact Or.inr h

/-- The events before some point of an order, together with `done`, are closed. -/
theorem closed_prefix {done xs rest : List Nat} (hc : Closed' g done)
    (h : Valid g done (xs ++ rest)) : Closed' g (xs ++ done) := by
  induction xs generalizing done with
  | nil => simpa using hc
  | cons x xs ih =>
    cases h with
    | cons _ _ hp hl =>
      have hc' : Closed' g (x :: done) := by
        intro v hv u hu
        simp only [List.mem_cons] at hv
        rcases hv with rfl | hv
        · exact List.mem_cons_of_mem _ (hp u hu)
        · exact List.mem_cons_of_mem _ (hc v hv u hu)
      have := ih hc' hl
      intro v hv u hu
      have hv' : v ∈ xs ++ x :: done := by
        simp only [List.mem_cons, List.mem_append] at hv ⊢; grind
      have := this v hv' u hu
      simp only [List.mem_cons, List.mem_append] at this ⊢; grind

end Valid

theorem Closed'.reach_mem {g : DepGraph} {done : List Nat} (hc : Closed' g done) {x w : Nat}
    (r : DepGraph.Reach g x w) (hw : w ∈ done) : x ∈ done := by
  induction r with
  | refl => exact hw
  | step _ hp ih => exact ih (hc _ hw _ hp)

theorem runEffects_bubble {eff : Nat → Mem V → Mem V} {a : Nat} {xs ys : List Nat}
    (hcomm : ∀ x ∈ xs, ∀ m, eff a (eff x m) = eff x (eff a m)) (m : Mem V) :
    runEffects eff (xs ++ a :: ys) m = runEffects eff (a :: (xs ++ ys)) m := by
  induction xs generalizing m with
  | nil => rfl
  | cons x xs ih =>
    simp only [runEffects, List.cons_append, List.foldl_cons] at ih ⊢
    rw [ih (fun x' hx' => hcomm x' (List.mem_cons_of_mem _ hx')) (eff x m)]
    rw [hcomm x (List.mem_cons_self ..) m]

/-- **Any two allowed finishing orders of the same events give the same memory**, in a race-free
program with framed effects. -/
theorem runEffects_eq {g : DepGraph} {fp : Footprint} {eff : Nat → Mem V → Mem V}
    (hfr : Framed fp eff) (hrf : RaceFree g fp) :
    ∀ (l₁ l₂ done : List Nat) (m : Mem V), Closed' g done → Valid g done l₁ → Valid g done l₂ →
      (∀ v, v ∈ l₁ ↔ v ∈ l₂) → runEffects eff l₁ m = runEffects eff l₂ m := by
  intro l₁
  induction l₁ with
  | nil =>
    intro l₂ done m _ _ _ hsame
    cases l₂ with
    | nil => rfl
    | cons y _ => exact absurd ((hsame y).mpr (List.mem_cons_self ..)) (by simp)
  | cons a r₁ ih =>
    intro l₂ done m hc h₁ h₂ hsame
    cases h₁ with
    | cons halt hand hap hr₁ =>
      obtain ⟨xs, ys, rfl⟩ := List.append_of_mem ((hsame a).mp (List.mem_cons_self ..))
      have hnd₂ := h₂.nodup
      have haxs : a ∉ xs := by
        intro hax
        have := (List.nodup_append.mp hnd₂).2.2 a hax a (List.mem_cons_self ..)
        exact this rfl
      have haxys : a ∉ xs ++ ys := by
        intro h
        simp only [List.mem_append] at h
        rcases h with h | h
        · exact haxs h
        · exact (List.nodup_cons.mp (List.nodup_append.mp hnd₂).2.1).1 h
      -- `a` commutes with everything run before it in the second order.
      have hcomm : ∀ x ∈ xs, ∀ m, eff a (eff x m) = eff x (eff a m) := by
        intro x hx m
        have hxa : x ≠ a := fun h => haxs (h ▸ hx)
        have hxl₂ : x ∈ xs ++ a :: ys := List.mem_append_left _ hx
        apply effects_commute hfr
        intro hconf
        rcases hrf a x halt (h₂.lt x hxl₂) (Ne.symm hxa) hconf with r | r
        · -- `x` waits for `a`, so `a` would have to come before `x`.
          have hcp := Valid.closed_prefix hc h₂
          have := hcp.reach_mem r (List.mem_append_left _ hx)
          simp only [List.mem_append] at this
          rcases this with h | h
          · exact haxs h
          · exact hand h
        · -- `a` waits for `x`, so `x` would be done already.
          obtain ⟨w, hw, rxw⟩ := r.last hxa
          have := hc.reach_mem rxw (hap w hw)
          exact h₂.not_mem_done x hxl₂ this
      rw [runEffects_bubble hcomm]
      simp only [runEffects, List.foldl_cons]
      apply ih (xs ++ ys) (a :: done) (eff a m)
      · intro v hv u hu
        simp only [List.mem_cons] at hv
        rcases hv with rfl | hv
        · exact List.mem_cons_of_mem _ (hap u hu)
        · exact List.mem_cons_of_mem _ (hc v hv u hu)
      · exact hr₁
      · exact h₂.remove
      · intro v
        have har₁ : a ∉ r₁ := fun h => hr₁.not_mem_done a h (List.mem_cons_self ..)
        by_cases hva : v = a
        · subst hva; exact ⟨fun h => absurd h har₁, fun h => absurd h haxys⟩
        · have := hsame v
          simp only [List.mem_cons, hva, false_or, List.mem_append] at this ⊢
          exact this

/-! ### From traces to finishing orders -/

/-- The event semantics of framed effects: starting does nothing, finishing applies the effect. -/
def effSem (eff : Nat → Mem V → Mem V) : Sem (Mem V) where
  onStart _ s s' := s' = s
  onFinish v s s' := s' = eff v s

def finishes : List Label → List Nat
  | [] => []
  | .start _ :: t => finishes t
  | .finish v :: t => v :: finishes t

/-- What a trace from the start establishes: the memory is the finished events' effects in order,
the done events are the finished ones, and the order they finished in is allowed. -/
structure TraceInv (g : DepGraph) (eff : Nat → Mem V → Mem V) (m₀ : Mem V) (c : Config (Mem V))
    (fin : List Nat) : Prop where
  state : c.state = runEffects eff fin m₀
  done : ∀ v, c.phase v = .done ↔ v ∈ fin
  valid : Valid g [] fin
  started : ∀ v, c.phase v ≠ .pending → v < g.size
  closed : Closed g c

theorem traceInv_step {g : DepGraph} {eff : Nat → Mem V → Mem V} {m₀ : Mem V}
    {c c' : Config (Mem V)} {fin : List Nat} {l : Label} (hf : g.Forward)
    (hi : TraceInv g eff m₀ c fin)
    (st : Step g (effSem eff) c l c') :
    TraceInv g eff m₀ c' (fin ++ match l with | .start _ => [] | .finish v => [v]) := by
  have hcl := closed_step hi.closed st
  cases st with
  | @start v s hr hs =>
    simp only [effSem] at hs
    subst hs
    simp only [List.append_nil]
    refine ⟨hi.state, fun w => ?_, hi.valid, fun w hw => ?_, hcl⟩
    · by_cases hwv : w = v
      · subst hwv
        simp only [setPhase, ite_true]
        constructor
        · intro h; cases h
        · intro h; rw [← hi.done w, hr.pending] at h; cases h
      · simp only [setPhase, hwv, ite_false]; exact hi.done w
    · by_cases hwv : w = v
      · exact hwv ▸ hr.lt
      · simp only [setPhase, hwv, ite_false] at hw; exact hi.started w hw
  | @finish v s hrun hs =>
    simp only [effSem] at hs
    subst hs
    have hvfin : v ∉ fin := fun h => by rw [← hi.done v, hrun] at h; cases h
    refine ⟨?_, fun w => ?_, ?_, fun w hw => ?_, hcl⟩
    · simp [hi.state, runEffects, List.foldl_append]
    · by_cases hwv : w = v
      · subst hwv; simp [setPhase]
      · simp only [setPhase, hwv, ite_false, List.mem_append, List.mem_singleton, or_false]
        exact hi.done w
    · apply hi.valid.append_single (hi.started v (by simp [hrun])) (by simp) hvfin
      intro u hu
      right
      have hne : u ≠ v := Nat.ne_of_lt (hf v u hu)
      have := hi.closed u v (by simp [hrun]) (.single hu) hne
      exact (hi.done u).mp this
    · by_cases hwv : w = v
      · subst hwv; exact hi.started w (by simp [hrun])
      · simp only [setPhase, hwv, ite_false] at hw; exact hi.started w hw

theorem traceInv_steps {g : DepGraph} {eff : Nat → Mem V → Mem V} {m₀ : Mem V}
    {c c' : Config (Mem V)} {fin : List Nat} {t : List Label} (hf : g.Forward)
    (hi : TraceInv g eff m₀ c fin)
    (st : Steps g (effSem eff) c t c') : TraceInv g eff m₀ c' (fin ++ finishes t) := by
  induction st generalizing fin with
  | nil => simpa [finishes] using hi
  | @cons c c₁ c₂ l t s _ ih =>
    have h1 := traceInv_step hf hi s
    have := ih h1
    cases l <;> simpa [finishes, List.append_assoc] using this

/-- **Race-free programs are deterministic.** In a race-free program (on a forward graph) whose
effects are framed by its footprint, every complete execution from the same memory ends with the
same memory. -/
theorem deterministic {g : DepGraph} {fp : Footprint} {eff : Nat → Mem V → Mem V}
    (hf : g.Forward) (hfr : Framed fp eff) (hrf : RaceFree g fp) {m₀ : Mem V} {t₁ t₂ : List Label}
    {c₁ c₂ : Config (Mem V)}
    (h₁ : Steps g (effSem eff) (Config.init m₀) t₁ c₁) (h₂ : Steps g (effSem eff) (Config.init m₀) t₂ c₂)
    (done₁ : ∀ v, v < g.size → c₁.phase v = .done) (done₂ : ∀ v, v < g.size → c₂.phase v = .done) :
    c₁.state = c₂.state := by
  have init : TraceInv g eff m₀ (Config.init m₀) [] :=
    ⟨rfl, fun v => by simp [Config.init], .nil _, fun v h => absurd rfl h, closed_init g m₀⟩
  have i₁ := traceInv_steps hf init h₁
  have i₂ := traceInv_steps hf init h₂
  simp only [List.nil_append] at i₁ i₂
  rw [i₁.state, i₂.state]
  apply runEffects_eq hfr hrf _ _ [] m₀ (fun _ h => absurd h (by simp)) i₁.valid i₂.valid
  intro v
  rw [← i₁.done, ← i₂.done]
  constructor
  · intro h; exact done₂ v (i₁.started v (by simp [h]))
  · intro h; exact done₁ v (i₂.started v (by simp [h]))

end

end Veir.Air
