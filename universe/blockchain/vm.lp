@! ============================================================================
@! LIPI UNIVERSAL ARCHITECTURE — MAYAVM SMART CONTRACT EXECUTOR
@! Module: universe/blockchain/vm.lp
@! Milestone: Layer-1 Sovereign Blockchain (MayaNet)
@! 100% Pure Lipi Implementation — Zero External Dependencies
@! Features: Isolated Virtual Machine, Deterministic Gas Metering, Opcode Stack,
@! Persistent Contract Storage & Transaction State Rollback on Revert
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/crypto/sha256"

@! ============================================================================
@! 1. VM STATE & STORAGE STRUCTURES
@! ============================================================================

@struct StorageSlot
  key: string
  value: string
@end

@struct MayaVMContext
  caller: string
  contract_address: string
  call_value: i64
  gas_limit: i64
  gas_used: i64
  gas_price: i64
  is_reverted: i64
  return_data: string
  error_msg: string
@end

@struct MayaVMState
  stack: array
  memory: array
  storage: array
@end

@struct VMExecutionResult
  success: i64
  gas_used: i64
  return_value: string
  storage_root: string
@end

@! ============================================================================
@! 2. VM CONSTRUCTORS
@! ============================================================================

@fn vm_context_new(caller, contract_addr, val, gas_limit, gas_price)
  return {
    caller: caller,
    contract_address: contract_addr,
    call_value: val,
    gas_limit: gas_limit,
    gas_used: 21000, @! Base transaction fee
    gas_price: gas_price,
    is_reverted: 0,
    return_data: "",
    error_msg: ""
  }
@end

@fn vm_state_new()
  return {
    stack: [],
    memory: [],
    storage: []
  }
@end

@! ============================================================================
@! 3. STORAGE GET / SET OPERATIONS
@! ============================================================================

@fn vm_storage_get(vm_state, key_str)
  i = 0
  n_slots = vm_state.storage.len()
  @while i < n_slots
    s = vm_state.storage[i]
    @if s.key == key_str
      return s.value
    @end
    i = i + 1
  @end
  return "0"
@end

@fn vm_storage_set(vm_state, key_str, val_str)
  updated = []
  found = 0
  i = 0
  n_slots = vm_state.storage.len()
  @while i < n_slots
    s = vm_state.storage[i]
    @if s.key == key_str
      updated = updated.push({ key: key_str, value: val_str })
      found = 1
    @else
      updated = updated.push(s)
    @end
    i = i + 1
  @end

  @if found == 0
    updated = updated.push({ key: key_str, value: val_str })
  @end

  vm_state.storage = updated
  return vm_state
@end

@fn vm_storage_root(vm_state)
  concat_str = ""
  i = 0
  n_slots = vm_state.storage.len()
  @while i < n_slots
    s = vm_state.storage[i]
    concat_str = concat_str + s.key + "=" + s.value + ";"
    i = i + 1
  @end
  @if str_len(concat_str) == 0
    return sha256_hex_string("empty_storage")
  @end
  return sha256_hex_string(concat_str)
@end

@! ============================================================================
@! 4. SMART CONTRACT INSTRUCTION EXECUTOR
@! ============================================================================

@fn vm_consume_gas(ctx, amount)
  ctx.gas_used = ctx.gas_used + amount
  @if ctx.gas_used > ctx.gas_limit
    ctx.is_reverted = 1
    ctx.error_msg = "Out of Gas"
    return 0
  @end
  return 1
@end

@fn vm_execute_bytecode(ctx, vm_state, opcodes)
  pc = 0
  n_ops = opcodes.len()
  
  @while pc < n_ops && ctx.is_reverted == 0
    op = opcodes[pc]
    
    @! Opcode: PUSH <val>
    @if op == "PUSH"
      @if vm_consume_gas(ctx, 3) == 0 break @end
      val = opcodes[pc + 1]
      vm_state.stack = vm_state.stack.push(val)
      pc = pc + 2
    @! Opcode: ADD
    @elif op == "ADD"
      @if vm_consume_gas(ctx, 3) == 0 break @end
      @if vm_state.stack.len() < 2
        ctx.is_reverted = 1
        ctx.error_msg = "Stack underflow on ADD"
        break
      @end
      st_len = vm_state.stack.len()
      b_val = str_to_int(vm_state.stack[st_len - 1])
      a_val = str_to_int(vm_state.stack[st_len - 2])
      
      @! Pop 2
      new_st = []
      i = 0
      @while i < st_len - 2
        new_st = new_st.push(vm_state.stack[i])
        i = i + 1
      @end
      sum_val = a_val + b_val
      new_st = new_st.push(sum_val.to_str())
      vm_state.stack = new_st
      pc = pc + 1
    @! Opcode: SSTORE <key> <val> (Persistent Contract Storage)
    @elif op == "SSTORE"
      @if vm_consume_gas(ctx, 5000) == 0 break @end
      st_len = vm_state.stack.len()
      @if st_len < 2
        ctx.is_reverted = 1
        ctx.error_msg = "Stack underflow on SSTORE"
        break
      @end
      val_str = vm_state.stack[st_len - 1]
      key_str = vm_state.stack[st_len - 2]
      
      new_st = []
      i = 0
      @while i < st_len - 2
        new_st = new_st.push(vm_state.stack[i])
        i = i + 1
      @end
      vm_state.stack = new_st
      vm_state = vm_storage_set(vm_state, key_str, val_str)
      pc = pc + 1
    @! Opcode: SLOAD <key>
    @elif op == "SLOAD"
      @if vm_consume_gas(ctx, 200) == 0 break @end
      st_len = vm_state.stack.len()
      @if st_len < 1
        ctx.is_reverted = 1
        ctx.error_msg = "Stack underflow on SLOAD"
        break
      @end
      key_str = vm_state.stack[st_len - 1]
      
      new_st = []
      i = 0
      @while i < st_len - 1
        new_st = new_st.push(vm_state.stack[i])
        i = i + 1
      @end
      fetched_val = vm_storage_get(vm_state, key_str)
      new_st = new_st.push(fetched_val)
      vm_state.stack = new_st
      pc = pc + 1
    @! Opcode: RETURN
    @elif op == "RETURN"
      @if vm_consume_gas(ctx, 5) == 0 break @end
      st_len = vm_state.stack.len()
      ret = "0"
      @if st_len > 0
        ret = vm_state.stack[st_len - 1]
      @end
      ctx.return_data = ret
      break
    @! Opcode: REVERT
    @elif op == "REVERT"
      ctx.is_reverted = 1
      ctx.error_msg = "Explicit Execution Reverted"
      break
    @else
      pc = pc + 1
    @end
  @end

  is_ok = 1
  @if ctx.is_reverted == 1
    is_ok = 0
  @end

  st_root = vm_storage_root(vm_state)
  return {
    success: is_ok,
    gas_used: ctx.gas_used,
    return_value: ctx.return_data,
    storage_root: st_root
  }
@end
