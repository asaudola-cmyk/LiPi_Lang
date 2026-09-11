@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — EBPF & SMARTNIC P4 TEST SUITE
@! File: tests/net/test_ebpf_p4.maya
@! ============================================================================

import "universe/core/collections"
import "universe/net/ebpf_p4"

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
  println("🛡️ MAYA EBPF & SMARTNIC (P4) IN-HARDWARE PIPELINE TEST SUITE 🛡️")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: eBPF Bytecode Instruction Assembly & Serialization
  println("▶ Section 1: 64-Bit eBPF Bytecode Assembly for SmartNIC...")
  total_tests = total_tests + 1
  pipe = smartnic_pipeline_new("SmartNIC_Port0")
  @! eBPF: MOV R1, 1 -> JEQ R1, 1 -> EXIT
  pipe = smartnic_add_ebpf_inst(pipe, 183, 1, 0, 0, 1)
  pipe = smartnic_add_ebpf_inst(pipe, 21, 1, 0, 1, 1)
  pipe = smartnic_add_ebpf_inst(pipe, 149, 0, 0, 0, 0)

  ok1 = assert_eq_int(pipe.ebpf_bytecode.len(), 3, "Assembled 3 eBPF hardware instructions")
  inst0 = pipe.ebpf_bytecode[0]
  ok2 = assert_eq_int(inst0.opcode, 183, "Opcode 0 is BPF_MOV (0xB7 = 183)")

  @! Verify 8-byte instruction binary serialization
  raw_bytes = ebpf_serialize_bytecode(pipe)
  ok3 = assert_eq_int(raw_bytes.len(), 24, "Serialized 3 instructions into 24-byte eBPF binary bytecode")
  ok4 = assert_eq_int(raw_bytes[0], 183, "Bytecode byte 0 is opcode 183")

  @! Verify 64-bit sovereign VM execution
  vm_res = smartnic_execute_ebpf_vm(pipe, [1, 80])
  ok5 = assert_eq_int(vm_res, 0, "64-bit eBPF VM executed and returned R0")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] 64-bit eBPF instruction assembly, serialization & VM execution verified")
  @end

  @! SECTION 2: P4 Match-Action Firewall Rules Setup
  println("▶ Section 2: P4 Match-Action Hardware Firewall Tables...")
  total_tests = total_tests + 1
  @! Rule 1: Drop TCP traffic on port 23 (Telnet attack)
  pipe = smartnic_add_p4_firewall_rule(pipe, 6, 23, 1)
  @! Rule 2: Pass TCP traffic on port 443 (HTTPS)
  pipe = smartnic_add_p4_firewall_rule(pipe, 6, 443, 2)

  ok1 = assert_eq_int(pipe.p4_rules.len(), 2, "Installed 2 P4 hardware table rules")
  @if ok1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] P4 match-action table rules verified")
  @end

  @! SECTION 3: In-NIC Line-Rate Hardware Packet Evaluation
  println("▶ Section 3: In-NIC Line-Rate Packet Evaluation (Pre-Host RAM)...")
  total_tests = total_tests + 1
  @! Attack packet on port 23 -> must be dropped in NIC
  action_telnet = smartnic_evaluate_packet(pipe, 6, 23)
  ok1 = assert_eq_int(action_telnet, 1, "Attack packet on port 23 dropped directly in SmartNIC (Action = DROP)")
  ok2 = assert_eq_int(pipe.dropped_packets_count, 1, "Dropped packets counter is 1")

  @! Legitimate HTTPS packet on port 443 -> passed to host
  action_https = smartnic_evaluate_packet(pipe, 6, 443)
  ok3 = assert_eq_int(action_https, 2, "HTTPS packet on port 443 passed to host OS (Action = PASS)")
  ok4 = assert_eq_int(pipe.passed_packets_count, 1, "Passed packets counter is 1")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] In-NIC hardware packet filtering & host defense verified")
  @end

  println("=================================================================")
  println("📊 SMARTNIC P4 TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 3 EBPF & SMARTNIC P4 TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME SMARTNIC TESTS FAILED")
    return 1
  @end
@end
