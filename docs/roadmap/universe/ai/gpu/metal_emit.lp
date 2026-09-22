@! ============================================================================
@! MAYA UNIVERSE GPU — APPLE METAL SHADING LANGUAGE (MSL) EMITTER
@! 100% Written in Pure Maya Language — Apple Silicon Acceleration
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"

@fn msl_kernel_new(name)
  code = "#include <metal_stdlib>\n"
  code = code + "using namespace metal;\n\n"
  code = code + "kernel void " + name + "(\n"
  code = code + "  device const float* in [[buffer(0)]],\n"
  code = code + "  device float* out [[buffer(1)]],\n"
  code = code + "  uint id [[thread_position_in_grid]])\n"
  code = code + "{\n"
  code = code + "  out[id] = in[id] * 2.0f;\n"
  code = code + "}\n"
  return { name: name, source: code }
@end
