# Scaling `air-veir` to real designs (design, 2026-11-17)

Status: proposal, not implemented. Every reduction below must come with a Lean theorem that the
reduced check gives the verdict of the full one; a reduction without one is a heuristic and is not
used for verification.

## 1. Measurements

Inputs: the 107 modules of mlir-air's lit tests (main `251927e6c`) that `air-veir` (`07dc634d6`)
refuses as too large (48, over 20000 event instances) or times out on (59, over 300 s), and the
input `aircc` gets for dflash `qwen3_4b` (target decode). Sizes are static estimates
(`estimate.py`): an op's instances are the product of the trip counts of its loops and the sizes
of its hierarchy ops; a transfer's elements are the product of its sizes.

| Set | Ops | Event instances | Elements moved |
| --- | --- | --- | --- |
| 48 "too large" (median) | 18 | 1e5-1e7 | 1e7 and more (35 of 48) |
| 59 timeouts (median) | 14 | under 1e4 (49 of 59) | 1e6-1e7 (32 of 59) |
| dflash `qwen3_4b` decode | 450 | 2.3e6 (loops up to x35420, herds x8) | 5.3e9 |

Where the time goes, on timeouts with ~500 event instances (`air_split_l2_memref*`):
`air-veir graph` takes 0.1 s; `run` and `races` exceed 120 s. The event graph is small; the
element-level channel and DMA model is not (one such module moves 1,048,576 elements).

Two causes, independent:
1. **Element granularity.** Transfers are streams of single elements (`ChanSem`: `push`, `pull`,
   `xfer` per element). 600 to 2000 elements per event instance in the median; this alone explains
   the timeouts.
2. **Full instantiation.** Every loop iteration and hierarchy instance is its own set of events:
   a program of 18 ops becomes 1e5-1e7 instances, the LLM's 450 ops 2.3e6. Some bounds are run-time
   values (the LLM's sequence length), which full instantiation can only take one at a time.

## 2. Phase 1: chunked transfers (cause 1)

**Idea.** Within one matched put/get pair, the element steps between its first and last element
are invisible to the rest of the program when no other event touches those elements meanwhile.
They can then be taken as one atomic step, a *chunk*, without changing what can be reached.

**Theorem to prove (Lipton reduction).** For a program whose element-level executions satisfy
the chunk condition (below), the chunked semantics and `ChanSem`'s element semantics have:
- the same reachable final states (so `outcome_uniqueH` transfers);
- deadlock iff deadlock (`checkH_true`/`checkH_false` transfer);
- race-freedom iff race-freedom, with a race of chunk footprints mapped back to an element race.

Proof route: each element step inside a chunk, after the first, is a *right mover* (it commutes
with every step of other transfers, since their footprints are disjoint from the chunk's remaining
elements and channels other than this subchannel are untouched); Lipton's theorem then moves every
execution to one where each chunk is contiguous.

**Chunk condition** (checked, else fall back to elements): the put and get of a pair cover the same
run of a subchannel's stream; no third event's footprint meets the elements the chunk has yet to
move; broadcast slots move together (D53). Checking it is cheap: it is a statement about
footprints, which the race check already computes per event.

**Expected effect.** All 59 timeouts have under 1e5 event instances; with chunks, their channel
model has about as many steps as events. The LLM's 5.3e9 elements become about 1.8e6 chunks
(cause 2 remains).

**Status (2026-11-18): implemented, by a simulation instead of a reduction** (`ChanChunk.lean`,
proven, standard axioms only). A chunk is a run of consecutive elements of a stream with the same
put, gets and buffering; the chunked program has one element per chunk. Proven:
- `hb_transfer`: happens-before in the chunked program gives it in the element program, between
  every pair of members, or, along a chunk's own steps (read, entry, arrival), between members in
  stream order. Every edge of the chunked order is classified (`edgeOk`), then induction;
- `raceFree_of_chunked`: race-freedom transfers when, within a chunk, no member's read conflicts
  with an earlier member's write (`CondOk`, decided by `condB`: stream slots only at the member's
  own element, other buffers not shared with a write);
- `completes_iff`: an execution completes in one program iff in the other (a chunked label's
  members fire in stream order, `expand_run`; a chunked label fires when its last member has);
- `chunked_sound`, `chunked_deadlock`, `outcome_uniqueC`: the verdicts of `checkH` and `racesOkE`
  on the chunked program, for the element program, when `validB` checks the chunking.
`ChanModel.chunking` (not trusted: `validB` and `condB` check what it builds) groups elements
greedily. A race found on chunks is reported with witnesses on chunks, mapped to members (below).

**Footprints as ranges (2026-11-18, `ChanRange.lean`, proven).** An access is a list of ranges
`[lo, hi)` (`RAcc`); its positions are what the theorems speak of (`toLFp`) and are not listed by
the check. `racesOkRange` cuts each buffer at the ends of all its accesses' ranges and checks each
piece as `racesOkR` checks a position (`raceFree_of_racesOkRange`: a position's accesses are its
piece's). Whole buffers (D22, D23) are one range; a chunk's members' ranges are joined
(`chunkRFp`, covering every member's access: `raceFree_of_chunked` takes covering footprints).
The D59/D62 checks have range versions implying the position ones, and `decision_readsRF` takes a
complete execution and race-freedom on its labels, which every path gives. `tranpose_linalg_cpy`
went from out of memory (14 GB) to 3.5 s and 190 MB. What remains for the largest modules is the
memory the D62 rounds simulate element by element (`air_split_l2_memref.mlir` #15: 4e6 positions).

**D62 memory and race witnesses (2026-11-19).** Overlapping ranges are merged after sorting
(`joinRanges`), and values are proposed from a run a use after deallocation does not stop
(`MState.lenient`). #15 went from out of memory to 57 s and 3.4 GB; its 2048 races are real.

Witnesses are proven (`ChanWitness.lean`): a witness `x` before `y` in a complete execution comes
with a certificate (`certify`, not trusted; `certB` checks it): the positions a search back from `y`
reaches, between `x` and `y`, and every position before `x`, are closed under `hbPreds`, with `y`
in and `x` out. Firing those labels first, then the others, each in the execution's order, is a
complete execution (`reorder`, from `en_of_preds`: what enables a label is what `hbPreds` lists;
`buildIndex_complete`: the index lists every element of each event), so `witness_sound`: another
complete execution fires `y` before `x`. On chunks, the certificate is on the chunked program and
`expand_run` gives the element execution (`witness_soundC`); a race between members of one chunk is
certified on the expanded execution (`witness_soundE`). A pair without a certificate is not
printed; before this, pairs ordered through a path the bounded `labelReach` misses were printed.

## 3. Phase 2: certificates instead of instantiation (cause 2)

In the manner of proof-carrying code (Necula, POPL 1997): an untrusted *certificate generator*
proposes, for each loop and hierarchy op, a symbolic summary; a *checker proven in Lean* accepts it
or not. Generating may use heuristics and be slow; checking is proportional to the program text.
A rejected or missing certificate falls back to instantiation.

**Certificate per loop** (iteration `i` of `n`, `n` possibly symbolic):
- each event's footprint as an affine function of `i` (`buf[a*i + b .. a*i + b + len)`), and of
  the hierarchy ids around it;
- the token chain: which events of iteration `i` wait for which of iteration `i - 1`;
- per subchannel, the elements each iteration puts and gets.

**What the checker proves from it** (one theorem each):
1. *Race-freedom for all `i`, `j`*: two iterations' conflicting footprints are disjoint (affine
   non-overlap, decided by integer arithmetic) or ordered by the token chain (a path from `i` to
   `j > i`). Sound for every `n`.
2. *Balance*: per subchannel, the puts and gets of one iteration move the same elements in the same
   order; together with (3), no iteration waits for one that cannot come.
3. *Deadlock-freedom by induction*: a schedule of one iteration, given iteration `i - 1` finished,
   is a schedule of iteration `i` (the summary is invariant under `i -> i + 1`). Then a schedule of
   all `n` iterations exists (`Schedule.lean`'s certificates, lifted).

**Certificate per hierarchy op**: tiles grouped by the footprints and subchannels their ids
select; the checker proves that tiles in different groups touch disjoint buffers and subchannels,
and checks one tile of each group with its peers' channel endpoints in place.

**Expected effect.** Checking becomes linear in the ops of the program (18 median, 450 for the
LLM), and symbolic bounds become possible: a verdict for every sequence length at once.

### 3.1 Phase 2a in detail: race-freedom for every bound (decided 2026-11-18)

Scope: sequential loops (`scf.for`, `affine.for`), parallel loops (`scf.parallel`, `scf.forall`,
`affine.parallel`) and their nesting. Decisions: the extraction from IR to a template is trusted, as
`Instance.lean` is, and not cross-checked against instantiation; the first version includes
parallel loops and nesting.

**Template** (`LoopCert.lean`). A program in which each event inside a symbolic loop appears once:
- loops `L` with a parent, a kind (sequential or parallel) and a bound: a constant, or unknown;
- events `v` with the chain of loops around them, outermost first; an *instance* is `(v, it)` with
  `it L < n L` for each loop `L` of `v`, where `n` gives every loop's trip count;
- edges `u -> v` ("`v` waits for `u`") with, per loop, how the two instances' iterations relate:
  for a loop around both, `eq` or `succ` (a token `scf.yield` carries to the next iteration); for a
  loop around `u` only, `last` (a sequential loop's result) or `any` (a parallel loop's reduction);
  for a loop around `v` only, `first` (an `iter_args` initial value) or `any` (a captured token).
  An edge may hold only when a loop has no iteration (the result of an empty `scf.for` is its
  initial value);
- footprints: per access, a buffer (allocated per iteration of some of the event's loops, so that
  allocations in different iterations are different buffers), read or write, and positions
  `base + sum_L c_L * it L + q` for `q` in a finite pattern.

**Theorem.** For every `n` matching the constant bounds, and every channel program `p` with
footprints `fp` that *realizes* the template (each template edge is an edge of `p`'s graph; each
label's footprint lies in the template footprint of an instance that starts before it and finishes
after it, `startersL`/`finishersL`; distinct buffer instances are distinct buffers), and in which
two labels of one event that conflict are ordered (the stream's FIFO): `RaceFree p fp S` for every
`S`. Its route: `hb_starters`, `hb_finishers`, `hb_finish_start` turn an instance path into a
happens-before between the labels; the checker below gives the paths.

**Checker.**
1. *Paths for every bound.* Facts `(a, b, pattern, guard)`: for every `n` satisfying `guard` (some
   loops empty, some not), every instance of `a` reaches every instance of `b` whose iterations
   relate as `pattern` says (per loop: `eq`, `succ`, `lt`, `le`, `any`, `first`, `last`). Facts
   start from the edges and close under composition (a table of the per-loop compositions whose
   intermediate iteration always exists, each proven), the chain rule (`succ` from an instance to
   the same event's next iteration gives `lt` by induction), and union (`eq` and `lt` give `le`).
2. *Conflicts.* For each pair of template events whose footprints share a buffer with a write,
   each region of iterations (per common loop `<`, `=` or `>`) and each emptiness of the guarded
   loops: either a fact orders the pair over the whole region (one way or the other), or the
   footprints are disjoint over it: different buffer instances, or no solution to the position
   equation. That is decided exactly by enumeration for constant bounds, and for one unknown bound
   by the arithmetic progression the iteration difference contributes, cut to the finite range the
   patterns allow; anything else is reported, not assumed disjoint.

**Nested loops (2026-11-19).** A token that leaves an inner loop at its last iteration and enters
it again in the next iteration of an outer loop relates the inner loop's iterations by `Rel.wrap`
(source last, target first); with `toFirst` and `fromLast` (target first, source last) the
compositions `le;wrap = toFirst`, `wrap;le = fromLast`, `toFirst;le = any`, `le;fromLast = any` are
proven (`compRel_ok`), and the chain rule accepts `any` on the other loops (`chain_holds`): every
instance of an earlier outer iteration then reaches every instance of a later one.

**Verdict.** `races` gives "race-free for every value of the unknown bounds" (proven,
`LoopCert.raceFree_of_certOk`); deadlock and outcomes are phase 2b.

**Extraction** (trusted, `LoopTemplate.lean`). The program is instantiated with every symbolic
loop (trip count not known, or above 4) run three times, with the values events compute (the
rounds of D59/D62); each event and buffer records the symbolic loops and iterations it was made
in. Template events are the sample's events up to their iterations (every iteration must make the
same events); edges are the sample's dependencies generalized to a pattern and kept only if the
sample has every dependency the pattern claims; one more sample per loop, with that loop empty,
gives the edges its emptiness guards; footprints must shift by a constant per iteration. A bound
used anywhere but as a bound is not known in the sample, and the function is refused.

**Status (2026-11-18): implemented.** `LoopCert.lean` (proven, standard axioms only),
`LoopTemplate.lean`, `air-veir races` falls back to it, `air-veir template` prints it. On the 164
lit modules the coverage sweep could not instantiate (unknown bound, too large, timeout, out of
memory): 51 race-free for every trip count; 38 not established, 31 of them a read of an
`air.execute` result no token orders (D57; where the full model, given bounds, completes, it
reports the same races: `runtime_repeat_count_unit_reuses_buffer`,
`fuse_channels_sequential_loops`; elsewhere it deadlocks before the read);
42 without a template (still over 20000 events in the sample, bounds deciding hierarchy sizes or
channel indices, D33, run-time branches); 32 still time out or run out of memory, mostly in the
element-level model the sample is run on (phase 1's chunks are not implemented).

### 3.2 Phase 2b: deadlock-freedom and outcomes for every bound (design, 2026-11-19)

Goal: for the functions phase 2a proves race-free for every trip count, also "completes, for every
trip count" (and then, with race-freedom, one outcome: `deterministic` needs one complete execution
and race-freedom). Every execution can then complete (`completes_from_anywhere`, already proven).

**What is missing from the template.** Channels. Phase 2a only needs a stream's slots to be ordered
by the stream (`exempt`, `self`); completing needs which put meets which get. The template gains,
per subchannel (fixed after the hierarchy is instantiated; symbolic loops stay symbolic):
- the template events that put on it and get from it, each moving a constant number of elements
  per instance;
- the order of its elements: the puts' instances in a total order (one put per subchannel per
  iteration of a chain of sequential loops), likewise the gets.

**Decisions (2026-11-19).** Puts and gets in different loops balance when their loops are aligned
up to an integer multiple; two bounds are equal when they are the same constant, or the same
arithmetic expression (arith/affine ops, the same ops in the same order) of the same values (one
SSA value through `args` of launch, segment and herd is one value); the extraction is trusted, not
cross-checked against instantiation.

**Balance by alignment.** A subchannel's puts run in one loop chain and its gets in another (one
per destination slot); loop `L` moves `m_L` elements per iteration. An *alignment class* is a set
of loops tied by subchannels; each loop `L` of it gets a *scale* `s_L` (time units per iteration)
and each subchannel a rate `u` (elements per time unit) with `m_L = u * s_L` at both ends. Their
bounds must satisfy `s_L * n_L = s_L' * n_L'` for every trip count: bounds are `c * E` with `c` a
constant and `E` an expression, and the equation is checked on `c` and `E`. Then iteration `i` of
`L` spans time units `[s_L * i, s_L * (i + 1))`, element `e` of the subchannel is moved at unit
`e / u`, and puts and gets balance for every trip count. A put loop of `n` iterations of `4c`
elements against a get loop of `4n` iterations of `c`: scales 4 and 1, rate `c`. Anything else
(counts that depend on the iteration, two put events on one subchannel, bounds the equation does
not relate) is reported as not established.

**Deadlock-freedom by a ranking.** A run exists when the labels can be listed so that each comes
after everything `hbPreds` lists for it (`ChanWitness.run_sorted`; the run is complete when it lists
every finish). The certificate is such a key, compared lexicographically:
- one coordinate per alignment class, in an order of the classes: a label inside a loop of the
  class has its time unit (an event instance starts at its iteration's first unit and finishes at
  its last; an element at its unit); a label outside it is before (`⊥`) or after (`⊤`) all of it;
- then a place in a topological order of one time unit: event starts and finishes, and per
  subchannel its reads, pushes, pulls and transfers;
- then the element index.
The checker proves, on the template, that every kind of predecessor decreases the key: token
edges by their relation (`succ`, `lt`, `last`, `first` and `eq` against scales and `⊥`/`⊤`); the
stream order (`prev`: the previous element, at the same or an earlier unit); meetings and buffering
(a get's elements after the put's reads and pushes, and after the get started); an event's finish
after its elements. The theorem: for every `n` that satisfies the known bounds and the alignment
equations, a program realizing the extended template completes; with `raceFree_of_certOk`,
`deterministic` gives one outcome for every trip count.

**Extraction** (trusted, as in phase 2a): the sample (each symbolic loop run three times) gives, per
subchannel, its puts and gets with their template events and element counts; alignment is read off
the sample (put instance `i` meets get instance `i`) and kept only if the bounds are the same value.

**Status (2026-11-19): implemented.** `LoopDead.lean` (proven, standard axioms only),
`LoopDeadGen.lean` (extraction, trusted, and the certificate generator, checked), reported by
`air-veir races` after phase 2a's verdict. As built, a stream is more general than above: in each
iteration of its loop, its puts (and each slot's gets) are a sequence of *runs*, each event moving
`m` consecutive elements from offset `off` (several puts on one channel in one iteration); its
start and finish offsets are its run's first and last element's units. A slot nothing gets is
allowed for a buffered stream (its elements stay, D30); an unbuffered one is reported (its puts
never finish). The generator refines a class's unit so that each run fills whole units, places an
event after a class when anything inside reaches it, when it follows such an event, or when another
end of its stream is after it, and derives offsets and the order of one unit from the edges. The
proof: `completes_of_rank` (a run exists when a key ranks every label above what it waits for),
`edge_lt` (token edges), `side_coords`/`seg_lt` (elements between their runs' starts and finishes),
`en_all` and the per-label `pre_*` lemmas, `completes_of_deadOk`. Lit: `loopdead.mlir` (aligned,
an integer multiple, and three refusals the element-level model confirms as deadlocks or as
depending on the trip counts). A stream whose every side moves all of
an instance's elements in one instance of its events (a DMA's elements, put and got by the DMA
itself) is *instance-local*: it may sit in any nest of symbolic loops, each element at its
instance's coordinates, between the start and finish of every side's event (`side_coords_local`;
`RealizesD` gives each element its instance, `elIt`); the sample's chains, one per instance, are
one template stream. Template-checked functions of the lit sweep: 28 of 98 complete for every
trip count. Not yet: streams fed by several loops in turn (the puts of one loop, then another's:
the element index is a sum of trip counts), streams whose ends are in more than one symbolic loop
and not instance-local, streams of no loop with several runs, and the dependency 2a's patterns
cannot state (from an inner loop's last iteration to the next outer iteration's first). Most of
the remaining refusals are real: per-iteration counts that differ at the two ends (lit tests of
passes, not runnable programs), or unbuffered streams nothing gets.

## 4. Order of work

1. Phase 1: chunk semantics, the reduction theorem in Lean, the chunk condition check; re-run the
   coverage sweep (target: the 59 timeouts).
2. Phase 2a: loop certificates for race-freedom only (theorem 1): the most common verdict, and the
   simplest proof.
3. Phase 2b: balance and deadlock (theorems 2, 3); hierarchy groups.
4. The LLM input as the acceptance test.

## 5. What stays trusted

Unchanged by this work: the AIR semantics decisions (`SEMANTICS.md`) and the extraction from IR to
the model (`Instance.lean`, `Channels.lean`, `ChanGlue.lean`). The certificate generator is not
trusted; the chunk condition and certificate checkers are proven, and so are race witnesses
(`witness_sound`).
