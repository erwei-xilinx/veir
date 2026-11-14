"builtin.module"() ({
  "func.func"() <{function_type = () -> (), sym_name = "f"}> ({
    %a:2 = "air.execute"() ({
      %c1 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      "air.execute_terminator"(%c1) : (i32) -> ()
    }) : () -> (!air.async.token, i32)
    %b:2 = "air.execute"() ({
      %c10 = "arith.constant"() <{value = 10 : i32}> : () -> i32
      "air.execute_terminator"(%c10) : (i32) -> ()
    }) : () -> (!air.async.token, i32)
    %c:2 = "air.execute"() ({
      %y = "arith.constant"() <{value = 2 : i32}> : () -> i32
      "air.execute_terminator"(%y) : (i32) -> ()
    }) : () -> (!air.async.token, i32)
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
