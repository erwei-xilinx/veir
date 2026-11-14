"builtin.module"() ({
  "func.func"() <{function_type = () -> (), sym_name = "f"}> ({
    %c0 = "arith.constant"() <{value = 0 : index}> : () -> index
    %c4 = "arith.constant"() <{value = 4 : index}> : () -> index
    %c1 = "arith.constant"() <{value = 1 : index}> : () -> index
    %t = "air.wait_all"() : () -> !air.async.token
    %r = "scf.for"(%c0, %c4, %c1, %t) ({
    ^bb0(%i: index, %it: !air.async.token):
      %n = "air.wait_all"(%it) : (!air.async.token) -> !air.async.token
      "scf.yield"(%n) : (!air.async.token) -> ()
    }) : (index, index, index, !air.async.token) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
