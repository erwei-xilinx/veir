"builtin.module"() ({
  "func.func"() <{function_type = () -> (), sym_name = "f"}> ({
    %a = "air.wait_all"(%b) : (!air.async.token) -> !air.async.token
    %b = "air.wait_all"(%a) : (!air.async.token) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
