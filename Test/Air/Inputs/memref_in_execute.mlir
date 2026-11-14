"builtin.module"() ({
  "func.func"() <{function_type = () -> (), sym_name = "f"}> ({
    %a:2 = "air.execute"() ({
      %m = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4xi32>
      "air.execute_terminator"(%m) : (memref<4xi32>) -> ()
    }) : () -> (!air.async.token, memref<4xi32>)
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
