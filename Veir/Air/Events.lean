module

public import Veir.Air.DepGraph

namespace Veir.Air

@[expose] public section

/-! # A small-step semantics for AIR async events

Each event is `pending`, then `running`, then `done`. An event may *start* once every event it
waits for is `done` -- having its dependencies met allows it to start, it does not make it start,
and two events with no dependency between them may start in either order or overlap. An event
*finishes* some time after it started, and only then is its token signalled.

What an event does is not fixed here. `Sem` gives the effect of starting and of finishing each
event as a relation on a state `σ` that is otherwise opaque: `σ` can be the values an
`air.execute` yields, a memory, both, or a fault flag. Nothing below inspects it, which is why the
theorems hold for every choice -- including effects on shared memory. What *is* assumed is that an
event's effects happen at its start and finish steps: a body that interleaves with another body at
a finer grain than that needs those intermediate steps to be events of their own.

The observable behaviour of a program is its set of traces: sequences of `start`/`finish` labels
from the initial configuration, together with the configuration each one reaches. `steps_reduce_iff`
says the transitive reduction leaves that set unchanged.
-/

inductive Phase where
  | pending
  | running
  | done
deriving DecidableEq, Repr, Inhabited

structure Config (σ : Type) where
  phase : Nat → Phase
  state : σ

/-- Nothing has started. -/
def Config.init {σ : Type} (s : σ) : Config σ := ⟨fun _ => .pending, s⟩

inductive Label where
  | start (v : Nat)
  | finish (v : Nat)
deriving DecidableEq, Repr

/-- The effects of starting and finishing each event. -/
structure Sem (σ : Type) where
  onStart : Nat → σ → σ → Prop
  onFinish : Nat → σ → σ → Prop

def setPhase (p : Nat → Phase) (v : Nat) (x : Phase) : Nat → Phase :=
  fun w => if w = v then x else p w

variable {σ : Type}

/-- `v` may start: it has not, and every event it waits for is done. -/
structure Ready (g : DepGraph) (c : Config σ) (v : Nat) : Prop where
  lt : v < g.size
  pending : c.phase v = .pending
  deps : ∀ u ∈ g.predsOf v, c.phase u = .done

inductive Step (g : DepGraph) (sem : Sem σ) : Config σ → Label → Config σ → Prop
  | start {c : Config σ} {v : Nat} {s : σ} :
      Ready g c v → sem.onStart v c.state s →
      Step g sem c (.start v) ⟨setPhase c.phase v .running, s⟩
  | finish {c : Config σ} {v : Nat} {s : σ} :
      c.phase v = .running → sem.onFinish v c.state s →
      Step g sem c (.finish v) ⟨setPhase c.phase v .done, s⟩

inductive Steps (g : DepGraph) (sem : Sem σ) : Config σ → List Label → Config σ → Prop
  | nil (c : Config σ) : Steps g sem c [] c
  | cons {c c' c'' : Config σ} {l : Label} {t : List Label} :
      Step g sem c l c' → Steps g sem c' t c'' → Steps g sem c (l :: t) c''

/-! ### The invariant: everything a started event transitively waits for is done -/

def Closed (g : DepGraph) (c : Config σ) : Prop :=
  ∀ u v, c.phase v ≠ .pending → DepGraph.Reach g u v → u ≠ v → c.phase u = .done

theorem closed_init (g : DepGraph) (s : σ) : Closed g (Config.init s) := by
  intro u v hv
  exact absurd rfl hv

theorem closed_step {g : DepGraph} {sem : Sem σ} {c c' : Config σ} {l : Label}
    (hc : Closed g c) (st : Step g sem c l c') : Closed g c' := by
  cases st with
  | @start v s hr _ =>
    intro u v' hv' r hne
    simp only [setPhase] at hv' ⊢
    by_cases hv : v' = v
    · subst hv
      obtain ⟨w, hw, ruw⟩ := r.last hne
      have hwd := hr.deps w hw
      have huv : u ≠ v' := hne
      simp only [huv, ite_false]
      by_cases huw : u = w
      · subst huw; exact hwd
      · exact hc u w (by simp [hwd]) ruw huw
    · simp only [hv, ite_false] at hv'
      have hud := hc u v' hv' r hne
      have huv : u ≠ v := by
        intro h; subst h; rw [hr.pending] at hud; cases hud
      simp [huv, hud]
  | @finish v s hrun _ =>
    intro u v' hv' r hne
    simp only [setPhase] at hv' ⊢
    have hv'' : c.phase v' ≠ .pending := by
      by_cases hv : v' = v
      · subst hv; simp [hrun]
      · simpa [hv] using hv'
    have hud := hc u v' hv'' r hne
    by_cases huv : u = v <;> simp [huv, hud]

theorem closed_steps {g : DepGraph} {sem : Sem σ} {c c' : Config σ} {t : List Label}
    (hc : Closed g c) (st : Steps g sem c t c') : Closed g c' := by
  induction st with
  | nil => exact hc
  | cons s _ ih => exact ih (closed_step hc s)

theorem closed_of_reach {g h : DepGraph} {c : Config σ}
    (reach : ∀ u v, DepGraph.Reach g u v → DepGraph.Reach h u v) (hc : Closed h c) :
    Closed g c :=
  fun u v hv r hne => hc u v hv (reach u v r) hne

/-! ### Two graphs with the same reachability enable the same events -/

theorem ready_transfer {g h : DepGraph} {c : Config σ} {v : Nat} (hfg : g.Forward)
    (size : g.size = h.size) (reach : ∀ u v, DepGraph.Reach g u v → DepGraph.Reach h u v)
    (hc : Closed h c) (hr : Ready h c v) : Ready g c v := by
  refine ⟨size ▸ hr.lt, hr.pending, fun u hu => ?_⟩
  have huv : u ≠ v := Nat.ne_of_lt (hfg v u hu)
  obtain ⟨w, hw, ruw⟩ := (reach u v (.single hu)).last huv
  have hwd := hr.deps w hw
  by_cases huw : u = w
  · subst huw; exact hwd
  · exact hc u w (by simp [hwd]) ruw huw

theorem step_transfer {g h : DepGraph} {sem : Sem σ} {c c' : Config σ} {l : Label}
    (hfg : g.Forward) (size : g.size = h.size)
    (reach : ∀ u v, DepGraph.Reach g u v → DepGraph.Reach h u v)
    (hc : Closed h c) (st : Step h sem c l c') : Step g sem c l c' := by
  cases st with
  | start hr hs => exact .start (ready_transfer hfg size reach hc hr) hs
  | finish hrun hs => exact .finish hrun hs

theorem steps_transfer {g h : DepGraph} {sem : Sem σ} {c c' : Config σ} {t : List Label}
    (hfg : g.Forward) (size : g.size = h.size)
    (reach : ∀ u v, DepGraph.Reach g u v → DepGraph.Reach h u v)
    (hc : Closed h c) (st : Steps h sem c t c') : Steps g sem c t c' := by
  induction st with
  | nil => exact .nil _
  | cons s _ ih =>
    exact .cons (step_transfer hfg size reach hc s) (ih (closed_step hc s))

/-- **Same reachability, same traces.** Two forward graphs on the same events that order them
identically admit exactly the same executions, under any event semantics, from any configuration
in which every started event's dependencies are done. -/
theorem steps_iff_of_reach {g h : DepGraph} {sem : Sem σ} {c c' : Config σ} {t : List Label}
    (hfg : g.Forward) (hfh : h.Forward) (size : g.size = h.size)
    (reach : ∀ u v, DepGraph.Reach g u v ↔ DepGraph.Reach h u v) (hc : Closed g c) :
    Steps g sem c t c' ↔ Steps h sem c t c' := by
  have hgh : ∀ u v, DepGraph.Reach g u v → DepGraph.Reach h u v := fun u v => (reach u v).mp
  have hhg : ∀ u v, DepGraph.Reach h u v → DepGraph.Reach g u v := fun u v => (reach u v).mpr
  exact ⟨steps_transfer hfh size.symm hhg hc,
    steps_transfer hfg size hgh (closed_of_reach hhg hc)⟩

/-- **The transitive reduction of `air-dependency-canonicalize` does not change behaviour.** On a
forward graph, the reduced graph and the original admit the same executions from the start, under
every event semantics. -/
theorem steps_reduce_iff {g : DepGraph} {sem : Sem σ} {s : σ} {c : Config σ} {t : List Label}
    (hf : g.Forward) :
    Steps g.reduce sem (Config.init s) t c ↔ Steps g sem (Config.init s) t c :=
  steps_iff_of_reach hf.reduce hf (DepGraph.size_reduce g)
    (fun _ _ => DepGraph.reach_reduce_iff hf) (closed_init _ s)

/-- The form the AIR rewrite uses: any graph between the reduction and the original behaves as the
original does. -/
theorem steps_between_iff {g h : DepGraph} {sem : Sem σ} {s : σ} {c : Config σ} {t : List Label}
    (hf : g.Forward) (size : h.size = g.size)
    (lower : ∀ u v, u ∈ g.reduce.predsOf v → u ∈ h.predsOf v)
    (upper : ∀ u v, u ∈ h.predsOf v → u ∈ g.predsOf v) :
    Steps h sem (Config.init s) t c ↔ Steps g sem (Config.init s) t c :=
  steps_iff_of_reach (fun v u hu => hf v u (upper u v hu)) hf size
    (fun _ _ => DepGraph.reach_between_iff hf lower upper) (closed_init _ s)

/-- What a checker accepting `g` and `h` buys: the same executions. This is the statement that
covers a rewrite made by someone else, such as the C++ pass. -/
theorem steps_of_sameReach {g h : DepGraph} {sem : Sem σ} {s : σ} {c : Config σ} {t : List Label}
    (hc : DepGraph.sameReach g h = true) :
    Steps g sem (Config.init s) t c ↔ Steps h sem (Config.init s) t c :=
  have ⟨size, hfg, hfh, reach⟩ := DepGraph.sameReach_sound hc
  steps_iff_of_reach hfg hfh size reach (closed_init _ s)

/-! ### Progress

Every forward graph can run to completion, under any semantics whose steps can always be taken.
This is checklist item C2 for the async layer: dependencies alone never deadlock. It stops being
true once events can block on each other for other reasons -- a channel `get` waiting for its
`put` -- which is why it is stated here, before those exist. -/

theorem Steps.append {g : DepGraph} {sem : Sem σ} {c c' c'' : Config σ} {t t' : List Label}
    (h₁ : Steps g sem c t c') (h₂ : Steps g sem c' t' c'') : Steps g sem c (t ++ t') c'' := by
  induction h₁ with
  | nil => exact h₂
  | cons s _ ih => exact .cons s (ih h₂)

/-- **Progress.** On a forward graph, if starting and finishing an event can always take a step,
some execution from the start finishes every event. -/
theorem progress {g : DepGraph} {sem : Sem σ} (hf : g.Forward)
    (hstart : ∀ v s, ∃ s', sem.onStart v s s') (hfinish : ∀ v s, ∃ s', sem.onFinish v s s')
    (s₀ : σ) :
    ∃ t c, Steps g sem (Config.init s₀) t c ∧ ∀ v, v < g.size → c.phase v = .done := by
  -- Run events 0, 1, 2, ... one at a time: before event k, exactly the events below k are done.
  have run : ∀ k, k ≤ g.size → ∃ t c, Steps g sem (Config.init s₀) t c ∧
      (∀ v, v < k → c.phase v = .done) ∧ (∀ v, k ≤ v → c.phase v = .pending) := by
    intro k
    induction k with
    | zero => exact fun _ => ⟨[], _, .nil _, fun _ h => absurd h (Nat.not_lt_zero _),
        fun _ _ => rfl⟩
    | succ k ih =>
      intro hk
      obtain ⟨t, c, hsteps, hdone, hpend⟩ := ih (Nat.le_of_succ_le hk)
      have ready : Ready g c k :=
        ⟨hk, hpend k (Nat.le_refl _), fun u hu => hdone u (hf k u hu)⟩
      obtain ⟨s₁, hs₁⟩ := hstart k c.state
      obtain ⟨s₂, hs₂⟩ := hfinish k s₁
      let c₁ : Config σ := ⟨setPhase c.phase k .running, s₁⟩
      let c₂ : Config σ := ⟨setPhase c₁.phase k .done, s₂⟩
      have st₁ : Step g sem c (.start k) c₁ := .start ready hs₁
      have st₂ : Step g sem c₁ (.finish k) c₂ := .finish (by simp [c₁, setPhase]) hs₂
      refine ⟨t ++ [.start k, .finish k], c₂,
        hsteps.append (.cons st₁ (.cons st₂ (.nil _))), fun v hv => ?_, fun v hv => ?_⟩
      · by_cases hvk : v = k
        · simp [c₂, c₁, setPhase, hvk]
        · simp [c₂, c₁, setPhase, hvk, hdone v (Nat.lt_of_le_of_ne (Nat.le_of_lt_succ hv) hvk)]
      · have hvk : v ≠ k := by omega
        simp [c₂, c₁, setPhase, hvk, hpend v (by omega)]
  obtain ⟨t, c, hsteps, hdone, _⟩ := run g.size (Nat.le_refl _)
  exact ⟨t, c, hsteps, hdone⟩

end

end Veir.Air
