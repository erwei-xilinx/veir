"builtin.module"() ({
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "ca"}> : () -> ()
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "cb"}> : () -> ()
  "func.func"() <{function_type = (index) -> (), sym_name = "aligned"}> ({
  ^bb0(%arg124: index):
    %115 = "arith.constant"() <{value = 1 : index}> : () -> index
    %116 = "air.launch"(%115, %arg124) <{operandSegmentSizes = array<i32: 0, 1, 1>}> ({
    ^bb0(%arg125: index, %arg126: index, %arg127: index):
      %117 = "air.segment"(%arg127) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg128: index):
        %118 = "arith.constant"() <{value = 0 : index}> : () -> index
        %119 = "arith.constant"() <{value = 1 : index}> : () -> index
        %120:2 = "air.execute"() ({
          %130 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%130) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %121 = "scf.for"(%118, %arg128, %119, %120#0) ({
        ^bb0(%arg136: index, %arg137: !air.async.token):
          %129 = "air.channel.put"(%arg137, %120#1) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          "scf.yield"(%129) : (!air.async.token) -> ()
        }) : (index, index, index, !air.async.token) -> !air.async.token
        %122 = "air.herd"(%119, %119, %arg128) <{operandSegmentSizes = array<i32: 0, 2, 1>, sym_name = "herd"}> ({
        ^bb0(%arg129: index, %arg130: index, %arg131: index, %arg132: index, %arg133: index):
          %123 = "arith.constant"() <{value = 0 : index}> : () -> index
          %124 = "arith.constant"() <{value = 1 : index}> : () -> index
          %125:2 = "air.execute"() ({
            %128 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 2>
            "air.execute_terminator"(%128) : (memref<32xi32, 2>) -> ()
          }) : () -> (!air.async.token, memref<32xi32, 2>)
          %126 = "scf.for"(%123, %arg133, %124, %125#0) ({
          ^bb0(%arg134: index, %arg135: !air.async.token):
            %127 = "air.channel.get"(%arg135, %125#1) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<32xi32, 2>) -> !air.async.token
            "scf.yield"(%127) : (!air.async.token) -> ()
          }) : (index, index, index, !air.async.token) -> !air.async.token
          "air.herd_terminator"() : () -> ()
        }) : (index, index, index) -> !air.async.token
        "air.segment_terminator"() : () -> ()
      }) : (index) -> !air.async.token
      "air.launch_terminator"() : () -> ()
    }) : (index, index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (index) -> (), sym_name = "multiple"}> ({
  ^bb0(%arg110: index):
    %96 = "arith.constant"() <{value = 1 : index}> : () -> index
    %97 = "air.launch"(%96, %arg110) <{operandSegmentSizes = array<i32: 0, 1, 1>}> ({
    ^bb0(%arg111: index, %arg112: index, %arg113: index):
      %98 = "air.segment"(%arg113) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg114: index):
        %99 = "arith.constant"() <{value = 0 : index}> : () -> index
        %100 = "arith.constant"() <{value = 1 : index}> : () -> index
        %101:2 = "air.execute"() ({
          %114 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%114) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %102 = "scf.for"(%99, %arg114, %100, %101#0) ({
        ^bb0(%arg122: index, %arg123: !air.async.token):
          %113 = "air.channel.put"(%arg123, %101#1) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          "scf.yield"(%113) : (!air.async.token) -> ()
        }) : (index, index, index, !air.async.token) -> !air.async.token
        %103 = "air.herd"(%100, %100, %arg114) <{operandSegmentSizes = array<i32: 0, 2, 1>, sym_name = "herd"}> ({
        ^bb0(%arg115: index, %arg116: index, %arg117: index, %arg118: index, %arg119: index):
          %104 = "arith.constant"() <{value = 0 : index}> : () -> index
          %105 = "arith.constant"() <{value = 1 : index}> : () -> index
          %106:2 = "air.execute"() ({
            %112 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 2>
            "air.execute_terminator"(%112) : (memref<32xi32, 2>) -> ()
          }) : () -> (!air.async.token, memref<32xi32, 2>)
          %107 = "arith.constant"() <{value = 4 : index}> : () -> index
          %108 = "arith.constant"() <{value = 8 : index}> : () -> index
          %109 = "arith.muli"(%arg119, %107) <{overflowFlags = #arith.overflow<none>}> : (index, index) -> index
          %110 = "scf.for"(%104, %109, %105, %106#0) ({
          ^bb0(%arg120: index, %arg121: !air.async.token):
            %111 = "air.channel.get"(%arg121, %106#1, %104, %108, %105) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>}> : (!air.async.token, memref<32xi32, 2>, index, index, index) -> !air.async.token
            "scf.yield"(%111) : (!air.async.token) -> ()
          }) : (index, index, index, !air.async.token) -> !air.async.token
          "air.herd_terminator"() : () -> ()
        }) : (index, index, index) -> !air.async.token
        "air.segment_terminator"() : () -> ()
      }) : (index) -> !air.async.token
      "air.launch_terminator"() : () -> ()
    }) : (index, index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (index) -> (), sym_name = "gets_after_puts"}> ({
  ^bb0(%arg96: index):
    %80 = "arith.constant"() <{value = 1 : index}> : () -> index
    %81 = "air.launch"(%80, %arg96) <{operandSegmentSizes = array<i32: 0, 1, 1>}> ({
    ^bb0(%arg97: index, %arg98: index, %arg99: index):
      %82 = "air.segment"(%arg99) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg100: index):
        %83 = "arith.constant"() <{value = 0 : index}> : () -> index
        %84 = "arith.constant"() <{value = 1 : index}> : () -> index
        %85:2 = "air.execute"() ({
          %95 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%95) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %86 = "scf.for"(%83, %arg100, %84, %85#0) ({
        ^bb0(%arg108: index, %arg109: !air.async.token):
          %94 = "air.channel.put"(%arg109, %85#1) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          "scf.yield"(%94) : (!air.async.token) -> ()
        }) : (index, index, index, !air.async.token) -> !air.async.token
        %87 = "air.herd"(%86, %84, %84, %arg100) <{operandSegmentSizes = array<i32: 1, 2, 1>, sym_name = "herd"}> ({
        ^bb0(%arg101: index, %arg102: index, %arg103: index, %arg104: index, %arg105: index):
          %88 = "arith.constant"() <{value = 0 : index}> : () -> index
          %89 = "arith.constant"() <{value = 1 : index}> : () -> index
          %90:2 = "air.execute"() ({
            %93 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 2>
            "air.execute_terminator"(%93) : (memref<32xi32, 2>) -> ()
          }) : () -> (!air.async.token, memref<32xi32, 2>)
          %91 = "scf.for"(%88, %arg105, %89, %90#0) ({
          ^bb0(%arg106: index, %arg107: !air.async.token):
            %92 = "air.channel.get"(%arg107, %90#1) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<32xi32, 2>) -> !air.async.token
            "scf.yield"(%92) : (!air.async.token) -> ()
          }) : (index, index, index, !air.async.token) -> !air.async.token
          "air.herd_terminator"() : () -> ()
        }) : (!air.async.token, index, index, index) -> !air.async.token
        "air.segment_terminator"() : () -> ()
      }) : (index) -> !air.async.token
      "air.launch_terminator"() : () -> ()
    }) : (index, index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (index, index) -> (), sym_name = "other_bound"}> ({
  ^bb0(%arg79: index, %arg80: index):
    %64 = "arith.constant"() <{value = 1 : index}> : () -> index
    %65 = "air.launch"(%64, %arg79, %arg80) <{operandSegmentSizes = array<i32: 0, 1, 2>}> ({
    ^bb0(%arg81: index, %arg82: index, %arg83: index, %arg84: index):
      %66 = "air.segment"(%arg83, %arg84) <{operandSegmentSizes = array<i32: 0, 0, 2>, sym_name = "seg"}> ({
      ^bb0(%arg85: index, %arg86: index):
        %67 = "arith.constant"() <{value = 0 : index}> : () -> index
        %68 = "arith.constant"() <{value = 1 : index}> : () -> index
        %69:2 = "air.execute"() ({
          %79 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%79) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %70 = "scf.for"(%67, %arg85, %68, %69#0) ({
        ^bb0(%arg94: index, %arg95: !air.async.token):
          %78 = "air.channel.put"(%arg95, %69#1) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          "scf.yield"(%78) : (!air.async.token) -> ()
        }) : (index, index, index, !air.async.token) -> !air.async.token
        %71 = "air.herd"(%68, %68, %arg86) <{operandSegmentSizes = array<i32: 0, 2, 1>, sym_name = "herd"}> ({
        ^bb0(%arg87: index, %arg88: index, %arg89: index, %arg90: index, %arg91: index):
          %72 = "arith.constant"() <{value = 0 : index}> : () -> index
          %73 = "arith.constant"() <{value = 1 : index}> : () -> index
          %74:2 = "air.execute"() ({
            %77 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 2>
            "air.execute_terminator"(%77) : (memref<32xi32, 2>) -> ()
          }) : () -> (!air.async.token, memref<32xi32, 2>)
          %75 = "scf.for"(%72, %arg91, %73, %74#0) ({
          ^bb0(%arg92: index, %arg93: !air.async.token):
            %76 = "air.channel.get"(%arg93, %74#1) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<32xi32, 2>) -> !air.async.token
            "scf.yield"(%76) : (!air.async.token) -> ()
          }) : (index, index, index, !air.async.token) -> !air.async.token
          "air.herd_terminator"() : () -> ()
        }) : (index, index, index) -> !air.async.token
        "air.segment_terminator"() : () -> ()
      }) : (index, index) -> !air.async.token
      "air.launch_terminator"() : () -> ()
    }) : (index, index, index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (index) -> (), sym_name = "unbalanced"}> ({
  ^bb0(%arg65: index):
    %47 = "arith.constant"() <{value = 1 : index}> : () -> index
    %48 = "air.launch"(%47, %arg65) <{operandSegmentSizes = array<i32: 0, 1, 1>}> ({
    ^bb0(%arg66: index, %arg67: index, %arg68: index):
      %49 = "air.segment"(%arg68) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg69: index):
        %50 = "arith.constant"() <{value = 0 : index}> : () -> index
        %51 = "arith.constant"() <{value = 1 : index}> : () -> index
        %52:2 = "air.execute"() ({
          %63 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%63) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %53 = "scf.for"(%50, %arg69, %51, %52#0) ({
        ^bb0(%arg77: index, %arg78: !air.async.token):
          %62 = "air.channel.put"(%arg78, %52#1) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          "scf.yield"(%62) : (!air.async.token) -> ()
        }) : (index, index, index, !air.async.token) -> !air.async.token
        %54 = "air.herd"(%51, %51, %arg69) <{operandSegmentSizes = array<i32: 0, 2, 1>, sym_name = "herd"}> ({
        ^bb0(%arg70: index, %arg71: index, %arg72: index, %arg73: index, %arg74: index):
          %55 = "arith.constant"() <{value = 0 : index}> : () -> index
          %56 = "arith.constant"() <{value = 1 : index}> : () -> index
          %57:2 = "air.execute"() ({
            %61 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 2>
            "air.execute_terminator"(%61) : (memref<32xi32, 2>) -> ()
          }) : () -> (!air.async.token, memref<32xi32, 2>)
          %58 = "scf.for"(%55, %arg74, %56, %57#0) ({
          ^bb0(%arg75: index, %arg76: !air.async.token):
            %59 = "arith.constant"() <{value = 16 : index}> : () -> index
            %60 = "air.channel.get"(%arg76, %57#1, %55, %59, %56) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>}> : (!air.async.token, memref<32xi32, 2>, index, index, index) -> !air.async.token
            "scf.yield"(%60) : (!air.async.token) -> ()
          }) : (index, index, index, !air.async.token) -> !air.async.token
          "air.herd_terminator"() : () -> ()
        }) : (index, index, index) -> !air.async.token
        "air.segment_terminator"() : () -> ()
      }) : (index) -> !air.async.token
      "air.launch_terminator"() : () -> ()
    }) : (index, index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4096xi32>, memref<4096xi32>, index) -> (), sym_name = "dma_nest"}> ({
  ^bb0(%arg59: memref<4096xi32>, %arg60: memref<4096xi32>, %arg61: index):
    %40 = "arith.constant"() <{value = 0 : index}> : () -> index
    %41 = "arith.constant"() <{value = 1 : index}> : () -> index
    %42 = "arith.constant"() <{value = 8 : index}> : () -> index
    "scf.for"(%40, %arg61, %41) ({
    ^bb0(%arg62: index):
      %43 = "arith.muli"(%arg62, %42) <{overflowFlags = #arith.overflow<none>}> : (index, index) -> index
      %44 = "air.wait_all"() : () -> !air.async.token
      %45 = "scf.for"(%40, %arg61, %41, %44) ({
      ^bb0(%arg63: index, %arg64: !air.async.token):
        %46 = "air.dma_memcpy_nd"(%arg64, %arg60, %43, %42, %41, %arg59, %43, %42, %41) <{operandSegmentSizes = array<i32: 1, 1, 1, 1, 1, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (!air.async.token, memref<4096xi32>, index, index, index, memref<4096xi32>, index, index, index) -> !air.async.token
        "scf.yield"(%46) : (!air.async.token) -> ()
      }) : (index, index, index, !air.async.token) -> !air.async.token
      "scf.yield"() : () -> ()
    }) : (index, index, index) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (index) -> (), sym_name = "put_after_get"}> ({
  ^bb0(%arg52: index):
    %27 = "arith.constant"() <{value = 1 : index}> : () -> index
    %28 = "air.launch"(%27, %arg52) <{operandSegmentSizes = array<i32: 0, 1, 1>}> ({
    ^bb0(%arg53: index, %arg54: index, %arg55: index):
      %29 = "air.segment"(%arg55) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg56: index):
        %30 = "arith.constant"() <{value = 0 : index}> : () -> index
        %31 = "arith.constant"() <{value = 1 : index}> : () -> index
        %32:2 = "air.execute"() ({
          %39 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%39) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %33:2 = "air.execute"() ({
          %38 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%38) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %34 = "air.wait_all"(%32#0, %33#0) : (!air.async.token, !air.async.token) -> !air.async.token
        %35 = "scf.for"(%30, %arg56, %31, %34) ({
        ^bb0(%arg57: index, %arg58: !air.async.token):
          %36 = "air.channel.get"(%arg58, %33#1) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          %37 = "air.channel.put"(%36, %32#1) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          "scf.yield"(%37) : (!air.async.token) -> ()
        }) : (index, index, index, !air.async.token) -> !air.async.token
        "air.segment_terminator"() : () -> ()
      }) : (index) -> !air.async.token
      "air.launch_terminator"() : () -> ()
    }) : (index, index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (index, index) -> (), sym_name = "blocking_then_herd"}> ({
  ^bb0(%arg36: index, %arg37: index):
    %18 = "arith.constant"() <{value = 1 : index}> : () -> index
    "air.launch"(%18, %arg36, %arg37) <{operandSegmentSizes = array<i32: 0, 1, 2>}> ({
    ^bb0(%arg38: index, %arg39: index, %arg40: index, %arg41: index):
      "air.segment"(%arg40, %arg41) <{operandSegmentSizes = array<i32: 0, 0, 2>, sym_name = "seg"}> ({
      ^bb0(%arg42: index, %arg43: index):
        %19 = "arith.constant"() <{value = 0 : index}> : () -> index
        %20 = "arith.constant"() <{value = 1 : index}> : () -> index
        %21:2 = "air.execute"() ({
          %26 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<8xi32, 1>
          "air.execute_terminator"(%26) : (memref<8xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<8xi32, 1>)
        "scf.for"(%19, %arg42, %20) ({
        ^bb0(%arg51: index):
          "air.channel.put"(%21#1) <{chan_name = @cb, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<8xi32, 1>) -> ()
          "scf.yield"() : () -> ()
        }) : (index, index, index) -> ()
        "air.herd"(%20, %20, %arg42, %arg43) <{operandSegmentSizes = array<i32: 0, 2, 2>, sym_name = "h"}> ({
        ^bb0(%arg44: index, %arg45: index, %arg46: index, %arg47: index, %arg48: index, %arg49: index):
          %22 = "arith.constant"() <{value = 0 : index}> : () -> index
          %23 = "arith.constant"() <{value = 1 : index}> : () -> index
          %24:2 = "air.execute"() ({
            %25 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<8xi32, 2>
            "air.execute_terminator"(%25) : (memref<8xi32, 2>) -> ()
          }) : () -> (!air.async.token, memref<8xi32, 2>)
          "scf.for"(%22, %arg48, %23) ({
          ^bb0(%arg50: index):
            "air.channel.get"(%24#1) <{chan_name = @cb, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (memref<8xi32, 2>) -> ()
            "scf.yield"() : () -> ()
          }) : (index, index, index) -> ()
          "air.herd_terminator"() : () -> ()
        }) : (index, index, index, index) -> ()
        "air.segment_terminator"() : () -> ()
      }) : (index, index) -> ()
      "air.launch_terminator"() : () -> ()
    }) : (index, index, index) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (index, index) -> (), sym_name = "phases_blocking"}> ({
  ^bb0(%arg18: index, %arg19: index):
    %9 = "arith.constant"() <{value = 1 : index}> : () -> index
    "air.launch"(%9, %arg18, %arg19) <{operandSegmentSizes = array<i32: 0, 1, 2>}> ({
    ^bb0(%arg20: index, %arg21: index, %arg22: index, %arg23: index):
      "air.segment"(%arg22, %arg23) <{operandSegmentSizes = array<i32: 0, 0, 2>, sym_name = "seg"}> ({
      ^bb0(%arg24: index, %arg25: index):
        %10 = "arith.constant"() <{value = 0 : index}> : () -> index
        %11 = "arith.constant"() <{value = 1 : index}> : () -> index
        %12:2 = "air.execute"() ({
          %17 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<8xi32, 1>
          "air.execute_terminator"(%17) : (memref<8xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<8xi32, 1>)
        "scf.for"(%10, %arg24, %11) ({
        ^bb0(%arg35: index):
          "air.channel.put"(%12#1) <{chan_name = @cb, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<8xi32, 1>) -> ()
          "scf.yield"() : () -> ()
        }) : (index, index, index) -> ()
        "scf.for"(%10, %arg25, %11) ({
        ^bb0(%arg34: index):
          "air.channel.put"(%12#1) <{chan_name = @cb, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<8xi32, 1>) -> ()
          "scf.yield"() : () -> ()
        }) : (index, index, index) -> ()
        "air.herd"(%11, %11, %arg24, %arg25) <{operandSegmentSizes = array<i32: 0, 2, 2>, sym_name = "h"}> ({
        ^bb0(%arg26: index, %arg27: index, %arg28: index, %arg29: index, %arg30: index, %arg31: index):
          %13 = "arith.constant"() <{value = 0 : index}> : () -> index
          %14 = "arith.constant"() <{value = 1 : index}> : () -> index
          %15:2 = "air.execute"() ({
            %16 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<8xi32, 2>
            "air.execute_terminator"(%16) : (memref<8xi32, 2>) -> ()
          }) : () -> (!air.async.token, memref<8xi32, 2>)
          "scf.for"(%13, %arg30, %14) ({
          ^bb0(%arg33: index):
            "air.channel.get"(%15#1) <{chan_name = @cb, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (memref<8xi32, 2>) -> ()
            "scf.yield"() : () -> ()
          }) : (index, index, index) -> ()
          "scf.for"(%13, %arg31, %14) ({
          ^bb0(%arg32: index):
            "air.channel.get"(%15#1) <{chan_name = @cb, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (memref<8xi32, 2>) -> ()
            "scf.yield"() : () -> ()
          }) : (index, index, index) -> ()
          "air.herd_terminator"() : () -> ()
        }) : (index, index, index, index) -> ()
        "air.segment_terminator"() : () -> ()
      }) : (index, index) -> ()
      "air.launch_terminator"() : () -> ()
    }) : (index, index, index) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (index, index) -> (), sym_name = "phases_other_bound"}> ({
  ^bb0(%arg0: index, %arg1: index):
    %0 = "arith.constant"() <{value = 1 : index}> : () -> index
    "air.launch"(%0, %arg0, %arg1) <{operandSegmentSizes = array<i32: 0, 1, 2>}> ({
    ^bb0(%arg2: index, %arg3: index, %arg4: index, %arg5: index):
      "air.segment"(%arg4, %arg5) <{operandSegmentSizes = array<i32: 0, 0, 2>, sym_name = "seg"}> ({
      ^bb0(%arg6: index, %arg7: index):
        %1 = "arith.constant"() <{value = 0 : index}> : () -> index
        %2 = "arith.constant"() <{value = 1 : index}> : () -> index
        %3:2 = "air.execute"() ({
          %8 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<8xi32, 1>
          "air.execute_terminator"(%8) : (memref<8xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<8xi32, 1>)
        "scf.for"(%1, %arg6, %2) ({
        ^bb0(%arg17: index):
          "air.channel.put"(%3#1) <{chan_name = @cb, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<8xi32, 1>) -> ()
          "scf.yield"() : () -> ()
        }) : (index, index, index) -> ()
        "scf.for"(%1, %arg7, %2) ({
        ^bb0(%arg16: index):
          "air.channel.put"(%3#1) <{chan_name = @cb, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<8xi32, 1>) -> ()
          "scf.yield"() : () -> ()
        }) : (index, index, index) -> ()
        "air.herd"(%2, %2, %arg6, %arg7) <{operandSegmentSizes = array<i32: 0, 2, 2>, sym_name = "h"}> ({
        ^bb0(%arg8: index, %arg9: index, %arg10: index, %arg11: index, %arg12: index, %arg13: index):
          %4 = "arith.constant"() <{value = 0 : index}> : () -> index
          %5 = "arith.constant"() <{value = 1 : index}> : () -> index
          %6:2 = "air.execute"() ({
            %7 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<8xi32, 2>
            "air.execute_terminator"(%7) : (memref<8xi32, 2>) -> ()
          }) : () -> (!air.async.token, memref<8xi32, 2>)
          "scf.for"(%4, %arg12, %5) ({
          ^bb0(%arg15: index):
            "air.channel.get"(%6#1) <{chan_name = @cb, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (memref<8xi32, 2>) -> ()
            "scf.yield"() : () -> ()
          }) : (index, index, index) -> ()
          "scf.for"(%4, %arg12, %5) ({
          ^bb0(%arg14: index):
            "air.channel.get"(%6#1) <{chan_name = @cb, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (memref<8xi32, 2>) -> ()
            "scf.yield"() : () -> ()
          }) : (index, index, index) -> ()
          "air.herd_terminator"() : () -> ()
        }) : (index, index, index, index) -> ()
        "air.segment_terminator"() : () -> ()
      }) : (index, index) -> ()
      "air.launch_terminator"() : () -> ()
    }) : (index, index, index) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
