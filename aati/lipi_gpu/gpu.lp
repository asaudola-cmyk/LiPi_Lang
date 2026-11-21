// ==============================================================================
// 👑 LIPI UNIVERSE GPU — GRAND UMBRELLA PRELUDE (aati/lipi_gpu/gpu.lp)
// ⚡ Compute Shaders, SPIR-V Native Lowering, Direct DRM/KMS Dumb-Buffers
// ==============================================================================
// WHY: Bundles the cohesive high-level typed GPU compute & shader stack
// (compute, shader, directive). Standalone low-level drivers
// `aati/lipi_gpu/spirv_native` and `aati/lipi_gpu/drm` expose direct buffer-level
// primitives and are imported directly when targeting raw DRM/SPIR-V words.
import "aati/lipi_gpu/compute"
import "aati/lipi_gpu/shader"
import "aati/lipi_gpu/directive"

fn lipi_gpu_version
    return "First 1.0.0 (প্রথম ১.০.০)"
