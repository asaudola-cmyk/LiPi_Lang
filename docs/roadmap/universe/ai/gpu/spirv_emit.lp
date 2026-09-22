@! ============================================================================
@! MAYA UNIVERSE GPU — SPIR-V BINARY SHADER EMITTER
@! 100% Written in Pure Maya Language — Zero glslang / Vulkan-SDK Dependencies
@! ============================================================================

import "universe/core/collections"

@! SPIR-V Magic Number: 0x07230203
@fn spirv_builder_new()
  header = [
    0x03, 0x02, 0x23, 0x07, @! Magic Number (Little Endian)
    0x00, 0x03, 0x01, 0x00, @! Version 1.3
    0x00, 0x00, 0x00, 0x00, @! Generator ID (Maya Core)
    0x10, 0x00, 0x00, 0x00, @! Bound
    0x00, 0x00, 0x00, 0x00  @! Schema
  ]
  return {
    words: header,
    instructions: [],
    id_counter: 1
  }
@end

@fn spirv_emit_op(builder, opcode, operands)
  word_count = operands.len() + 1
  first_word = (word_count * 65536) + opcode
  
  builder.words = builder.words.push(first_word % 256)
  builder.words = builder.words.push((first_word / 256) % 256)
  builder.words = builder.words.push((first_word / 65536) % 256)
  builder.words = builder.words.push(0)

  @for op in operands
    builder.words = builder.words.push(op % 256)
    builder.words = builder.words.push((op / 256) % 256)
    builder.words = builder.words.push(0)
    builder.words = builder.words.push(0)
  @end

  return builder
@end

@fn spirv_build_compute_shader(kernel_name)
  b = spirv_builder_new()
  @! OpCapability Shader (Opcode 17)
  b = spirv_emit_op(b, 17, [1])
  @! OpMemoryModel Logical GLSL450 (Opcode 14)
  b = spirv_emit_op(b, 14, [0, 1])
  @! OpEntryPoint GLCompute (Opcode 15)
  b = spirv_emit_op(b, 15, [5, 1, 100])
  @! OpExecutionMode LocalSize 256 1 1 (Opcode 16)
  b = spirv_emit_op(b, 16, [1, 17, 256, 1, 1])
  return b
@end
