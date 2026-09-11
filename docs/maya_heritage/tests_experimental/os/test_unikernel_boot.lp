@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — MAYA RING-0 UNIKERNEL TEST SUITE
@! File: tests/os/test_unikernel_boot.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/os/unikernel"

@fn assert_true(cond, msg)
  @if cond == 0
    println(str_concat("  [FAIL] Assertion failed: ", msg))
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println(str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> Expected ", str_concat(to_str(expected), str_concat(", got ", to_str(actual)))))))
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("☁️ MAYA RING-0 UNIKERNEL (5MS CLOUD/AWS BOOT) TEST SUITE ☁️")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: Unikernel Image Linkage & Multiboot2 Header Emitter
  println("▶ Section 1: Ring-0 Bare-Metal Unikernel Image & Multiboot2 Emitter...")
  total_tests = total_tests + 1
  img = unikernel_build_image("MayaCloudMicroVM", 9999)
  
  ok1 = assert_eq_int(img.boot_time_ms, 5, "Unikernel cold boot time is 5ms")
  ok2 = assert_eq_int(img.ring_privilege, 0, "Execution privilege is Ring-0 (Direct Hardware Access)")
  ok3 = assert_eq_int(img.is_virtio_enabled, 1, "VirtIO cloud standard driver enabled")
  ok4 = assert_eq_int(img.multiboot_header_bytes.len(), 16, "Multiboot2 16-byte header generated")
  ok5 = assert_eq_int(img.multiboot_header_bytes[0], 214, "Multiboot2 magic 0xE85250D6 byte 0 is 214")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Ring-0 Unikernel image & Multiboot2 header verified")
  @end

  @! SECTION 2: VirtIO Network Packet Transmission & Diagnostics
  println("▶ Section 2: VirtIO Network Packet Transmit & Remote Logging...")
  total_tests = total_tests + 1
  img = unikernel_virtio_send_packet(img, [72, 84, 84, 80]) @! "HTTP"
  ok1 = assert_eq_int(img.tx_packets_count, 1, "VirtIO TX packets counter incremented")

  img = unikernel_emit_diagnostic_log(img, "TCP Web Server Online on port 8080 (0 kernel context switches)")
  ok2 = assert_eq_int(img.log_buffer.len(), 1, "Diagnostic log message recorded")
  ok3 = assert_true(string_contains(img.log_buffer[0], "0 kernel context switches"), "Diagnostic message logged accurately")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] VirtIO network driver and remote diagnostic logging verified")
  @end

  res_str = str_concat("📊 UNIKERNEL TEST RESULTS: ", str_concat(to_str(passed_tests), str_concat(" / ", str_concat(to_str(total_tests), " passed"))))
  println(res_str)
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 2 MAYA UNIKERNEL TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME UNIKERNEL TESTS FAILED")
    return 1
  @end
@end
