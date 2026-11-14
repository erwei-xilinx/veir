module

public import Std.Data.HashMap

namespace Veir.Air

@[expose] public section

/-! # Access patterns

An AIR access pattern (`air.dma_memcpy_nd`'s `offsets`, `sizes`, `strides`) and the elements of
the underlying buffer it touches, in the order it touches them.

The meaning is the one the AIR and mlir-aie lowerings implement (`SEMANTICS.md`, D14): element
`k` is at linear position `Σ (offsets[i] + k[i]) · strides[i]`. Each offset counts in units of its
own dimension's stride, and the number of dimensions is independent of the memref's rank. Upstream
`memref.subview` means something else, and this file states both and relates them, because
AIR's frontend folds subviews into patterns (AIR-009).
-/

/-- One dimension of an AIR access pattern. -/
structure Dim where
  offset : Int
  size : Nat
  stride : Int
deriving Repr, DecidableEq, Inhabited

/-- The linear positions a pattern touches from `base`, in traversal order: the first dimension is
the outermost. -/
def positionsFrom (base : Int) : List Dim → List Int
  | [] => [base]
  | d :: ds =>
    (List.range d.size).flatMap fun (k : Nat) => positionsFrom (base + (d.offset + k) * d.stride) ds

/-- The linear positions a pattern touches (D14). -/
def positions (ds : List Dim) : List Int := positionsFrom 0 ds

/-- A pattern touches `Π sizes` elements, counting repeats: the quantity D15 compares between a
DMA's source and destination. -/
theorem length_positionsFrom (base : Int) (ds : List Dim) :
    (positionsFrom base ds).length = (ds.map Dim.size).prod := by
  induction ds generalizing base with
  | nil => rfl
  | cons d ds ih =>
    simp only [positionsFrom, List.length_flatMap, List.map_cons, List.prod_cons, ih,
      List.map_const', List.length_range, List.sum_replicate_nat]

/-! ### `memref.subview`

One dimension of a subview of a strided source: `offset` is a coordinate in the source's shape,
`step` the subview's stride (how far apart, in that dimension, consecutive elements are), and
`layout` the source's linear stride in that dimension. -/

structure SubviewDim where
  offset : Int
  size : Nat
  step : Int
  layout : Int
deriving Repr, DecidableEq, Inhabited

/-- The linear positions a subview selects from a source whose layout offset is `base`, in
traversal order. This is `memref.subview`'s meaning: the result layout of
`subview %m[o] [n] [s]` over a source with strides `L` and offset `b` is `strided<[s·L], offset:
b + Σ o·L>`. -/
def subviewFrom (base : Int) : List SubviewDim → List Int
  | [] => [base]
  | d :: ds =>
    (List.range d.size).flatMap fun (k : Nat) =>
      subviewFrom (base + (d.offset + (k : Int) * d.step) * d.layout) ds

/-- How `air-copy-to-dma` and the `air.dma_memcpy_nd` canonicalizer fold a subview of an
identity-layout memref into a pattern, as observed (AIR-009): the offsets are copied, and the
strides become linear (`step · layout`). -/
def foldAsAIR (ds : List SubviewDim) : List Dim :=
  ds.map fun d => ⟨d.offset, d.size, d.step * d.layout⟩

/-- The linear offset a subview's offsets contribute. -/
def SubviewDim.linearOffset (ds : List SubviewDim) : Int :=
  (ds.map fun d => d.offset * d.layout).sum

/-- A fold that is right under D14: the subview's whole offset goes into one leading size-1,
stride-1 dimension, and every other dimension starts at 0. -/
def foldFixed (base : Int) (ds : List SubviewDim) : List Dim :=
  ⟨base + SubviewDim.linearOffset ds, 1, 1⟩ :: ds.map fun d => ⟨0, d.size, d.step * d.layout⟩

theorem positionsFrom_zeroOffsets (b : Int) (ds : List SubviewDim) :
    positionsFrom (b + SubviewDim.linearOffset ds) (ds.map fun d => ⟨0, d.size, d.step * d.layout⟩) =
      subviewFrom b ds := by
  induction ds generalizing b with
  | nil => simp [positionsFrom, subviewFrom, SubviewDim.linearOffset]
  | cons d ds ih =>
    simp only [List.map_cons, positionsFrom, subviewFrom]
    congr 1
    funext k
    rw [← ih]
    congr 1
    simp only [SubviewDim.linearOffset, List.map_cons, List.sum_cons]
    grind

/-- **The fixed fold is right**: it touches exactly the subview's elements, in the same order. -/
theorem positions_foldFixed (base : Int) (ds : List SubviewDim) :
    positions (foldFixed base ds) = subviewFrom base ds := by
  simp [positions, foldFixed, positionsFrom, positionsFrom_zeroOffsets]

/-- AIR's fold is right when every step is 1, which is when the two conventions agree. -/
theorem positions_foldAsAIR_of_unitSteps (ds : List SubviewDim) (h : ∀ d ∈ ds, d.step = 1) :
    positions (foldAsAIR ds) = subviewFrom 0 ds := by
  suffices ∀ b, positionsFrom b (foldAsAIR ds) = subviewFrom b ds by exact this 0
  induction ds with
  | nil => intro b; rfl
  | cons d ds ih =>
    intro b
    have hd : d.step = 1 := h d (List.mem_cons_self ..)
    have ih' := ih fun d' hd' => h d' (List.mem_cons_of_mem _ hd')
    simp only [foldAsAIR, List.map_cons, positionsFrom, subviewFrom] at ih' ⊢
    congr 1
    funext k
    rw [← ih']
    congr 1
    rw [hd]
    grind

/-- **AIR-009.** With a step of 2, AIR's fold touches different elements than the subview:
`memref.subview %m[4] [4] [2]` selects 4, 6, 8, 10, and the folded pattern 8, 10, 12, 14. -/
theorem foldAsAIR_wrong :
    subviewFrom 0 [⟨4, 4, 2, 1⟩] = [4, 6, 8, 10] ∧
    positions (foldAsAIR [⟨4, 4, 2, 1⟩]) = [8, 10, 12, 14] := by
  decide

end

end Veir.Air
