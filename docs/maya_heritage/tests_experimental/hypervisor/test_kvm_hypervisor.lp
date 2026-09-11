@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — KVM HYPERVISOR TEST SUITE
@! File: tests/hypervisor/test_kvm_hypervisor.maya
@! ============================================================================

import "universe/core/collections"
import "universe/hypervisor/kvm"

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println("  [FAIL] Assertion failed: " + msg)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("🖥️ MAYA NATIVE LINUX KVM HYPERVISOR TEST SUITE 🖥️")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: Virtual Machine & Guest RAM Allocation (64KB)
  println("▶ Section 1: VM Creation & Guest RAM Allocation (64KB)...")
  total_tests = total_tests + 1
  vm = kvm_create_vm(65536)
  ok1 = assert_eq_int(vm.guest_ram_size, 65536, "Guest RAM allocated 65536 bytes")
  ok2 = assert_eq_int(vm.regs.rip, 0, "vCPU initial instruction pointer RIP is 0")
  ok3 = assert_eq_int(vm.is_running, 1, "VM state initialized to RUNNING")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] KVM VM creation & guest RAM allocation verified")
  @end

  @! SECTION 2: Loading Guest x86 Machine Code & Stepping
  println("▶ Section 2: Loading Guest Machine Code & Instruction Stepping...")
  total_tests = total_tests + 1
  @! Guest code:
  @! 0xB8, 0x2A, 0x00, 0x00, 0x00 (MOV EAX, 42)
  @! 0x90                         (NOP)
  @! 0xE7, 0x80                   (OUT 0x80, EAX) -> Hypervisor I/O Exit
  @! 0xF4                         (HLT)
  guest_code = [184, 42, 0, 0, 0, 144, 231, 128, 244]
  vm = kvm_load_guest_code(vm, guest_code, 0)
  
  @! Step 1: MOV EAX, 42
  vm = kvm_step_vcpu(vm)
  ok1 = assert_eq_int(vm.regs.rax, 42, "vCPU executed MOV EAX, 42 -> RAX is 42")
  ok2 = assert_eq_int(vm.regs.rip, 5, "RIP advanced by 5 bytes")

  @! Step 2: NOP
  vm = kvm_step_vcpu(vm)
  ok3 = assert_eq_int(vm.regs.rip, 6, "RIP advanced by 1 byte past NOP")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Guest x86 register transitions & instruction stepping verified")
  @end

  @! SECTION 3: Hypervisor I/O Intercept & Guest Halt
  println("▶ Section 3: Hypervisor I/O Exit & HLT Interception...")
  total_tests = total_tests + 1
  @! Step 3: OUT 0x80, EAX -> Exit Reason 2 (KVM_EXIT_IO)
  vm = kvm_step_vcpu(vm)
  ok1 = assert_eq_int(vm.last_exit.exit_reason, 2, "KVM intercepted I/O exit (exit_reason = 2)")
  ok2 = assert_eq_int(vm.last_exit.io_port, 128, "I/O exit port matches 0x80 (128)")
  ok3 = assert_eq_int(vm.last_exit.io_data, 42, "I/O exit transmitted EAX data 42")

  @! Step 4: HLT -> Exit Reason 5 (KVM_EXIT_HLT)
  vm = kvm_step_vcpu(vm)
  ok4 = assert_eq_int(vm.last_exit.exit_reason, 5, "KVM intercepted HLT exit (exit_reason = 5)")
  ok5 = assert_eq_int(vm.is_running, 0, "VM execution cleanly stopped on HLT")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Hypervisor I/O port interception and HLT lifecycle verified")
  @end

  println("=================================================================")
  println("📊 KVM HYPERVISOR TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 3 KVM HYPERVISOR TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME KVM HYPERVISOR TESTS FAILED")
    return 1
  @end
@end
