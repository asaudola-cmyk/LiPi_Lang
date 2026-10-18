@! ============================================================================
@! LIPI UNIVERSAL ARCHITECTURE — DOM-BYPASS WEB FRONTEND ENGINE
@! Module: aati/lipi_web/frontend/concurrency/mod.lp
@! Milestone: M3 — Lock-Free WASM Concurrency Engine
@! 100% Pure Lipi Implementation — Zero External Dependencies
@! Features: Subsystem Aggregator Exporting Message Protocol, Ring Buffer,
@! and Worker Pool for Multi-Threaded WASM Frontend Engine
@! ============================================================================

import "aati/lipi_web/frontend/concurrency/message_protocol"
import "aati/lipi_web/frontend/concurrency/ring_buffer"
import "aati/lipi_web/frontend/concurrency/worker_pool"

@fn frontend_concurrency_init(queue_capacity)
  return worker_pool_init(queue_capacity)
@end
