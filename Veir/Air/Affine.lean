module

public import Std

namespace Veir.Air

@[expose] public section

/-! # Affine maps and integer sets, evaluated on known integers

VeIR keeps `affine_map<...>` and `affine_set<...>` attributes verbatim
(`parseOptionalAffineAttrVerbatim`). The host needs their values only on integers it already
knows: loop induction variables, tile ids, constants. So `affine.apply`, `affine.if` and the
`affine.*` loads of an access pattern are evaluated here, from the text, following MLIR's
semantics:
- `floordiv` and `ceildiv` round toward minus and plus infinity;
- `mod` is the non-negative remainder (MLIR requires a positive divisor for all three);
- a constraint is `e >= 0` or `e == 0`.
-/

namespace Affine

inductive Tok where
  | num (n : Int)
  | ident (s : String)
  | sym (s : String)
deriving BEq, Inhabited, Repr

def tokenize (s : String) : List Tok := Id.run do
  let cs := s.toList
  let mut out : Array Tok := #[]
  let mut i := 0
  while h : i < cs.length do
    let c := cs[i]
    if c.isWhitespace then
      i := i + 1
    else if c.isDigit then
      let mut n := 0
      while h' : i < cs.length do
        if cs[i].isDigit then
          n := n * 10 + (cs[i].toNat - '0'.toNat)
          i := i + 1
        else break
      out := out.push (.num n)
    else if c.isAlpha || c == '_' then
      let mut id := ""
      while h' : i < cs.length do
        if cs[i].isAlphanum || cs[i] == '_' then
          id := id.push cs[i]
          i := i + 1
        else break
      out := out.push (.ident id)
    else if (c == '>' || c == '=' || c == '<') && i + 1 < cs.length && cs[i + 1]! == '=' then
      out := out.push (.sym (String.ofList [c, '=']))
      i := i + 2
    else if c == '-' && i + 1 < cs.length && cs[i + 1]! == '>' then
      out := out.push (.sym "->")
      i := i + 2
    else
      out := out.push (.sym (String.singleton c))
      i := i + 1
  return out.toList

/-- What the identifiers of a map stand for. -/
abbrev Env := List (String × Int)

def floorDiv (a b : Int) : Int := Int.fdiv a b
def ceilDiv (a b : Int) : Int := -(Int.fdiv (-a) b)
def modE (a b : Int) : Int := Int.emod a b

mutual

/-- expr := term (('+' | '-') term)* -/
partial def expr (env : Env) (ts : List Tok) : Except String (Int × List Tok) := do
  let (v, rest) ← term env ts
  exprTail env v rest

partial def exprTail (env : Env) (acc : Int) : List Tok → Except String (Int × List Tok)
  | .sym "+" :: ts => do let (v, r) ← term env ts; exprTail env (acc + v) r
  | .sym "-" :: ts => do let (v, r) ← term env ts; exprTail env (acc - v) r
  | ts => pure (acc, ts)

/-- term := factor (('*' | 'floordiv' | 'ceildiv' | 'mod') factor)* -/
partial def term (env : Env) (ts : List Tok) : Except String (Int × List Tok) := do
  let (v, rest) ← factor env ts
  termTail env v rest

partial def termTail (env : Env) (acc : Int) : List Tok → Except String (Int × List Tok)
  | .sym "*" :: ts => do let (v, r) ← factor env ts; termTail env (acc * v) r
  | .ident "floordiv" :: ts => do
    let (v, r) ← factor env ts
    if v ≤ 0 then throw "floordiv by a non-positive value"
    termTail env (floorDiv acc v) r
  | .ident "ceildiv" :: ts => do
    let (v, r) ← factor env ts
    if v ≤ 0 then throw "ceildiv by a non-positive value"
    termTail env (ceilDiv acc v) r
  | .ident "mod" :: ts => do
    let (v, r) ← factor env ts
    if v ≤ 0 then throw "mod by a non-positive value"
    termTail env (modE acc v) r
  | ts => pure (acc, ts)

/-- factor := integer | identifier | '(' expr ')' | '-' factor -/
partial def factor (env : Env) : List Tok → Except String (Int × List Tok)
  | .num n :: ts => pure (n, ts)
  | .sym "-" :: ts => do let (v, r) ← factor env ts; pure (-v, r)
  | .sym "(" :: ts => do
    let (v, r) ← expr env ts
    match r with
    | .sym ")" :: r' => pure (v, r')
    | _ => throw "expected ')'"
  | .ident x :: ts =>
    match env.lookup x with
    | some v => pure (v, ts)
    | none => throw s!"unknown identifier '{x}'"
  | t :: _ => throw s!"unexpected {repr t}"
  | [] => throw "unexpected end"

end

/-- `(` a, b, ... `)` or `[` a, b, ... `]`: the identifiers, and what follows. -/
def idList (openS closeS : String) : List Tok → Except String (List String × List Tok)
  | .sym o :: ts =>
    if o != openS then throw s!"expected '{openS}'" else
    let rec go (acc : List String) : List Tok → Except String (List String × List Tok)
      | .sym c :: r => if c == closeS then pure (acc.reverse, r) else
          if c == "," then go acc r else throw s!"unexpected '{c}'"
      | .ident x :: r => go (x :: acc) r
      | _ => throw "bad identifier list"
    go [] ts
  | _ => throw s!"expected '{openS}'"

/-- The dimension and symbol names of `(d0, ...)[s0, ...]`, bound to `dims` and `syms`. -/
def bind (ts : List Tok) (dims syms : List Int) : Except String (Env × List Tok) := do
  let (ds, r) ← idList "(" ")" ts
  let (ss, r) ← match r with
    | .sym "[" :: _ => idList "[" "]" r
    | _ => pure ([], r)
  if ds.length != dims.length || ss.length != syms.length then
    throw s!"expected {ds.length} dimension(s) and {ss.length} symbol(s), got {dims.length} and {syms.length}"
  return (ds.zip dims ++ ss.zip syms, r)

/-- The body of `keyword<...>`. -/
def body (keyword s : String) : Except String String :=
  if s.startsWith (keyword ++ "<") && s.endsWith ">" then
    pure ((s.drop (keyword.length + 1)).dropRight 1).toString
  else throw s!"expected {keyword}<...>, got {s}"

/-- How many dimensions `keyword<(d0, ...)...>` declares (its operands are dims, then symbols). -/
def numDims (keyword s : String) : Nat :=
  match body keyword s with
  | .ok b => match idList "(" ")" (tokenize b) with
    | .ok (ds, _) => ds.length
    | .error _ => 0
  | .error _ => 0

/-- Evaluate `affine_map<(dims)[syms] -> (e1, ..., en)>`. -/
def evalMap (s : String) (dims syms : List Int) : Except String (List Int) := do
  let (env, r) ← bind (tokenize (← body "affine_map" s)) dims syms
  let .sym "->" :: .sym "(" :: r := r | throw "expected '-> ('"
  let rec results (acc : List Int) (ts : List Tok) (fuel : Nat) : Except String (List Int) :=
    match fuel with
    | 0 => throw "too many results"
    | fuel + 1 => do
      let (v, r) ← expr env ts
      match r with
      | .sym "," :: r' => results (v :: acc) r' fuel
      | .sym ")" :: _ => pure (v :: acc).reverse
      | _ => throw "expected ',' or ')'"
  match r with
  | .sym ")" :: _ => pure []
  | _ => results [] r (r.length + 1)

/-- Evaluate `affine_set<(dims)[syms] : (c1, ..., cn)>`: whether every constraint holds. -/
def evalSet (s : String) (dims syms : List Int) : Except String Bool := do
  let (env, r) ← bind (tokenize (← body "affine_set" s)) dims syms
  let .sym ":" :: .sym "(" :: r := r | throw "expected ': ('"
  let rec go (ok : Bool) (ts : List Tok) (fuel : Nat) : Except String Bool :=
    match fuel with
    | 0 => throw "too many constraints"
    | fuel + 1 => do
      let (v, r) ← expr env ts
      let (holds, r) ← match r with
        | .sym ">=" :: .num 0 :: r' => pure (decide (v ≥ 0), r')
        | .sym "==" :: .num 0 :: r' => pure (v == 0, r')
        | _ => throw "expected '>= 0' or '== 0'"
      match r with
      | .sym "," :: r' => go (ok && holds) r' fuel
      | .sym ")" :: _ => pure (ok && holds)
      | _ => throw "expected ',' or ')'"
  go true r (r.length + 1)

end Affine

end

end Veir.Air
