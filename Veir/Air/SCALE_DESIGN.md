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
trusted; the chunk condition and certificate checkers are proven.
