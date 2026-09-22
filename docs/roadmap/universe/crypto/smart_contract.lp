@! ============================================================================
@! MAYA UNIVERSE CRYPTO - SMART CONTRACT VM
@! 100% Written in Pure Maya Language
@! ============================================================================

import "universe/core/collections"

@! Smart Contract VM State
@fn sc_vm_new()
  return {
    memory: [],
    stack: [],
    storage: {}, @! Key-value store for state
    pc: 0,
    gas: 0
  }
@end

@! Execute a bytecode instruction
@fn sc_vm_step(vm, instruction)
  @if vm.gas <= 0
    return { error: "Out of Gas" }
  @end
  
  vm.gas = vm.gas - 1
  
  @if instruction.op == "PUSH"
    vm.stack = vm.stack.push(instruction.val)
  @elif instruction.op == "POP"
    @! pop logic
  @elif instruction.op == "ADD"
    @! pop two, add, push
  @elif instruction.op == "SLOAD"
    @! Load from storage
  @elif instruction.op == "SSTORE"
    @! Save to storage
  @end
  
  vm.pc = vm.pc + 1
  return vm
@end
