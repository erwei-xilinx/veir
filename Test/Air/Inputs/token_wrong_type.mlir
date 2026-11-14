"builtin.module"() ({
  "func.func"() <{function_type = () -> (), sym_name = "f"}> ({
    %c = "arith.constant"() <{value = 0 : index}> : () -> index
    %a = "air.wait_all"(%c) : (index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
