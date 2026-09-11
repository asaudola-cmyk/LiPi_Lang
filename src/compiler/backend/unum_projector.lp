@! ============================================================================
@! Module: compiler/backend/unum_projector.maya
@! Isomorphically projects a Universal Number onto physical Silicon targets
@! (x86_64 base projection) using algebraic mappings.
@! ============================================================================

import "compiler/backend/universal_number"
import "universe/core/collections"

@! Helper to push 4 bytes (little-endian)
@fn push_i32_le(bytes_list, val)
  v = val
  @if v < 0
    v = v + 4294967296
  @end
  bytes_list = bytes_list.push(v % 256)
  v = v / 256
  bytes_list = bytes_list.push(v % 256)
  v = v / 256
  bytes_list = bytes_list.push(v % 256)
  v = v / 256
  bytes_list = bytes_list.push(v % 256)
  return bytes_list
@end

@fn project_unum_to_x86_64(unum)
  bytes = []
  
  @! Mathematical check of proof signature
  expected_proof = unum.semantic_operator * unum.state_flux
  @if unum.proof_signature != expected_proof
    @! Invalid universal number! Proof mismatch.
    return bytes
  @end

  op = unum.semantic_operator
  flux = unum.state_flux
  
  @if op == 101
    @! UNUM_OP_LOAD_SCALAR -> mapped to x86_64 RAX load (0x48 0xC7 0xC0)
    bytes = bytes.push(72)  @! 0x48
    bytes = bytes.push(199) @! 0xC7
    bytes = bytes.push(192) @! 0xC0
    bytes = push_i32_le(bytes, flux)
  @end
  
  @if op == 102
    @! UNUM_OP_ADD_SCALAR -> mapped to x86_64 RAX add immediate (0x48 0x05)
    bytes = bytes.push(72)  @! 0x48
    bytes = bytes.push(5)   @! 0x05
    bytes = push_i32_le(bytes, flux)
  @end
  
  @if op == 103
    @! UNUM_OP_HALT_RETURN -> mapped to x86_64 RET (0xC3)
    @! Also move rax to rdi so it can be returned as exit code if it's the main function
    @! mov rdi, rax -> 0x48 0x89 0xC7
    bytes = bytes.push(72)
    bytes = bytes.push(137)
    bytes = bytes.push(199)
    bytes = bytes.push(195) @! 0xC3
  @end
  
  return bytes
@end

@fn project_unum_sequence_to_x86_64(program)
  all_bytes = []
  i = 0
  num_items = program.len()
  @while i < num_items
    u = program[i]
    p_bytes = project_unum_to_x86_64(u)
    
    j = 0
    num_p = p_bytes.len()
    @while j < num_p
      all_bytes = all_bytes.push(p_bytes[j])
      j = j + 1
    @end
    i = i + 1
  @end
  return all_bytes
@end
