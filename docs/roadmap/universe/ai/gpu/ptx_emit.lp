@! ============================================================================
@! MAYA UNIVERSE GPU — NVIDIA PTX MACHINE CODE EMITTER
@! 100% Written in Pure Maya Language — Direct CUDA Hardware Execution
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"

@fn ptx_program_new(kernel_name)
  code = ".version 7.0\n"
  code = code + ".target sm_80\n"
  code = code + ".address_size 64\n\n"
  code = code + ".visible .entry " + kernel_name + "(\n"
  code = code + "  .param .u64 in_ptr,\n"
  code = code + "  .param .u64 out_ptr,\n"
  code = code + "  .param .u32 n\n"
  code = code + ") {\n"
  return { kernel: kernel_name, ptx: code }
@end

@fn ptx_emit_vector_add(ptx_prog)
  body = "  .reg .b32 %r<10>;\n"
  body = body + "  .reg .b64 %rd<10>;\n"
  body = body + "  .reg .f32 %f<10>;\n"
  body = body + "  .reg .pred %p<2>;\n\n"
  body = body + "  mov.u32 %r0, %ctaid.x;\n"
  body = body + "  mov.u32 %r1, %ntid.x;\n"
  body = body + "  mov.u32 %r2, %tid.x;\n"
  body = body + "  mad.lo.s32 %r3, %r0, %r1, %r2;\n"
  body = body + "  ld.param.u32 %r4, [n];\n"
  body = body + "  setp.ge.s32 %p0, %r3, %r4;\n"
  body = body + "  @%p0 bra $L_EXIT;\n\n"
  body = body + "  ld.param.u64 %rd0, [in_ptr];\n"
  body = body + "  ld.param.u64 %rd1, [out_ptr];\n"
  body = body + "  mul.wide.s32 %rd2, %r3, 4;\n"
  body = body + "  add.s64 %rd3, %rd0, %rd2;\n"
  body = body + "  ld.global.f32 %f0, [%rd3];\n"
  body = body + "  add.f32 %f1, %f0, %f0;\n"
  body = body + "  add.s64 %rd4, %rd1, %rd2;\n"
  body = body + "  st.global.f32 [%rd4], %f1;\n\n"
  body = body + "$L_EXIT:\n"
  body = body + "  ret;\n"
  body = body + "}\n"
  
  ptx_prog.ptx = ptx_prog.ptx + body
  return ptx_prog
@end
