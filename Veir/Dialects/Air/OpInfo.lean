module

public import Veir.IR.OpInfo
public import Veir.Verifier.Basic
meta import Veir.Meta.OpCode

namespace Veir

public section

/-! # The async-event subset of MLIR-AIR's `air` dialect

Only the operations that make up AIR's async dependency graph are registered: `air.execute`, its
terminator, and `air.wait_all`. Every other `air` operation (`air.launch`, `air.herd`,
`air.dma_memcpy_nd`, `air.channel.put`, ...) is still read and printed, as an unregistered
operation, under `--allow-unregistered-dialect`; registering it here would claim a structure check
this file does not perform.

The token type is `!air.async.token` (`AsyncTokenType` in `AIRDialect.cpp`). AIR's
`docs/AIRComputeModel.md` describes a `!air.token` and `air.token.alloc` that the dialect does not
implement; the type here is the one the dialect parses.

The structure checks are the ones AIR's ODS and `ExecuteOp::verify` make, and no more: AIR accepts
an `air.execute -> (index)` whose terminator yields an `i32`, or nothing, and so does this verifier.
`Veir.Air.Extract` refuses such an `air.execute` before giving it a meaning.
-/

@[opcodes]
inductive Air where
| execute
| execute_terminator
| wait_all
deriving Inhabited, Repr, Hashable, DecidableEq

@[expose, properties_of]
def Air.propertiesOf (_op : Air) : Type :=
  Unit

/-- None of the registered operations has properties. Their `id` and other attributes are
discardable attributes, which every operation keeps. -/
def Air.fromAttrDict
    (op : Air) (attrDict : Std.HashMap ByteArray Attribute) :
    Except String (Air.propertiesOf op) :=
  if attrDict.size > 0 then
    let plural := if attrDict.size = 1 then "property" else "properties"
    .error s!"air: expected no properties, but got {attrDict.size} {plural}"
  else by
    cases op
    all_goals exact .ok ()

def Air.toAttrDict
    (_op : Air) (_props : Air.propertiesOf _op) :
    Std.HashMap ByteArray Attribute :=
  Std.HashMap.emptyWithCapacity 0

/-- `air.execute` and `air.wait_all` order other operations, so neither can be removed for want of
uses. AIR derives `air.execute`'s effects from its body; `unknown` is the conservative stand-in. -/
@[get_effects]
def Air.getEffects
    (op : Air) (_props : Air.propertiesOf op) : MemoryEffects :=
  match op with
  | .execute | .wait_all => .unknown
  | .execute_terminator => .none

def Air.isConstantLike (_op : Air) : Bool :=
  false

def Air.hasSSADominance (_op : Air) (_index : Nat) : Bool :=
  true

@[is_terminator]
def Air.isTerminator (op : Air) : Bool :=
  match op with
  | .execute_terminator => true
  | .execute | .wait_all => false

#generate_dialect Air

instance : IsOpCode Air where
  fromName := Air.fromName
  name := Air.name
  propertiesOf := Air.propertiesOf
  fromAttrDict := Air.fromAttrDict
  toAttrDict := Air.toAttrDict

/-- The spelling of AIR's token type, as `parseOptionalType` stores it. -/
def Air.asyncTokenTypeName : String := "!air.async.token"

/-- Whether a type is `!air.async.token`. -/
def Air.isAsyncToken (type : Attribute) : Bool :=
  match type with
  | .unregisteredAttr attr => attr.isType && attr.value == Air.asyncTokenTypeName
  | _ => false

/-- Every operand is a token: `Variadic<air_AsyncToken>:$async_dependencies`. -/
def OperationPtr.verifyAirAsyncDependencies {OpInfo : Type} [IsOpCode OpInfo]
    (op : OperationPtr) (ctx : WfIRContext OpInfo) (opName : String) : Except String PUnit := do
  for type in op.getOperandTypes! ctx.raw, i in [0:op.getNumOperands! ctx.raw] do
    if !Air.isAsyncToken type.val then
      throw s!"{opName}: operand #{i} must be an async token, but got {type}"

/-- Verify the local invariants of an `air` operation. -/
def Air.verifyLocalInvariants {OpInfo : Type} [IsOpCode OpInfo]
    [HasDialect OpInfo Air] (opType : Air) (op : OperationPtr)
    (ctx : WfIRContext OpInfo) (opIn : op.InBounds ctx.raw) : Except String PUnit := do
  let resultTypes := op.getResultTypes! ctx.raw
  match opType with
  | .execute => do
    op.verifyAirAsyncDependencies ctx "air.execute"
    -- `outs air_AsyncToken:$async_token, Variadic<AnyType>:$results`: the token is not optional.
    let some tokenType := resultTypes[0]?
      | throw "air.execute: expected an async token result"
    if !Air.isAsyncToken tokenType.val then
      throw s!"air.execute: result #0 must be an async token, but got {tokenType}"
    if op.getNumSuccessors ctx.raw opIn ≠ 0 then
      throw "air.execute: expected 0 successors"
    -- `ExecuteOp::verify`, and `SizedRegion<1>`.
    if op.getNumRegions ctx.raw opIn ≠ 1 then
      throw "air.execute: expected 1 region"
    let region := op.getRegion! ctx.raw 0
    let some block := region.getFirstBlock! ctx.raw
      | throw "air.execute: expected a non-empty region"
    if region.getLastBlock! ctx.raw ≠ some block then
      throw "air.execute: expected a region with a single block"
  | .execute_terminator => do
    op.verifyTerminatorCounts ctx opIn 0
    -- `HasParent<"ExecuteOp">`.
    let some parent := op.getParentOp! ctx.raw
      | throw "air.execute_terminator: expected to be inside an air.execute"
    let some .execute := toDialect? Air (parent.getOpType! ctx.raw)
      | throw "air.execute_terminator: expected to be inside an air.execute"
  | .wait_all => do
    op.verifyAirAsyncDependencies ctx "air.wait_all"
    -- `Optional<air_AsyncToken>:$async_token`: no result is the blocking form.
    if resultTypes.size > 1 then
      throw "air.wait_all: expected at most 1 result"
    if let some type := resultTypes[0]? then
      if !Air.isAsyncToken type.val then
        throw s!"air.wait_all: result #0 must be an async token, but got {type}"
    op.verifyNonOperandCounts ctx opIn resultTypes.size 0 0

instance : HasOpInfo Air where
  verifyLocalInvariants := Air.verifyLocalInvariants
  getEffects := Air.getEffects
  isConstantLike := Air.isConstantLike
  hasSSADominance := Air.hasSSADominance
  isTerminator := Air.isTerminator

end

end Veir
