"builtin.module"() ({
  "func.func"() <{function_type = () -> (), sym_name = "f"}> ({
    %a:2 = "air.execute"() ({
      %c = "arith.constant"() <{value = 1 : i32}> : () -> i32
      "air.execute_terminator"(%c) : (i32) -> ()
    }) : () -> (!air.async.token, index)
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
