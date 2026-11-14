"builtin.module"() ({
  "func.func"() <{function_type = (!air.async.token) -> (), sym_name = "f"}> ({
  ^bb0(%t: !air.async.token):
    %a = "air.wait_all"(%t) : (!air.async.token) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
