module

public import Veir.Air.Extract
import all Veir.IR.Basic

namespace Veir.Air

public section

/-- Drop the operands `reducedOperands` does not keep.

This rewrites the operand array in place, without unlinking the dropped operands from their
values' use lists. The result is meant to be printed and nothing else -- it is a raw `IRContext`,
not a `WfIRContext` -- and the printed module is re-parsed and re-verified, by VeIR and by
`air-opt`, before anything is concluded from it. -/
def Program.applyReduction (ctx : IRContext OpCode) (p : Program) : IRContext OpCode := Id.run do
  let keep := p.reducedOperands
  let mut ctx := ctx
  for e in p.events, flags in keep do
    let operands := (e.op.get! ctx).operands
    -- The dependency operands come first; anything after them (a DMA's memrefs and pattern) stays.
    let deps := ((operands.extract 0 flags.size).zip flags).filterMap fun (o, k) => if k then some o else none
    ctx := e.op.setOperands! ctx (deps ++ operands.extract flags.size operands.size)
    if e.kind == .dma then
      ctx := setDependencySegment ctx e.op deps.size
  return ctx
where
  /-- An unregistered op with `operandSegmentSizes` (`air.dma_memcpy_nd`) records how many
  dependency operands it has in the segment's first entry. -/
  setDependencySegment (ctx : IRContext OpCode) (op : OperationPtr) (n : Nat) : IRContext OpCode :=
    if h : op.getOpType! ctx = ofDialect OpCode Builtin.unregistered then
      let props := op.getProperties! ctx (OpCode.builtin Builtin.unregistered)
      let entries := props.properties.entries.map fun (k, a) =>
        if k == "operandSegmentSizes".toUTF8 then
          match a with
          | .denseArrayAttr d => (k, Attribute.denseArrayAttr { d with values := d.values.set! 0 n })
          | _ => (k, a)
        else (k, a)
      op.setProperties! (opCode := Builtin.unregistered) ctx
        { props with properties := { props.properties with entries } } h
    else ctx

end

end Veir.Air
