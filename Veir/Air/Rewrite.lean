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
    let kept := (operands.zip flags).filterMap fun (o, k) => if k then some o else none
    ctx := e.op.setOperands! ctx kept
  return ctx

end

end Veir.Air
