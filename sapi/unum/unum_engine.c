/**
 * 👑 UNUM Universal Number Bare-Metal Compiler Engine
 * Implementation of 64-bit universal number encoding, decoding,
 * executable memory page management, and single-pass x86_64 JIT machine code emitter.
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <cpuid.h>
#include <math.h>
#include "unum_engine.h"

/* ------------------------------------------------------------------------ */
/* Bitfield Packing & Decoding Implementation                              */
/* ------------------------------------------------------------------------ */

unum_t unum_encode(uint8_t op, uint8_t type, uint8_t reg_dest, uint8_t reg_src, uint8_t simd, uint32_t payload)
{
    /* Pack reg_dest (4 bits) and reg_src (4 bits) into 8 bits */
    uint8_t reg_packed = (uint8_t)(((reg_dest & 0x0F) << 4) | (reg_src & 0x0F));

    return (((unum_t)(op & UNUM_MASK_BYTE)) << UNUM_SHIFT_OPCODE) |
           (((unum_t)(type & UNUM_MASK_BYTE)) << UNUM_SHIFT_TYPE) |
           (((unum_t)(reg_packed & UNUM_MASK_BYTE)) << UNUM_SHIFT_REG) |
           (((unum_t)(simd & UNUM_MASK_BYTE)) << UNUM_SHIFT_SIMD) |
           ((unum_t)(payload & UNUM_MASK_PAYLOAD));
}

void unum_decode(unum_t num, uint8_t *op, uint8_t *type, uint8_t *reg_dest, uint8_t *reg_src, uint8_t *simd, uint32_t *payload)
{
    if (op)       *op       = (uint8_t)((num >> UNUM_SHIFT_OPCODE) & UNUM_MASK_BYTE);
    if (type)     *type     = (uint8_t)((num >> UNUM_SHIFT_TYPE) & UNUM_MASK_BYTE);
    
    uint8_t reg_packed      = (uint8_t)((num >> UNUM_SHIFT_REG) & UNUM_MASK_BYTE);
    if (reg_dest) *reg_dest = (uint8_t)((reg_packed >> 4) & 0x0F);
    if (reg_src)  *reg_src  = (uint8_t)(reg_packed & 0x0F);

    if (simd)     *simd     = (uint8_t)((num >> UNUM_SHIFT_SIMD) & UNUM_MASK_BYTE);
    if (payload)  *payload  = (uint32_t)(num & UNUM_MASK_PAYLOAD);
}

/* ------------------------------------------------------------------------ */
/* Executable Memory Page Allocator (POSIX mmap)                            */
/* ------------------------------------------------------------------------ */

void* unum_alloc_executable_page(size_t size)
{
    size_t page_size = (size_t)sysconf(_SC_PAGESIZE);
    if (page_size == 0) page_size = 4096;

    size_t alloc_size = (size + page_size - 1) & ~(page_size - 1);
    if (alloc_size == 0) alloc_size = page_size;

    void *ptr = mmap(NULL, alloc_size,
                     PROT_READ | PROT_WRITE | PROT_EXEC,
                     MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);

    if (ptr == MAP_FAILED) {
        return NULL;
    }

    return ptr;
}

int unum_free_executable_page(void *addr, size_t size)
{
    if (!addr) return 0;

    size_t page_size = (size_t)sysconf(_SC_PAGESIZE);
    if (page_size == 0) page_size = 4096;

    size_t alloc_size = (size + page_size - 1) & ~(page_size - 1);
    if (alloc_size == 0) alloc_size = page_size;

    return munmap(addr, alloc_size);
}

/* ------------------------------------------------------------------------ */
/* Single-Pass x86_64 Machine Code Emitter                                 */
/* ------------------------------------------------------------------------ */

/* Helper to compute x86_64 REX prefix byte */
static inline uint8_t make_rex(int is_64bit, int reg, int rm)
{
    uint8_t rex = 0x40;
    if (is_64bit)   rex |= 0x08; /* REX.W */
    if (reg >= 8)   rex |= 0x04; /* REX.R */
    if (rm >= 8)    rex |= 0x01; /* REX.B */
    return (rex == 0x40 && !is_64bit) ? 0 : rex;
}

/* Helper to compute ModR/M byte for register-to-register operation */
static inline uint8_t make_modrm_reg(int reg, int rm)
{
    return (uint8_t)(0xC0 | ((reg & 7) << 3) | (rm & 7));
}

int unum_emit_machine_code(const unum_t *numbers, size_t count, uint8_t *code_buffer, size_t max_size, size_t *emitted_size)
{
    if (!numbers || !code_buffer || max_size < 64) {
        return -1;
    }

    size_t offset = 0;

    /*
     * 1. System V AMD64 ABI Function Prologue:
     * Preserve base pointer and callee-saved registers (RBX, R12-R15)
     */
    code_buffer[offset++] = 0x55;                         /* push rbp */
    code_buffer[offset++] = 0x48;
    code_buffer[offset++] = 0x89;
    code_buffer[offset++] = 0xE5;                         /* mov rbp, rsp */
    code_buffer[offset++] = 0x53;                         /* push rbx */
    code_buffer[offset++] = 0x41; code_buffer[offset++] = 0x54; /* push r12 */
    code_buffer[offset++] = 0x41; code_buffer[offset++] = 0x55; /* push r13 */
    code_buffer[offset++] = 0x41; code_buffer[offset++] = 0x56; /* push r14 */
    code_buffer[offset++] = 0x41; code_buffer[offset++] = 0x57; /* push r15 */

    /* Track loop start offset for hardware loop jumps */
    size_t loop_start_offset = offset;

    /*
     * 2. Translate Universal Numbers directly into Machine Instructions
     */
    for (size_t i = 0; i < count; i++) {
        uint8_t op, type, r_dest, r_src, simd;
        uint32_t payload;
        unum_decode(numbers[i], &op, &type, &r_dest, &r_src, &simd, &payload);

        /* Ensure buffer bounds */
        if (offset + 16 >= max_size) {
            return -2; /* Buffer overflow */
        }

        switch (op) {
            case UNUM_OP_NOP:
                code_buffer[offset++] = 0x90; /* nop */
                break;

            case UNUM_OP_MOV_IMM: {
                /* mov r_dest, imm32 (sign-extended to 64-bit) */
                uint8_t rex = make_rex(1, 0, r_dest);
                code_buffer[offset++] = rex;
                code_buffer[offset++] = 0xC7;
                code_buffer[offset++] = (uint8_t)(0xC0 | (r_dest & 7));
                code_buffer[offset++] = (uint8_t)(payload & 0xFF);
                code_buffer[offset++] = (uint8_t)((payload >> 8) & 0xFF);
                code_buffer[offset++] = (uint8_t)((payload >> 16) & 0xFF);
                code_buffer[offset++] = (uint8_t)((payload >> 24) & 0xFF);
                break;
            }

            case UNUM_OP_MOV_REG: {
                /* mov r_dest, r_src */
                uint8_t rex = make_rex(1, r_src, r_dest);
                code_buffer[offset++] = rex;
                code_buffer[offset++] = 0x89;
                code_buffer[offset++] = make_modrm_reg(r_src, r_dest);
                break;
            }

            case UNUM_OP_ADD_IMM: {
                /* add r_dest, imm32 */
                uint8_t rex = make_rex(1, 0, r_dest);
                code_buffer[offset++] = rex;
                code_buffer[offset++] = 0x81;
                code_buffer[offset++] = (uint8_t)(0xC0 | (r_dest & 7));
                code_buffer[offset++] = (uint8_t)(payload & 0xFF);
                code_buffer[offset++] = (uint8_t)((payload >> 8) & 0xFF);
                code_buffer[offset++] = (uint8_t)((payload >> 16) & 0xFF);
                code_buffer[offset++] = (uint8_t)((payload >> 24) & 0xFF);
                break;
            }

            case UNUM_OP_ADD_REG: {
                /* add r_dest, r_src */
                uint8_t rex = make_rex(1, r_src, r_dest);
                code_buffer[offset++] = rex;
                code_buffer[offset++] = 0x01;
                code_buffer[offset++] = make_modrm_reg(r_src, r_dest);
                break;
            }

            case UNUM_OP_SUB_IMM: {
                /* sub r_dest, imm32 */
                uint8_t rex = make_rex(1, 5, r_dest);
                code_buffer[offset++] = rex;
                code_buffer[offset++] = 0x81;
                code_buffer[offset++] = (uint8_t)(0xE8 | (r_dest & 7));
                code_buffer[offset++] = (uint8_t)(payload & 0xFF);
                code_buffer[offset++] = (uint8_t)((payload >> 8) & 0xFF);
                code_buffer[offset++] = (uint8_t)((payload >> 16) & 0xFF);
                code_buffer[offset++] = (uint8_t)((payload >> 24) & 0xFF);
                break;
            }

            case UNUM_OP_SUB_REG: {
                /* sub r_dest, r_src */
                uint8_t rex = make_rex(1, r_src, r_dest);
                code_buffer[offset++] = rex;
                code_buffer[offset++] = 0x29;
                code_buffer[offset++] = make_modrm_reg(r_src, r_dest);
                break;
            }

            case UNUM_OP_MUL_REG: {
                /* imul r_dest, r_src */
                uint8_t rex = make_rex(1, r_dest, r_src);
                code_buffer[offset++] = rex;
                code_buffer[offset++] = 0x0F;
                code_buffer[offset++] = 0xAF;
                code_buffer[offset++] = make_modrm_reg(r_dest, r_src);
                break;
            }

            case UNUM_OP_XOR_REG: {
                /* xor r_dest, r_src */
                uint8_t rex = make_rex(1, r_src, r_dest);
                code_buffer[offset++] = rex;
                code_buffer[offset++] = 0x31;
                code_buffer[offset++] = make_modrm_reg(r_src, r_dest);
                break;
            }

            case UNUM_OP_LOOP_START:
                /* Mark the beginning of the repeated loop body */
                loop_start_offset = offset;
                break;

            case UNUM_OP_LOOP_DEC: {
                /*
                 * Hardware Loop:
                 * dec r_dest (counter)
                 * jnz relative_back
                 */
                uint8_t rex = make_rex(1, 0, r_dest);
                code_buffer[offset++] = rex;
                code_buffer[offset++] = 0xFF;
                code_buffer[offset++] = (uint8_t)(0xC8 | (r_dest & 7)); /* dec r_dest */

                /* Compute backward jump offset */
                int32_t rel_jump = (int32_t)loop_start_offset - (int32_t)(offset + 2);
                if (rel_jump >= -128 && rel_jump <= 127) {
                    code_buffer[offset++] = 0x75; /* jnz rel8 */
                    code_buffer[offset++] = (uint8_t)(rel_jump & 0xFF);
                } else {
                    rel_jump = (int32_t)loop_start_offset - (int32_t)(offset + 6);
                    code_buffer[offset++] = 0x0F;
                    code_buffer[offset++] = 0x85; /* jnz rel32 */
                    code_buffer[offset++] = (uint8_t)(rel_jump & 0xFF);
                    code_buffer[offset++] = (uint8_t)((rel_jump >> 8) & 0xFF);
                    code_buffer[offset++] = (uint8_t)((rel_jump >> 16) & 0xFF);
                    code_buffer[offset++] = (uint8_t)((rel_jump >> 24) & 0xFF);
                }
                break;
            }

            case UNUM_OP_RET:
            case UNUM_OP_HALT:
                goto emit_epilogue;

            default:
                break;
        }
    }

emit_epilogue:
    /*
     * 3. System V AMD64 ABI Function Epilogue:
     * Restore callee-saved registers and return RAX
     */
    code_buffer[offset++] = 0x41; code_buffer[offset++] = 0x5F; /* pop r15 */
    code_buffer[offset++] = 0x41; code_buffer[offset++] = 0x5E; /* pop r14 */
    code_buffer[offset++] = 0x41; code_buffer[offset++] = 0x5D; /* pop r13 */
    code_buffer[offset++] = 0x41; code_buffer[offset++] = 0x5C; /* pop r12 */
    code_buffer[offset++] = 0x5B;                               /* pop rbx */
    code_buffer[offset++] = 0x5D;                               /* pop rbp */
    code_buffer[offset++] = 0xC3;                               /* ret */

    if (emitted_size) {
        *emitted_size = offset;
    }

    return 0;
}

/* ------------------------------------------------------------------------ */
/* Direct Hardware Execution Gateway                                        */
/* ------------------------------------------------------------------------ */

int64_t unum_execute(const void *code_page, int64_t arg1, int64_t arg2, int64_t arg3)
{
    if (!code_page) return -1;

    typedef int64_t (*unum_fn_t)(int64_t, int64_t, int64_t);
    unum_fn_t fn = (unum_fn_t)code_page;

    /* Direct jump to hardware CPU instructions */
    return fn(arg1, arg2, arg3);
}

/* ------------------------------------------------------------------------ */
/* Hardware AVX-512 & AVX2 SIMD Vector Acceleration                        */
/* ------------------------------------------------------------------------ */

#if defined(__x86_64__) || defined(_M_X64)
#include <immintrin.h>

__attribute__((target("avx512f,avx512dq,fma")))
static float unum_simd_dot_avx512(const float *a, const float *b, size_t dim)
{
    __m512 sum512 = _mm512_setzero_ps();
    size_t i = 0;
    for (; i + 16 <= dim; i += 16) {
        __m512 va = _mm512_loadu_ps(&a[i]);
        __m512 vb = _mm512_loadu_ps(&b[i]);
        sum512 = _mm512_fmadd_ps(va, vb, sum512);
    }
    float total = _mm512_reduce_add_ps(sum512);
    for (; i < dim; i++) {
        total += a[i] * b[i];
    }
    return total;
}

__attribute__((target("avx2,fma")))
static float unum_simd_dot_avx2(const float *a, const float *b, size_t dim)
{
    __m256 sum256 = _mm256_setzero_ps();
    size_t i = 0;
    for (; i + 8 <= dim; i += 8) {
        __m256 va = _mm256_loadu_ps(&a[i]);
        __m256 vb = _mm256_loadu_ps(&b[i]);
        sum256 = _mm256_fmadd_ps(va, vb, sum256);
    }
    __m128 lo = _mm256_castps256_ps128(sum256);
    __m128 hi = _mm256_extractf128_ps(sum256, 1);
    __m128 sum128 = _mm_add_ps(lo, hi);
    sum128 = _mm_hadd_ps(sum128, sum128);
    sum128 = _mm_hadd_ps(sum128, sum128);
    float total = _mm_cvtss_f32(sum128);
    for (; i < dim; i++) {
        total += a[i] * b[i];
    }
    return total;
}

__attribute__((target("avx512f,fma")))
static void unum_tensor_matmul_avx512(const float *A, const float *B, float *C, size_t M, size_t K, size_t N)
{
    /* WHY: Zero-initialize destination buffer before accumulating dot products */
    memset(C, 0, M * N * sizeof(float));
    /* WHY: IKJ loop ordering guarantees contiguous memory access across cache lines */
    for (size_t i = 0; i < M; i++) {
        for (size_t p = 0; p < K; p++) {
            float a_ip = A[i * K + p];
            __m512 va = _mm512_set1_ps(a_ip);
            size_t j = 0;
            for (; j + 16 <= N; j += 16) {
                __m512 vb = _mm512_loadu_ps(&B[p * N + j]);
                __m512 vc = _mm512_loadu_ps(&C[i * N + j]);
                vc = _mm512_fmadd_ps(va, vb, vc);
                _mm512_storeu_ps(&C[i * N + j], vc);
            }
            for (; j < N; j++) {
                C[i * N + j] += a_ip * B[p * N + j];
            }
        }
    }
}

__attribute__((target("avx2,fma")))
static void unum_tensor_matmul_avx2(const float *A, const float *B, float *C, size_t M, size_t K, size_t N)
{
    /* WHY: Zero-initialize destination buffer before accumulating dot products */
    memset(C, 0, M * N * sizeof(float));
    /* WHY: IKJ loop ordering avoids strided cache thrashing in L1/L2 caches */
    for (size_t i = 0; i < M; i++) {
        for (size_t p = 0; p < K; p++) {
            float a_ip = A[i * K + p];
            __m256 va = _mm256_set1_ps(a_ip);
            size_t j = 0;
            for (; j + 8 <= N; j += 8) {
                __m256 vb = _mm256_loadu_ps(&B[p * N + j]);
                __m256 vc = _mm256_loadu_ps(&C[i * N + j]);
                vc = _mm256_fmadd_ps(va, vb, vc);
                _mm256_storeu_ps(&C[i * N + j], vc);
            }
            for (; j < N; j++) {
                C[i * N + j] += a_ip * B[p * N + j];
            }
        }
    }
}

__attribute__((target("avx2")))
static void unum_relu_avx2(float *data, size_t size)
{
    __m256 zero = _mm256_setzero_ps();
    size_t i = 0;
    for (; i + 8 <= size; i += 8) {
        __m256 v = _mm256_loadu_ps(&data[i]);
        v = _mm256_max_ps(v, zero);
        _mm256_storeu_ps(&data[i], v);
    }
    for (; i < size; i++) {
        if (data[i] < 0.0f) data[i] = 0.0f;
    }
}

__attribute__((target("avx2,fma")))
static float unum_cosine_avx2(const float *a, const float *b, size_t dim)
{
    __m256 sum_dot = _mm256_setzero_ps();
    __m256 sum_a2  = _mm256_setzero_ps();
    __m256 sum_b2  = _mm256_setzero_ps();

    size_t i = 0;
    for (; i + 8 <= dim; i += 8) {
        __m256 va = _mm256_loadu_ps(&a[i]);
        __m256 vb = _mm256_loadu_ps(&b[i]);
        sum_dot = _mm256_fmadd_ps(va, vb, sum_dot);
        sum_a2  = _mm256_fmadd_ps(va, va, sum_a2);
        sum_b2  = _mm256_fmadd_ps(vb, vb, sum_b2);
    }

    __m128 lo_d = _mm256_castps256_ps128(sum_dot);
    __m128 hi_d = _mm256_extractf128_ps(sum_dot, 1);
    __m128 s_d = _mm_add_ps(lo_d, hi_d);
    s_d = _mm_hadd_ps(s_d, s_d);
    s_d = _mm_hadd_ps(s_d, s_d);
    float dot = _mm_cvtss_f32(s_d);

    __m128 lo_a = _mm256_castps256_ps128(sum_a2);
    __m128 hi_a = _mm256_extractf128_ps(sum_a2, 1);
    __m128 s_a = _mm_add_ps(lo_a, hi_a);
    s_a = _mm_hadd_ps(s_a, s_a);
    s_a = _mm_hadd_ps(s_a, s_a);
    float norm_a = _mm_cvtss_f32(s_a);

    __m128 lo_b = _mm256_castps256_ps128(sum_b2);
    __m128 hi_b = _mm256_extractf128_ps(sum_b2, 1);
    __m128 s_b = _mm_add_ps(lo_b, hi_b);
    s_b = _mm_hadd_ps(s_b, s_b);
    s_b = _mm_hadd_ps(s_b, s_b);
    float norm_b = _mm_cvtss_f32(s_b);

    for (; i < dim; i++) {
        dot += a[i] * b[i];
        norm_a += a[i] * a[i];
        norm_b += b[i] * b[i];
    }

    float denom = sqrtf(norm_a) * sqrtf(norm_b);
    if (denom <= 1e-12f) return 0.0f;
    return dot / denom;
}
#endif

float unum_simd_dot_f32(const float *a, const float *b, size_t dim)
{
#if defined(__x86_64__) || defined(_M_X64)
    if (__builtin_cpu_supports("avx512f") && __builtin_cpu_supports("fma")) {
        return unum_simd_dot_avx512(a, b, dim);
    }
    if (__builtin_cpu_supports("avx2") && __builtin_cpu_supports("fma")) {
        return unum_simd_dot_avx2(a, b, dim);
    }
#endif
    /* Fallback scalar dot product */
    float sum = 0.0f;
    for (size_t i = 0; i < dim; i++) {
        sum += a[i] * b[i];
    }
    return sum;
}

float unum_simd_dot_batch(const float *a, const float *b, size_t dim, size_t count)
{
    float total = 0.0f;
    for (size_t i = 0; i < count; i++) {
        total += unum_simd_dot_f32(a, b, dim);
    }
    return total;
}

void unum_tensor_matmul_f32(const float *A, const float *B, float *C, size_t M, size_t K, size_t N)
{
    if (!A || !B || !C || M == 0 || K == 0 || N == 0) return;

#if defined(__x86_64__) || defined(_M_X64)
    if (__builtin_cpu_supports("avx512f") && __builtin_cpu_supports("fma")) {
        unum_tensor_matmul_avx512(A, B, C, M, K, N);
        return;
    }
    if (__builtin_cpu_supports("avx2") && __builtin_cpu_supports("fma")) {
        unum_tensor_matmul_avx2(A, B, C, M, K, N);
        return;
    }
#endif

    /* Portable fallback scalar matmul with IKJ ordering */
    memset(C, 0, M * N * sizeof(float));
    for (size_t i = 0; i < M; i++) {
        for (size_t p = 0; p < K; p++) {
            float a_ip = A[i * K + p];
            for (size_t j = 0; j < N; j++) {
                C[i * N + j] += a_ip * B[p * N + j];
            }
        }
    }
}

void unum_tensor_activate_f32(float *data, size_t size, int activation_type)
{
    if (!data || size == 0) return;

    switch (activation_type) {
        case 0: /* ReLU */
#if defined(__x86_64__) || defined(_M_X64)
            if (__builtin_cpu_supports("avx2")) {
                unum_relu_avx2(data, size);
                return;
            }
#endif
            for (size_t i = 0; i < size; i++) {
                if (data[i] < 0.0f) data[i] = 0.0f;
            }
            break;

        case 1: { /* GELU: 0.5 * x * (1 + tanh(sqrt(2/pi) * (x + 0.044715 * x^3))) */
            const float sqrt_2_over_pi = 0.7978845608028654f;
            const float coeff = 0.044715f;
            for (size_t i = 0; i < size; i++) {
                float x = data[i];
                float cube = x * x * x;
                float inner = sqrt_2_over_pi * (x + coeff * cube);
                data[i] = 0.5f * x * (1.0f + tanhf(inner));
            }
            break;
        }

        case 2: { /* Softmax: exp(x_i - max) / sum(exp(x_j - max)) */
            float max_val = data[0];
            for (size_t i = 1; i < size; i++) {
                if (data[i] > max_val) max_val = data[i];
            }

            float sum_exp = 0.0f;
            for (size_t i = 0; i < size; i++) {
                data[i] = expf(data[i] - max_val);
                sum_exp += data[i];
            }

            if (sum_exp > 0.0f) {
                float inv_sum = 1.0f / sum_exp;
                for (size_t i = 0; i < size; i++) {
                    data[i] *= inv_sum;
                }
            }
            break;
        }

        default:
            break;
    }
}

float unum_tensor_cosine_similarity(const float *a, const float *b, size_t dim)
{
    if (!a || !b || dim == 0) return 0.0f;

#if defined(__x86_64__) || defined(_M_X64)
    if (__builtin_cpu_supports("avx2") && __builtin_cpu_supports("fma")) {
        return unum_cosine_avx2(a, b, dim);
    }
#endif

    float dot = 0.0f;
    float norm_a = 0.0f;
    float norm_b = 0.0f;
    for (size_t i = 0; i < dim; i++) {
        dot += a[i] * b[i];
        norm_a += a[i] * a[i];
        norm_b += b[i] * b[i];
    }

    float denom = sqrtf(norm_a) * sqrtf(norm_b);
    if (denom <= 1e-12f) return 0.0f;
    return dot / denom;
}

uint32_t unum_cpu_features(void)
{
    uint32_t flags = 0;
#if defined(__x86_64__) || defined(_M_X64)
    if (__builtin_cpu_supports("avx"))     flags |= 1;
    if (__builtin_cpu_supports("avx2"))    flags |= 2;
    if (__builtin_cpu_supports("avx512f")) flags |= 4;
    if (__builtin_cpu_supports("fma"))     flags |= 8;
#endif
    return flags;
}

/* ------------------------------------------------------------------------ */
/* Transformer RMSNorm & RoPE Kernels                                       */
/* ------------------------------------------------------------------------ */

void unum_tensor_rmsnorm_f32(const float *x, const float *weight, float *out, size_t dim, float eps)
{
    if (!x || !out || dim == 0) return;

    /* WHY: Compute sum of squares sum(x_i^2) across the vector */
    float sum_sq = 0.0f;
#if defined(__x86_64__) || defined(_M_X64)
    if (__builtin_cpu_supports("avx2") && __builtin_cpu_supports("fma")) {
        __m256 vsum = _mm256_setzero_ps();
        size_t i = 0;
        for (; i + 8 <= dim; i += 8) {
            __m256 vx = _mm256_loadu_ps(&x[i]);
            vsum = _mm256_fmadd_ps(vx, vx, vsum);
        }
        __m128 lo = _mm256_castps256_ps128(vsum);
        __m128 hi = _mm256_extractf128_ps(vsum, 1);
        __m128 s = _mm_add_ps(lo, hi);
        s = _mm_hadd_ps(s, s);
        s = _mm_hadd_ps(s, s);
        sum_sq = _mm_cvtss_f32(s);
        for (; i < dim; i++) {
            sum_sq += x[i] * x[i];
        }
    } else {
        for (size_t i = 0; i < dim; i++) sum_sq += x[i] * x[i];
    }
#else
    for (size_t i = 0; i < dim; i++) sum_sq += x[i] * x[i];
#endif

    float rms = sqrtf((sum_sq / (float)dim) + eps);
    float inv_rms = 1.0f / rms;

#if defined(__x86_64__) || defined(_M_X64)
    if (__builtin_cpu_supports("avx2")) {
        __m256 vinv = _mm256_set1_ps(inv_rms);
        size_t i = 0;
        for (; i + 8 <= dim; i += 8) {
            __m256 vx = _mm256_loadu_ps(&x[i]);
            __m256 vnorm = _mm256_mul_ps(vx, vinv);
            if (weight) {
                __m256 vw = _mm256_loadu_ps(&weight[i]);
                vnorm = _mm256_mul_ps(vnorm, vw);
            }
            _mm256_storeu_ps(&out[i], vnorm);
        }
        for (; i < dim; i++) {
            out[i] = (x[i] * inv_rms) * (weight ? weight[i] : 1.0f);
        }
        return;
    }
#endif

    for (size_t i = 0; i < dim; i++) {
        out[i] = (x[i] * inv_rms) * (weight ? weight[i] : 1.0f);
    }
}

void unum_tensor_rope_f32(float *q, float *k, size_t seq_len, size_t num_heads, size_t head_dim, size_t pos_offset)
{
    if (!q || seq_len == 0 || num_heads == 0 || head_dim < 2) return;

    size_t half_dim = head_dim / 2;

    for (size_t pos = 0; pos < seq_len; pos++) {
        float p = (float)(pos + pos_offset);
        for (size_t h = 0; h < num_heads; h++) {
            size_t head_offset = (pos * num_heads + h) * head_dim;
            float *q_head = &q[head_offset];
            float *k_head = k ? &k[head_offset] : NULL;

            for (size_t j = 0; j < half_dim; j++) {
                float freq = 1.0f / powf(10000.0f, (float)(2 * j) / (float)head_dim);
                float theta = p * freq;
                float cos_theta = cosf(theta);
                float sin_theta = sinf(theta);

                size_t idx0 = j * 2;
                size_t idx1 = j * 2 + 1;

                float q0 = q_head[idx0];
                float q1 = q_head[idx1];
                q_head[idx0] = q0 * cos_theta - q1 * sin_theta;
                q_head[idx1] = q0 * sin_theta + q1 * cos_theta;

                if (k_head) {
                    float k0 = k_head[idx0];
                    float k1 = k_head[idx1];
                    k_head[idx0] = k0 * cos_theta - k1 * sin_theta;
                    k_head[idx1] = k0 * sin_theta + k1 * cos_theta;
                }
            }
        }
    }
}

void unum_tensor_mha_f32(const float *Q, const float *K, const float *V, float *out, size_t seq_len, size_t num_heads, size_t head_dim)
{
    if (!Q || !K || !V || !out || seq_len == 0 || num_heads == 0 || head_dim == 0) return;

    float scale = 1.0f / sqrtf((float)head_dim);

    /* Allocate temporary attention score matrix S: seq_len x seq_len */
    float *scores = (float*)malloc(seq_len * seq_len * sizeof(float));
    if (!scores) return;

    for (size_t h = 0; h < num_heads; h++) {
        /* Pass 1: S = (Q * K^T) * scale */
        for (size_t i = 0; i < seq_len; i++) {
            const float *qi = &Q[(i * num_heads + h) * head_dim];
            for (size_t j = 0; j < seq_len; j++) {
                const float *kj = &K[(j * num_heads + h) * head_dim];
                float dot = unum_simd_dot_f32(qi, kj, head_dim);
                scores[i * seq_len + j] = dot * scale;
            }
        }

        /* Pass 2: Row-wise Softmax on S */
        for (size_t i = 0; i < seq_len; i++) {
            float *row = &scores[i * seq_len];
            float max_s = row[0];
            for (size_t j = 1; j < seq_len; j++) {
                if (row[j] > max_s) max_s = row[j];
            }
            float sum_exp = 0.0f;
            for (size_t j = 0; j < seq_len; j++) {
                row[j] = expf(row[j] - max_s);
                sum_exp += row[j];
            }
            float inv_sum = sum_exp > 0.0f ? (1.0f / sum_exp) : 0.0f;
            for (size_t j = 0; j < seq_len; j++) {
                row[j] *= inv_sum;
            }
        }

        /* Pass 3: out = S * V */
        for (size_t i = 0; i < seq_len; i++) {
            float *out_head = &out[(i * num_heads + h) * head_dim];
            memset(out_head, 0, head_dim * sizeof(float));
            for (size_t j = 0; j < seq_len; j++) {
                float a_ij = scores[i * seq_len + j];
                const float *vj = &V[(j * num_heads + h) * head_dim];
                for (size_t d = 0; d < head_dim; d++) {
                    out_head[d] += a_ij * vj[d];
                }
            }
        }
    }

    free(scores);
}

/* ------------------------------------------------------------------------ */
/* POSIX Shared Memory & Hardware Atomics                                   */
/* ------------------------------------------------------------------------ */

int unum_shm_create(const char *name, size_t size, void **addr_out)
{
    if (!name || size == 0 || !addr_out) return -1;

    int fd = shm_open(name, O_CREAT | O_RDWR | O_TRUNC, 0666);
    if (fd < 0) return -2;

    if (ftruncate(fd, (off_t)size) < 0) {
        close(fd);
        shm_unlink(name);
        return -3;
    }

    void *addr = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    close(fd);

    if (addr == MAP_FAILED) {
        shm_unlink(name);
        return -4;
    }

    *addr_out = addr;
    return 0;
}

int unum_shm_open(const char *name, size_t size, void **addr_out)
{
    if (!name || size == 0 || !addr_out) return -1;

    int fd = shm_open(name, O_RDWR, 0666);
    if (fd < 0) return -2;

    void *addr = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    close(fd);

    if (addr == MAP_FAILED) return -3;

    *addr_out = addr;
    return 0;
}

int unum_shm_close(void *addr, size_t size)
{
    if (!addr || size == 0) return 0;
    return munmap(addr, size);
}

int unum_shm_unlink(const char *name)
{
    if (!name) return -1;
    return shm_unlink(name);
}

uint64_t unum_atomic_cas64(uint64_t *ptr, uint64_t old_val, uint64_t new_val)
{
    if (!ptr) return 0;
    return __sync_val_compare_and_swap(ptr, old_val, new_val);
}

uint64_t unum_atomic_fetch_add64(uint64_t *ptr, uint64_t val)
{
    if (!ptr) return 0;
    return __sync_fetch_and_add(ptr, val);
}

/* ------------------------------------------------------------------------ */
/* SIMD Columnar Filter & Aggregation Engine                                */
/* ------------------------------------------------------------------------ */

size_t unum_column_filter_gt_i64(const int64_t *col, size_t size, int64_t threshold, uint8_t *bitmap_out)
{
    if (!col || !bitmap_out || size == 0) return 0;

    size_t match_count = 0;
    size_t i = 0;

#if defined(__x86_64__) || defined(_M_X64)
    if (__builtin_cpu_supports("avx2")) {
        __m256i vthresh = _mm256_set1_epi64x(threshold);
        for (; i + 4 <= size; i += 4) {
            __m256i vdata = _mm256_loadu_si256((const __m256i*)&col[i]);
            __m256i vcmp = _mm256_cmpgt_epi64(vdata, vthresh);
            int64_t m0 = _mm256_extract_epi64(vcmp, 0);
            int64_t m1 = _mm256_extract_epi64(vcmp, 1);
            int64_t m2 = _mm256_extract_epi64(vcmp, 2);
            int64_t m3 = _mm256_extract_epi64(vcmp, 3);
            bitmap_out[i + 0] = m0 ? 1 : 0;
            bitmap_out[i + 1] = m1 ? 1 : 0;
            bitmap_out[i + 2] = m2 ? 1 : 0;
            bitmap_out[i + 3] = m3 ? 1 : 0;
            match_count += (bitmap_out[i] + bitmap_out[i+1] + bitmap_out[i+2] + bitmap_out[i+3]);
        }
    }
#endif

    for (; i < size; i++) {
        uint8_t match = (col[i] > threshold) ? 1 : 0;
        bitmap_out[i] = match;
        match_count += match;
    }

    return match_count;
}

int64_t unum_column_sum_i64(const int64_t *col, const uint8_t *bitmap, size_t size)
{
    if (!col || size == 0) return 0;

    int64_t total = 0;
    for (size_t i = 0; i < size; i++) {
        if (!bitmap || bitmap[i]) {
            total += col[i];
        }
    }
    return total;
}

size_t unum_column_filter_gt_f32(const float *col, size_t size, float threshold, uint8_t *bitmap_out)
{
    if (!col || !bitmap_out || size == 0) return 0;

    size_t match_count = 0;
    size_t i = 0;

#if defined(__x86_64__) || defined(_M_X64)
    if (__builtin_cpu_supports("avx")) {
        __m256 vthresh = _mm256_set1_ps(threshold);
        for (; i + 8 <= size; i += 8) {
            __m256 vdata = _mm256_loadu_ps(&col[i]);
            __m256 vcmp = _mm256_cmp_ps(vdata, vthresh, _CMP_GT_OQ);
            int mask = _mm256_movemask_ps(vcmp);
            for (int b = 0; b < 8; b++) {
                uint8_t m = (mask & (1 << b)) ? 1 : 0;
                bitmap_out[i + b] = m;
                match_count += m;
            }
        }
    }
#endif

    for (; i < size; i++) {
        uint8_t m = (col[i] > threshold) ? 1 : 0;
        bitmap_out[i] = m;
        match_count += m;
    }

    return match_count;
}

float unum_column_sum_f32(const float *col, const uint8_t *bitmap, size_t size)
{
    if (!col || size == 0) return 0.0f;

    float total = 0.0f;
    for (size_t i = 0; i < size; i++) {
        if (!bitmap || bitmap[i]) {
            total += col[i];
        }
    }
    return total;
}

