@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — HARDWARE DMA OFFLOAD TEST SUITE
@! File: tests/io/test_dma_offload.maya
@! ============================================================================

import "universe/core/collections"
import "universe/io/dma"

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
  println("⚡ MAYA CPU-ZERO-TOUCH HARDWARE DMA OFFLOAD TEST SUITE ⚡")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: DMA Controller & Scatter-Gather Descriptor Chaining
  println("▶ Section 1: Scatter-Gather PCIe DMA Descriptor Chaining...")
  total_tests = total_tests + 1
  dma_ctrl = dma_controller_new(4294967296, 8589934592) @! 4GB NIC base, 8GB NVMe base
  
  @! Queue 2 large scatter-gather DMA chunks (50GB + 50GB = 100GB total)
  dma_ctrl = dma_add_scatter_gather_desc(dma_ctrl, 0, 0, 53687091200)
  dma_ctrl = dma_add_scatter_gather_desc(dma_ctrl, 53687091200, 53687091200, 53687091200)

  ok1 = assert_eq_int(dma_ctrl.descriptors.len(), 2, "Chained 2 scatter-gather DMA descriptors")
  desc0 = dma_ctrl.descriptors[0]
  ok2 = assert_eq_int(desc0.transfer_bytes, 53687091200, "Descriptor 0 payload size is 50GB")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Scatter-gather DMA descriptor chaining verified")
  @end

  @! SECTION 2: Zero-Touch Direct Bus DMA Transfer & CPU Overhead (0%)
  println("▶ Section 2: Peer-to-Peer Bus Streaming & CPU Overhead Calculation...")
  total_tests = total_tests + 1
  streamed_bytes = dma_execute_p2p_stream(dma_ctrl)
  
  ok1 = assert_eq_int(streamed_bytes, 107374182400, "Successfully transferred 100 GB via PCIe DMA bus")
  ok2 = assert_eq_int(dma_ctrl.cpu_cycles_spent, 0, "CPU cycles spent during transfer is strictly 0 (0% CPU utilization)")
  ok3 = assert_eq_int(dma_ctrl.total_transferred_bytes, 107374182400, "Total transferred bytes counter updated")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Zero-touch hardware DMA offload and 0% CPU utilization verified")
  @end

  println("=================================================================")
  println("📊 DMA OFFLOAD TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 2 HARDWARE DMA OFFLOAD TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME HARDWARE DMA TESTS FAILED")
    return 1
  @end
@end
