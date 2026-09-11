@! ARM64 ABI constants

@fn arm64_abi_arg_regs()
  return [0, 1, 2, 3, 4, 5, 6, 7]
@end

@fn arm64_abi_ret_reg()
  return 0
@end

@fn arm64_abi_callee_saved()
  return [19, 20, 21, 22, 23, 24, 25, 26, 27, 28]
@end

@fn arm64_abi_stack_align()
  return 16
@end
