<?php

declare(strict_types=1);

namespace Unum;

use FFI;
use RuntimeException;

/**
 * 👑 Hardware Executor & Silicon Bridge
 * 
 * WHY: Bridges PHP directly to native CPU silicon via System V AMD64 ABI.
 * Allocates executable memory pages (mmap PROT_EXEC), compiles 64-bit Universal Numbers
 * into native machine code, and invokes direct hardware execution in nanoseconds.
 */
final class HardwareExecutor
{
    private static ?FFI $ffi = null;
    private static ?string $libPath = null;
    private static bool $isEmulated = false;

    public function __construct(?string $libPath = null)
    {
        if (self::$ffi === null && !self::$isEmulated) {
            try {
                if (!extension_loaded('ffi') || !class_exists('\FFI')) {
                    throw new RuntimeException("FFI extension is not loaded in PHP runtime.");
                }

                $ffiEnable = ini_get('ffi.enable');
                if ($ffiEnable === '0' || strtolower((string)$ffiEnable) === 'false' || (PHP_SAPI !== 'cli' && $ffiEnable === 'preload')) {
                    throw new RuntimeException("FFI execution restricted by php.ini (cPanel/shared hosting policy).");
                }

                $path = $libPath ?? dirname(__DIR__, 2) . '/libs/libunum.so';
                if (!file_exists($path)) {
                    throw new RuntimeException("UNUM native library not found at: {$path}.");
                }
                self::$libPath = realpath($path);

                $cdefs = <<<'CDEF'
                typedef uint64_t unum_t;
                unum_t unum_encode(uint8_t op, uint8_t type, uint8_t reg_dest, uint8_t reg_src, uint8_t simd, uint32_t payload);
                void unum_decode(unum_t num, uint8_t *op, uint8_t *type, uint8_t *reg_dest, uint8_t *reg_src, uint8_t *simd, uint32_t *payload);
                void* unum_alloc_executable_page(size_t size);
                int unum_free_executable_page(void *addr, size_t size);
                int unum_emit_machine_code(const unum_t *numbers, size_t count, uint8_t *code_buffer, size_t max_size, size_t *emitted_size);
                int64_t unum_execute(const void *code_page, int64_t arg1, int64_t arg2, int64_t arg3);
                float unum_simd_dot_f32(const float *a, const float *b, size_t dim);
                float unum_simd_dot_batch(const float *a, const float *b, size_t dim, size_t count);
                void unum_tensor_matmul_f32(const float *A, const float *B, float *C, size_t M, size_t K, size_t N);
                void unum_tensor_activate_f32(float *data, size_t size, int activation_type);
                float unum_tensor_cosine_similarity(const float *a, const float *b, size_t dim);
                void unum_tensor_rmsnorm_f32(const float *x, const float *weight, float *out, size_t dim, float eps);
                void unum_tensor_rope_f32(float *q, float *k, size_t seq_len, size_t num_heads, size_t head_dim, size_t pos_offset);
                void unum_tensor_mha_f32(const float *Q, const float *K, const float *V, float *out, size_t seq_len, size_t num_heads, size_t head_dim);
                int unum_shm_create(const char *name, size_t size, void **addr_out);
                int unum_shm_open(const char *name, size_t size, void **addr_out);
                int unum_shm_close(void *addr, size_t size);
                int unum_shm_unlink(const char *name);
                uint64_t unum_atomic_cas64(uint64_t *ptr, uint64_t old_val, uint64_t new_val);
                uint64_t unum_atomic_fetch_add64(uint64_t *ptr, uint64_t val);
                size_t unum_column_filter_gt_i64(const int64_t *col, size_t size, int64_t threshold, uint8_t *bitmap_out);
                int64_t unum_column_sum_i64(const int64_t *col, const uint8_t *bitmap, size_t size);
                size_t unum_column_filter_gt_f32(const float *col, size_t size, float threshold, uint8_t *bitmap_out);
                float unum_column_sum_f32(const float *col, const uint8_t *bitmap, size_t size);
                uint32_t unum_cpu_features(void);
CDEF;

                self::$ffi = FFI::cdef($cdefs, self::$libPath);
                self::$isEmulated = false;
            } catch (\Throwable $e) {
                self::$ffi = null;
                self::$isEmulated = true;
            }
        }
    }

    /**
     * Returns true if running in pure PHP emulation mode (cPanel / restricted hosting).
     */
    public function isEmulated(): bool
    {
        return self::$isEmulated;
    }

    /**
     * Allocates page-aligned executable memory via POSIX mmap.
     */
    public function allocPage(int $size = 4096): FFI\CData
    {
        $page = self::$ffi->unum_alloc_executable_page($size);
        if ($page === null) {
            throw new RuntimeException("Failed to allocate executable memory page via mmap(PROT_EXEC).");
        }
        return $page;
    }

    /**
     * Frees an executable memory page via POSIX munmap.
     */
    public function freePage(FFI\CData $page, int $size = 4096): int
    {
        return self::$ffi->unum_free_executable_page($page, $size);
    }

    /**
     * Compiles an array of Universal Numbers into an executable memory page.
     * 
     * @param UniversalNumber[] $numbers
     * @return array{page: FFI\CData, emitted_bytes: int, size: int}
     */
    public function compile(array $numbers, int $pageSize = 4096): array
    {
        $count = count($numbers);
        if ($count === 0) {
            throw new RuntimeException("Cannot compile empty universal number sequence.");
        }

        /* Allocate C array of unum_t */
        $cArray = self::$ffi->new("unum_t[{$count}]");
        foreach ($numbers as $i => $num) {
            $cArray[$i] = $num->toInt();
        }

        /* Allocate executable memory page */
        $page = $this->allocPage($pageSize);

        /* Emit machine code bytes */
        $emittedSizePtr = self::$ffi->new("size_t");
        $codeBuffer = FFI::cast("uint8_t*", $page);

        $err = self::$ffi->unum_emit_machine_code($cArray, $count, $codeBuffer, $pageSize, FFI::addr($emittedSizePtr));
        if ($err !== 0) {
            $this->freePage($page, $pageSize);
            throw new RuntimeException("Machine code emission failed with error code: {$err}");
        }

        $emittedBytes = (int)$emittedSizePtr->cdata;

        return [
            'page'          => $page,
            'emitted_bytes' => $emittedBytes,
            'size'          => $pageSize,
        ];
    }

    /**
     * Executes the machine code directly on the CPU registers.
     * Passes arg1 -> RDI, arg2 -> RSI, arg3 -> RDX.
     * Returns RAX directly to PHP.
     */
    public function execute(FFI\CData $page, int $arg1 = 0, int $arg2 = 0, int $arg3 = 0): int
    {
        return self::$ffi->unum_execute($page, $arg1, $arg2, $arg3);
    }

    /**
     * High-speed hardware AVX-512 / AVX2 vector dot product.
     * 
     * @param float[] $vecA
     * @param float[] $vecB
     */
    public function simdDot(array $vecA, array $vecB): float
    {
        $dim = count($vecA);
        if ($dim !== count($vecB)) {
            throw new RuntimeException("Vector dimension mismatch: " . $dim . " vs " . count($vecB));
        }

        $cA = self::$ffi->new("float[{$dim}]");
        $cB = self::$ffi->new("float[{$dim}]");

        for ($i = 0; $i < $dim; $i++) {
            $cA[$i] = (float)$vecA[$i];
            $cB[$i] = (float)$vecB[$i];
        }

        return (float)self::$ffi->unum_simd_dot_f32($cA, $cB, $dim);
    }

    /**
     * High-speed batch hardware AVX SIMD execution.
     * Computes dot product 'count' times in native C with zero per-iteration FFI overhead.
     * 
     * @param float[] $vecA
     * @param float[] $vecB
     */
    public function simdDotBatch(array $vecA, array $vecB, int $count): float
    {
        $dim = count($vecA);
        if ($dim !== count($vecB)) {
            throw new RuntimeException("Vector dimension mismatch: " . $dim . " vs " . count($vecB));
        }

        $cA = self::$ffi->new("float[{$dim}]");
        $cB = self::$ffi->new("float[{$dim}]");

        for ($i = 0; $i < $dim; $i++) {
            $cA[$i] = (float)$vecA[$i];
            $cB[$i] = (float)$vecB[$i];
        }

        return (float)self::$ffi->unum_simd_dot_batch($cA, $cB, $dim, $count);
    }

    /**
     * Returns the raw internal FFI instance for zero-copy operations.
     */
    public function getFfi(): FFI
    {
        return self::$ffi;
    }

    /**
     * Allocates a contiguous, memory-aligned C float buffer.
     */
    public function newFloatBuffer(int $count): FFI\CData
    {
        if ($count <= 0) {
            throw new RuntimeException("Buffer size must be greater than zero, got: {$count}");
        }
        return self::$ffi->new("float[{$count}]");
    }

    /**
     * Executes vectorized bare-metal matrix multiplication: C = A x B.
     * Dimensions: A is M x K, B is K x N, C is M x N.
     */
    public function tensorMatmul(FFI\CData $A, FFI\CData $B, FFI\CData $C, int $M, int $K, int $N): void
    {
        self::$ffi->unum_tensor_matmul_f32($A, $B, $C, $M, $K, $N);
    }

    /**
     * Executes vectorized neural network activation on a contiguous float buffer.
     * Activation Type: 0 = ReLU, 1 = GELU, 2 = Softmax.
     */
    public function tensorActivate(FFI\CData $data, int $size, int $activationType): void
    {
        self::$ffi->unum_tensor_activate_f32($data, $size, $activationType);
    }

    /**
     * Computes vectorized cosine similarity between two float buffers.
     */
    public function tensorCosineSimilarity(FFI\CData $a, FFI\CData $b, int $dim): float
    {
        return (float)self::$ffi->unum_tensor_cosine_similarity($a, $b, $dim);
    }

    /**
     * Executes vectorized Root Mean Square Normalization (RMSNorm) on a contiguous float buffer.
     */
    public function tensorRmsNorm(FFI\CData $x, ?FFI\CData $weight, FFI\CData $out, int $dim, float $eps = 1e-5): void
    {
        self::$ffi->unum_tensor_rmsnorm_f32($x, $weight, $out, $dim, $eps);
    }

    /**
     * Executes vectorized Rotary Position Embedding (RoPE) on query and key attention heads.
     */
    public function tensorRope(FFI\CData $q, ?FFI\CData $k, int $seqLen, int $numHeads, int $headDim, int $posOffset = 0): void
    {
        self::$ffi->unum_tensor_rope_f32($q, $k, $seqLen, $numHeads, $headDim, $posOffset);
    }

    /**
     * Executes fused Multi-Head Scaled Dot-Product Attention: out = Softmax(Q * K^T / sqrt(d)) * V.
     */
    public function tensorMha(FFI\CData $Q, FFI\CData $K, FFI\CData $V, FFI\CData $out, int $seqLen, int $numHeads, int $headDim): void
    {
        self::$ffi->unum_tensor_mha_f32($Q, $K, $V, $out, $seqLen, $numHeads, $headDim);
    }

    /**
     * Creates a POSIX Shared Memory segment mapped into the process virtual address space.
     * 
     * @return array{addr: FFI\CData, size: int}
     */
    public function shmCreate(string $name, int $size): array
    {
        $addrPtr = self::$ffi->new("void*[1]");
        $err = self::$ffi->unum_shm_create($name, $size, FFI::addr($addrPtr[0]));
        if ($err !== 0) {
            throw new RuntimeException("Failed to create shared memory '{$name}' of size {$size}, code: {$err}");
        }
        return [
            'addr' => $addrPtr[0],
            'size' => $size,
        ];
    }

    /**
     * Opens an existing POSIX Shared Memory segment.
     * 
     * @return array{addr: FFI\CData, size: int}
     */
    public function shmOpen(string $name, int $size): array
    {
        $addrPtr = self::$ffi->new("void*[1]");
        $err = self::$ffi->unum_shm_open($name, $size, FFI::addr($addrPtr[0]));
        if ($err !== 0) {
            throw new RuntimeException("Failed to open shared memory '{$name}' of size {$size}, code: {$err}");
        }
        return [
            'addr' => $addrPtr[0],
            'size' => $size,
        ];
    }

    /**
     * Unmaps a shared memory address.
     */
    public function shmClose(FFI\CData $addr, int $size): int
    {
        return self::$ffi->unum_shm_close($addr, $size);
    }

    /**
     * Unlinks a POSIX Shared Memory segment by name.
     */
    public function shmUnlink(string $name): int
    {
        return self::$ffi->unum_shm_unlink($name);
    }

    /**
     * Atomic 64-bit Compare-And-Swap (hardware CMPXCHG).
     */
    public function atomicCas64(FFI\CData $ptr, int $oldVal, int $newVal): int
    {
        return (int)self::$ffi->unum_atomic_cas64($ptr, $oldVal, $newVal);
    }

    /**
     * Atomic 64-bit Fetch-And-Add (hardware XADD).
     */
    public function atomicFetchAdd64(FFI\CData $ptr, int $val): int
    {
        return (int)self::$ffi->unum_atomic_fetch_add64($ptr, $val);
    }

    /**
     * Allocates a contiguous C int64_t buffer.
     */
    public function newInt64Buffer(int $count): FFI\CData
    {
        if ($count <= 0) {
            throw new RuntimeException("Buffer count must be greater than zero, got: {$count}");
        }
        return self::$ffi->new("int64_t[{$count}]");
    }

    /**
     * Allocates a contiguous C uint8_t buffer.
     */
    public function newUint8Buffer(int $count): FFI\CData
    {
        if ($count <= 0) {
            throw new RuntimeException("Buffer count must be greater than zero, got: {$count}");
        }
        return self::$ffi->new("uint8_t[{$count}]");
    }

    /**
     * SIMD Columnar Filter: col[i] > threshold. Populates bitmapOut with 1/0.
     */
    public function columnFilterGtI64(FFI\CData $col, int $size, int $threshold, FFI\CData $bitmapOut): int
    {
        return (int)self::$ffi->unum_column_filter_gt_i64($col, $size, $threshold, $bitmapOut);
    }

    /**
     * SIMD Columnar Sum with optional filter bitmap.
     */
    public function columnSumI64(FFI\CData $col, ?FFI\CData $bitmap, int $size): int
    {
        return (int)self::$ffi->unum_column_sum_i64($col, $bitmap, $size);
    }

    /**
     * SIMD Columnar Filter Float32: col[i] > threshold. Populates bitmapOut with 1/0.
     */
    public function columnFilterGtF32(FFI\CData $col, int $size, float $threshold, FFI\CData $bitmapOut): int
    {
        return (int)self::$ffi->unum_column_filter_gt_f32($col, $size, $threshold, $bitmapOut);
    }

    /**
     * SIMD Columnar Sum Float32 with optional filter bitmap.
     */
    public function columnSumF32(FFI\CData $col, ?FFI\CData $bitmap, int $size): float
    {
        return (float)self::$ffi->unum_column_sum_f32($col, $bitmap, $size);
    }

    /**
     * Returns hardware CPU capabilities.
     * 
     * @return array{avx: bool, avx2: bool, avx512: bool, fma: bool}
     */
    public function getCpuFeatures(): array
    {
        if (self::$isEmulated || self::$ffi === null) {
            $cpuinfo = @file_get_contents('/proc/cpuinfo') ?: '';
            return [
                'avx'    => str_contains($cpuinfo, 'avx'),
                'avx2'   => str_contains($cpuinfo, 'avx2'),
                'avx512' => str_contains($cpuinfo, 'avx512'),
                'fma'    => str_contains($cpuinfo, 'fma'),
            ];
        }

        $flags = self::$ffi->unum_cpu_features();
        return [
            'avx'    => ($flags & 1) !== 0,
            'avx2'   => ($flags & 2) !== 0,
            'avx512' => ($flags & 4) !== 0,
            'fma'    => ($flags & 8) !== 0,
        ];
    }
}
