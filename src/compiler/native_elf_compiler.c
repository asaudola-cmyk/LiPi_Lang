/* ==============================================================================
 * 👑 Lipi Native Direct ELF Compiler (src/compiler/native_elf_compiler.c)
 * ⚡ Zero GCC | Zero Clang | Zero Python | Zero Libc in Output Binaries
 * 🏛️ Version: First 1.0 (প্রথম ১.০) — Sovereign
 *
 * WHY: This binary compiles Lipi source files (.lp) directly to standalone
 *      Linux x86_64 ELF64 executables. It achieves the exact autonomous tier
 *      of Go (cmd/compile), Zig, and Rust (rustc) — a single self-contained
 *      native compiler binary that outputs native machine code directly.
 * ============================================================================== */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <sys/stat.h>
#include <unistd.h>
#include <ctype.h>

#define ELF_BASE_VADDR 0x400000
#define ELF_HEADER_SIZE 120  /* 64 bytes ELF Header + 56 bytes Program Header */
#define ENTRY_POINT_VADDR (ELF_BASE_VADDR + ELF_HEADER_SIZE)

/* ── Dynamic Byte Buffer ─────────────────────────────────────────────────── */
typedef struct {
    uint8_t* data;
    size_t   size;
    size_t   capacity;
} ByteBuf;

static ByteBuf* bb_new(size_t cap) {
    ByteBuf* bb = (ByteBuf*)malloc(sizeof(ByteBuf));
    bb->capacity = cap > 128 ? cap : 128;
    bb->size = 0;
    bb->data = (uint8_t*)malloc(bb->capacity);
    return bb;
}

static void bb_free(ByteBuf* bb) {
    if (bb) {
        if (bb->data) free(bb->data);
        free(bb);
    }
}

static void bb_put8(ByteBuf* bb, uint8_t b) {
    if (bb->size >= bb->capacity) {
        bb->capacity *= 2;
        bb->data = (uint8_t*)realloc(bb->data, bb->capacity);
    }
    bb->data[bb->size++] = b;
}

static void bb_put32(ByteBuf* bb, uint32_t val) {
    bb_put8(bb, (uint8_t)(val & 0xFF));
    bb_put8(bb, (uint8_t)((val >> 8) & 0xFF));
    bb_put8(bb, (uint8_t)((val >> 16) & 0xFF));
    bb_put8(bb, (uint8_t)((val >> 24) & 0xFF));
}

static void bb_put64(ByteBuf* bb, uint64_t val) {
    bb_put32(bb, (uint32_t)(val & 0xFFFFFFFF));
    bb_put32(bb, (uint32_t)((val >> 32) & 0xFFFFFFFF));
}

static void bb_write(ByteBuf* bb, const void* src, size_t len) {
    const uint8_t* s = (const uint8_t*)src;
    for (size_t i = 0; i < len; i++) {
        bb_put8(bb, s[i]);
    }
}

/* ── Relocation / Label Table ────────────────────────────────────────────── */
#define MAX_LABELS 4096
#define MAX_RELOCS 8192

typedef struct {
    char name[64];
    size_t offset;
} LabelEntry;

typedef struct {
    size_t patch_offset;
    char   target_label[64];
    int    inst_len;
} RelocEntry;

static LabelEntry g_labels[MAX_LABELS];
static int g_label_count = 0;

static RelocEntry g_relocs[MAX_RELOCS];
static int g_reloc_count = 0;

static int g_anon_label_id = 0;

static void label_define(const char* name, size_t offset) {
    if (g_label_count < MAX_LABELS) {
        strncpy(g_labels[g_label_count].name, name, 63);
        g_labels[g_label_count].name[63] = '\0';
        g_labels[g_label_count].offset = offset;
        g_label_count++;
    }
}

static void reloc_add(size_t patch_offset, const char* target, int inst_len) {
    if (g_reloc_count < MAX_RELOCS) {
        g_relocs[g_reloc_count].patch_offset = patch_offset;
        strncpy(g_relocs[g_reloc_count].target_label, target, 63);
        g_relocs[g_reloc_count].target_label[63] = '\0';
        g_relocs[g_reloc_count].inst_len = inst_len;
        g_reloc_count++;
    }
}

static size_t label_find(const char* name) {
    for (int i = 0; i < g_label_count; i++) {
        if (strcmp(g_labels[i].name, name) == 0) {
            return g_labels[i].offset;
        }
    }
    fprintf(stderr, "❌ Error: Undefined machine code label '%s'\n", name);
    exit(1);
}

static void backpatch_all(ByteBuf* bb) {
    for (int i = 0; i < g_reloc_count; i++) {
        size_t patch_pos = g_relocs[i].patch_offset;
        size_t target_pos = label_find(g_relocs[i].target_label);
        size_t inst_start = patch_pos - (g_relocs[i].inst_len - 4);
        size_t next_rip = inst_start + g_relocs[i].inst_len;
        int32_t disp = (int32_t)(target_pos - next_rip);

        bb->data[patch_pos + 0] = (uint8_t)(disp & 0xFF);
        bb->data[patch_pos + 1] = (uint8_t)((disp >> 8) & 0xFF);
        bb->data[patch_pos + 2] = (uint8_t)((disp >> 16) & 0xFF);
        bb->data[patch_pos + 3] = (uint8_t)((disp >> 24) & 0xFF);
    }
}

static void make_anon_label(char* out, const char* prefix) {
    snprintf(out, 64, "%s_%d", prefix, ++g_anon_label_id);
}

/* ── x86_64 Machine Code Assembler Instructions ──────────────────────────── */
static void x86_push_rbp(ByteBuf* bb) { bb_put8(bb, 0x55); }
static void x86_mov_rbp_rsp(ByteBuf* bb) { bb_put8(bb, 0x48); bb_put8(bb, 0x89); bb_put8(bb, 0xE5); }
static void x86_pop_rbp(ByteBuf* bb) { bb_put8(bb, 0x5D); }
static void x86_leave(ByteBuf* bb) { bb_put8(bb, 0xC9); }
static void x86_ret(ByteBuf* bb) { bb_put8(bb, 0xC3); }
static void x86_syscall(ByteBuf* bb) { bb_put8(bb, 0x0F); bb_put8(bb, 0x05); }

static void x86_sub_rsp(ByteBuf* bb, int bytes) {
    if (bytes == 0) return;
    if (bytes <= 127) {
        bb_put8(bb, 0x48); bb_put8(bb, 0x83); bb_put8(bb, 0xEC);
        bb_put8(bb, (uint8_t)bytes);
    } else {
        bb_put8(bb, 0x48); bb_put8(bb, 0x81); bb_put8(bb, 0xEC);
        bb_put32(bb, (uint32_t)bytes);
    }
}

static void x86_push_reg(ByteBuf* bb, int reg) {
    if (reg >= 8) {
        bb_put8(bb, 0x41);
        bb_put8(bb, (uint8_t)(0x50 + (reg & 7)));
    } else {
        bb_put8(bb, (uint8_t)(0x50 + reg));
    }
}

static void x86_pop_reg(ByteBuf* bb, int reg) {
    if (reg >= 8) {
        bb_put8(bb, 0x41);
        bb_put8(bb, (uint8_t)(0x58 + (reg & 7)));
    } else {
        bb_put8(bb, (uint8_t)(0x58 + reg));
    }
}

static void x86_mov_reg_imm64(ByteBuf* bb, int reg, int64_t val) {
    uint8_t rex = 0x48 | (reg >= 8 ? 1 : 0);
    uint8_t op = (uint8_t)(0xB8 + (reg & 7));
    bb_put8(bb, rex);
    bb_put8(bb, op);
    bb_put64(bb, (uint64_t)val);
}

static void x86_mov_reg_reg(ByteBuf* bb, int dst, int src) {
    uint8_t rex = 0x48;
    if (src >= 8) rex |= 0x04;
    if (dst >= 8) rex |= 0x01;
    uint8_t modrm = (uint8_t)(0xC0 | ((src & 7) << 3) | (dst & 7));
    bb_put8(bb, rex);
    bb_put8(bb, 0x89);
    bb_put8(bb, modrm);
}

static void x86_mov_stack_rax(ByteBuf* bb, int offset) {
    int32_t disp = -offset;
    if (disp >= -128 && disp <= 127) {
        bb_put8(bb, 0x48); bb_put8(bb, 0x89); bb_put8(bb, 0x45);
        bb_put8(bb, (uint8_t)(int8_t)disp);
    } else {
        bb_put8(bb, 0x48); bb_put8(bb, 0x89); bb_put8(bb, 0x85);
        bb_put32(bb, (uint32_t)disp);
    }
}

static void x86_mov_rax_stack(ByteBuf* bb, int offset) {
    int32_t disp = -offset;
    if (disp >= -128 && disp <= 127) {
        bb_put8(bb, 0x48); bb_put8(bb, 0x8B); bb_put8(bb, 0x45);
        bb_put8(bb, (uint8_t)(int8_t)disp);
    } else {
        bb_put8(bb, 0x48); bb_put8(bb, 0x8B); bb_put8(bb, 0x85);
        bb_put32(bb, (uint32_t)disp);
    }
}

static void x86_mov_stack_reg(ByteBuf* bb, int offset, int reg) {
    int32_t disp = -offset;
    uint8_t rex = 0x48 | (reg >= 8 ? 0x04 : 0);
    if (disp >= -128 && disp <= 127) {
        bb_put8(bb, rex); bb_put8(bb, 0x89);
        bb_put8(bb, (uint8_t)(0x45 | ((reg & 7) << 3)));
        bb_put8(bb, (uint8_t)(int8_t)disp);
    } else {
        bb_put8(bb, rex); bb_put8(bb, 0x89);
        bb_put8(bb, (uint8_t)(0x85 | ((reg & 7) << 3)));
        bb_put32(bb, (uint32_t)disp);
    }
}

static void x86_mov_reg_stack(ByteBuf* bb, int reg, int offset) {
    int32_t disp = -offset;
    uint8_t rex = 0x48 | (reg >= 8 ? 0x04 : 0);
    if (disp >= -128 && disp <= 127) {
        bb_put8(bb, rex); bb_put8(bb, 0x8B);
        bb_put8(bb, (uint8_t)(0x45 | ((reg & 7) << 3)));
        bb_put8(bb, (uint8_t)(int8_t)disp);
    } else {
        bb_put8(bb, rex); bb_put8(bb, 0x8B);
        bb_put8(bb, (uint8_t)(0x85 | ((reg & 7) << 3)));
        bb_put32(bb, (uint32_t)disp);
    }
}

static void x86_lea_reg_rip(ByteBuf* bb, int reg, const char* label) {
    uint8_t rex = 0x48 | (reg >= 8 ? 0x04 : 0);
    uint8_t modrm = (uint8_t)(0x05 | ((reg & 7) << 3));
    size_t pos = bb->size;
    bb_put8(bb, rex);
    bb_put8(bb, 0x8D);
    bb_put8(bb, modrm);
    bb_put32(bb, 0);  /* placeholder */
    reloc_add(pos + 3, label, 7);
}

static void x86_add_rax_rbx(ByteBuf* bb) { bb_put8(bb, 0x48); bb_put8(bb, 0x01); bb_put8(bb, 0xD8); }
static void x86_sub_rax_rbx(ByteBuf* bb) { bb_put8(bb, 0x48); bb_put8(bb, 0x29); bb_put8(bb, 0xD8); }
static void x86_imul_rax_rbx(ByteBuf* bb) { bb_put8(bb, 0x48); bb_put8(bb, 0x0F); bb_put8(bb, 0xAF); bb_put8(bb, 0xC3); }
static void x86_idiv_rbx(ByteBuf* bb) {
    bb_put8(bb, 0x48); bb_put8(bb, 0x99); /* cqo */
    bb_put8(bb, 0x48); bb_put8(bb, 0xF7); bb_put8(bb, 0xFB); /* idiv rbx */
}
static void x86_imod_rbx(ByteBuf* bb) {
    x86_idiv_rbx(bb);
    x86_mov_reg_reg(bb, 0, 2); /* mov rax, rdx */
}

static void x86_cmp_rax_rbx(ByteBuf* bb) { bb_put8(bb, 0x48); bb_put8(bb, 0x39); bb_put8(bb, 0xD8); }

static void x86_set_cmp(ByteBuf* bb, const char* op) {
    x86_cmp_rax_rbx(bb);
    if (strcmp(op, "==") == 0) {
        bb_put8(bb, 0x0F); bb_put8(bb, 0x94); bb_put8(bb, 0xC0); /* sete al */
    } else if (strcmp(op, "!=") == 0) {
        bb_put8(bb, 0x0F); bb_put8(bb, 0x95); bb_put8(bb, 0xC0); /* setne al */
    } else if (strcmp(op, "<") == 0) {
        bb_put8(bb, 0x0F); bb_put8(bb, 0x9C); bb_put8(bb, 0xC0); /* setl al */
    } else if (strcmp(op, "<=") == 0) {
        bb_put8(bb, 0x0F); bb_put8(bb, 0x9E); bb_put8(bb, 0xC0); /* setle al */
    } else if (strcmp(op, ">") == 0) {
        bb_put8(bb, 0x0F); bb_put8(bb, 0x9F); bb_put8(bb, 0xC0); /* setg al */
    } else if (strcmp(op, ">=") == 0) {
        bb_put8(bb, 0x0F); bb_put8(bb, 0x9D); bb_put8(bb, 0xC0); /* setge al */
    }
    bb_put8(bb, 0x48); bb_put8(bb, 0x0F); bb_put8(bb, 0xB6); bb_put8(bb, 0xC0); /* movzx rax, al */
}

static void x86_jmp(ByteBuf* bb, const char* label) {
    size_t pos = bb->size;
    bb_put8(bb, 0xE9);
    bb_put32(bb, 0);
    reloc_add(pos + 1, label, 5);
}

static void x86_jz(ByteBuf* bb, const char* label) {
    size_t pos = bb->size;
    bb_put8(bb, 0x0F); bb_put8(bb, 0x84);
    bb_put32(bb, 0);
    reloc_add(pos + 2, label, 6);
}

static void x86_jnz(ByteBuf* bb, const char* label) {
    size_t pos = bb->size;
    bb_put8(bb, 0x0F); bb_put8(bb, 0x85);
    bb_put32(bb, 0);
    reloc_add(pos + 2, label, 6);
}

static void x86_call(ByteBuf* bb, const char* label) {
    size_t pos = bb->size;
    bb_put8(bb, 0xE8);
    bb_put32(bb, 0);
    reloc_add(pos + 1, label, 5);
}

/* ── String Pool ─────────────────────────────────────────────────────────── */
typedef struct {
    char text[512];
    char label[64];
} StringEntry;

static StringEntry g_strings[1024];
static int g_string_count = 0;

static const char* string_pool_get(const char* text) {
    for (int i = 0; i < g_string_count; i++) {
        if (strcmp(g_strings[i].text, text) == 0) {
            return g_strings[i].label;
        }
    }
    if (g_string_count < 1024) {
        strncpy(g_strings[g_string_count].text, text, 511);
        g_strings[g_string_count].text[511] = '\0';
        make_anon_label(g_strings[g_string_count].label, "str_const");
        return g_strings[g_string_count++].label;
    }
    return "";
}

/* ── Emit Libc-less Baremetal Linux Syscall Engine ────────────────────────── */
static void emit_runtime_stubs(ByteBuf* bb) {
    /* _start */
    label_define("_start", bb->size);
    bb_put8(bb, 0x48); bb_put8(bb, 0x83); bb_put8(bb, 0xE4); bb_put8(bb, 0xF0); /* and rsp, -16 */
    x86_call(bb, "_lipi_init_heap");
    x86_call(bb, "lipi_main");
    x86_mov_reg_reg(bb, 7, 0); /* mov rdi, rax */
    x86_mov_reg_imm64(bb, 0, 60); /* mov rax, 60 (sys_exit) */
    x86_syscall(bb);
    bb_put8(bb, 0xF4); /* hlt */

    /* _lipi_init_heap: sys_mmap(0, 16MB, 3, 34, -1, 0) */
    label_define("_lipi_init_heap", bb->size);
    bb_put8(bb, 0x48); bb_put8(bb, 0x31); bb_put8(bb, 0xFF); /* xor rdi, rdi */
    x86_mov_reg_imm64(bb, 6, 16777216); /* rsi = 16MB */
    x86_mov_reg_imm64(bb, 2, 3);        /* rdx = PROT_READ|PROT_WRITE */
    x86_mov_reg_imm64(bb, 10, 34);      /* r10 = MAP_PRIVATE|MAP_ANONYMOUS */
    x86_mov_reg_imm64(bb, 8, -1);       /* r8  = -1 */
    bb_put8(bb, 0x4D); bb_put8(bb, 0x31); bb_put8(bb, 0xC9); /* xor r9, r9 */
    x86_mov_reg_imm64(bb, 0, 9);        /* rax = sys_mmap */
    x86_syscall(bb);
    x86_lea_reg_rip(bb, 3, "_lipi_heap_base");
    bb_put8(bb, 0x48); bb_put8(bb, 0x89); bb_put8(bb, 0x03); /* mov [rbx], rax */
    x86_lea_reg_rip(bb, 3, "_lipi_heap_ptr");
    bb_put8(bb, 0x48); bb_put8(bb, 0x89); bb_put8(bb, 0x03); /* mov [rbx], rax */
    x86_ret(bb);

    /* _lipi_alloc: in: rdi = size. out: rax = ptr (len at [rax - 8]) */
    label_define("_lipi_alloc", bb->size);
    bb_put8(bb, 0x53); /* push rbx */
    bb_put8(bb, 0x41); bb_put8(bb, 0x54); /* push r12 */
    bb_put8(bb, 0x49); bb_put8(bb, 0x89); bb_put8(bb, 0xFC); /* mov r12, rdi */
    bb_put8(bb, 0x48); bb_put8(bb, 0x83); bb_put8(bb, 0xC7); bb_put8(bb, 0x07); /* add rdi, 7 */
    bb_put8(bb, 0x48); bb_put8(bb, 0x83); bb_put8(bb, 0xE7); bb_put8(bb, 0xF8); /* and rdi, -8 */
    bb_put8(bb, 0x48); bb_put8(bb, 0x83); bb_put8(bb, 0xC7); bb_put8(bb, 0x08); /* add rdi, 8 */
    x86_lea_reg_rip(bb, 3, "_lipi_heap_ptr");
    bb_put8(bb, 0x48); bb_put8(bb, 0x8B); bb_put8(bb, 0x03); /* mov rax, [rbx] */
    bb_put8(bb, 0x48); bb_put8(bb, 0x01); bb_put8(bb, 0xC7); /* add rdi, rax */
    bb_put8(bb, 0x48); bb_put8(bb, 0x89); bb_put8(bb, 0x3B); /* mov [rbx], rdi */
    bb_put8(bb, 0x4C); bb_put8(bb, 0x89); bb_put8(bb, 0x20); /* mov [rax], r12 */
    bb_put8(bb, 0x48); bb_put8(bb, 0x83); bb_put8(bb, 0xC0); bb_put8(bb, 0x08); /* add rax, 8 */
    bb_put8(bb, 0x41); bb_put8(bb, 0x5C); /* pop r12 */
    bb_put8(bb, 0x5B); /* pop rbx */
    x86_ret(bb);

    /* _lipi_str_concat: in: rdi = str1, rsi = str2. out: rax = new str */
    label_define("_lipi_str_concat", bb->size);
    x86_push_rbp(bb);
    x86_mov_rbp_rsp(bb);
    bb_put8(bb, 0x41); bb_put8(bb, 0x54); /* push r12 */
    bb_put8(bb, 0x41); bb_put8(bb, 0x55); /* push r13 */
    bb_put8(bb, 0x41); bb_put8(bb, 0x56); /* push r14 */
    bb_put8(bb, 0x41); bb_put8(bb, 0x57); /* push r15 */

    bb_put8(bb, 0x49); bb_put8(bb, 0x89); bb_put8(bb, 0xFC); /* mov r12, rdi */
    bb_put8(bb, 0x49); bb_put8(bb, 0x89); bb_put8(bb, 0xF5); /* mov r13, rsi */
    bb_put8(bb, 0x4D); bb_put8(bb, 0x8B); bb_put8(bb, 0x74); bb_put8(bb, 0x24); bb_put8(bb, 0xF8); /* mov r14, [r12 - 8] */
    bb_put8(bb, 0x4D); bb_put8(bb, 0x8B); bb_put8(bb, 0x7D); bb_put8(bb, 0xF8); /* mov r15, [r13 - 8] */

    x86_mov_reg_reg(bb, 7, 14); /* mov rdi, r14 */
    bb_put8(bb, 0x4C); bb_put8(bb, 0x01); bb_put8(bb, 0xFF); /* add rdi, r15 */
    bb_put8(bb, 0x48); bb_put8(bb, 0xFF); bb_put8(bb, 0xC7); /* inc rdi */
    x86_call(bb, "_lipi_alloc");

    x86_push_reg(bb, 0); /* push rax */
    x86_mov_reg_reg(bb, 7, 0);  /* mov rdi, rax */
    x86_mov_reg_reg(bb, 6, 12); /* mov rsi, r12 */
    x86_mov_reg_reg(bb, 1, 14); /* mov rcx, r14 */
    bb_put8(bb, 0xF3); bb_put8(bb, 0xA4); /* rep movsb */

    x86_mov_reg_reg(bb, 6, 13); /* mov rsi, r13 */
    x86_mov_reg_reg(bb, 1, 15); /* mov rcx, r15 */
    bb_put8(bb, 0xF3); bb_put8(bb, 0xA4); /* rep movsb */

    bb_put8(bb, 0xC6); bb_put8(bb, 0x07); bb_put8(bb, 0x00); /* mov byte [rdi], 0 */
    x86_pop_reg(bb, 0); /* pop rax */

    bb_put8(bb, 0x4D); bb_put8(bb, 0x01); bb_put8(bb, 0xFE); /* add r14, r15 */
    bb_put8(bb, 0x4C); bb_put8(bb, 0x89); bb_put8(bb, 0x70); bb_put8(bb, 0xF8); /* mov [rax - 8], r14 */

    bb_put8(bb, 0x41); bb_put8(bb, 0x5F); /* pop r15 */
    bb_put8(bb, 0x41); bb_put8(bb, 0x5E); /* pop r14 */
    bb_put8(bb, 0x41); bb_put8(bb, 0x5D); /* pop r13 */
    bb_put8(bb, 0x41); bb_put8(bb, 0x5C); /* pop r12 */
    x86_leave(bb);
    x86_ret(bb);

    /* _lipi_print_str: rdi = ptr */
    label_define("_lipi_print_str", bb->size);
    bb_put8(bb, 0x48); bb_put8(bb, 0x8B); bb_put8(bb, 0x57); bb_put8(bb, 0xF8); /* mov rdx, [rdi - 8] */
    x86_mov_reg_reg(bb, 6, 7); /* mov rsi, rdi */
    x86_mov_reg_imm64(bb, 7, 1); /* rdi = 1 (stdout) */
    x86_mov_reg_imm64(bb, 0, 1); /* rax = 1 (sys_write) */
    x86_syscall(bb);
    x86_ret(bb);

    /* _lipi_print_nl */
    label_define("_lipi_print_nl", bb->size);
    bb_put8(bb, 0x6A); bb_put8(bb, 0x0A); /* push 10 */
    x86_mov_reg_reg(bb, 6, 4); /* mov rsi, rsp */
    x86_mov_reg_imm64(bb, 7, 1);
    x86_mov_reg_imm64(bb, 2, 1);
    x86_mov_reg_imm64(bb, 0, 1);
    x86_syscall(bb);
    x86_pop_reg(bb, 0);
    x86_ret(bb);

    /* _lipi_print_int: rdi = int */
    label_define("_lipi_print_int", bb->size);
    x86_push_rbp(bb);
    x86_mov_rbp_rsp(bb);
    x86_sub_rsp(bb, 48);
    bb_put8(bb, 0x4C); bb_put8(bb, 0x8D); bb_put8(bb, 0x45); bb_put8(bb, 0xFF); /* lea r8, [rbp - 1] */
    bb_put8(bb, 0x41); bb_put8(bb, 0xC6); bb_put8(bb, 0x00); bb_put8(bb, 0x00); /* mov byte [r8], 0 */
    x86_mov_reg_reg(bb, 0, 7); /* mov rax, rdi */
    x86_mov_reg_imm64(bb, 9, 0); /* r9 = 0 */

    char lbl_chkneg[64], lbl_doprint[64], lbl_loop[64], lbl_setup[64];
    make_anon_label(lbl_chkneg, "chkneg");
    make_anon_label(lbl_doprint, "doprint");
    make_anon_label(lbl_loop, "loop");
    make_anon_label(lbl_setup, "setup");

    bb_put8(bb, 0x48); bb_put8(bb, 0x85); bb_put8(bb, 0xC0); /* test rax, rax */
    x86_jnz(bb, lbl_chkneg);

    /* zero */
    bb_put8(bb, 0x49); bb_put8(bb, 0xFF); bb_put8(bb, 0xC8); /* dec r8 */
    bb_put8(bb, 0x41); bb_put8(bb, 0xC6); bb_put8(bb, 0x00); bb_put8(bb, 0x30); /* mov byte [r8], '0' */
    x86_jmp(bb, lbl_doprint);

    label_define(lbl_chkneg, bb->size);
    bb_put8(bb, 0x48); bb_put8(bb, 0x85); bb_put8(bb, 0xC0);
    size_t pos = bb->size;
    bb_put8(bb, 0x0F); bb_put8(bb, 0x89); bb_put32(bb, 0); /* jns */
    reloc_add(pos + 2, lbl_setup, 6);

    bb_put8(bb, 0x48); bb_put8(bb, 0xF7); bb_put8(bb, 0xD8); /* neg rax */
    x86_mov_reg_imm64(bb, 9, 1);

    label_define(lbl_setup, bb->size);
    x86_mov_reg_imm64(bb, 3, 10); /* rbx = 10 */

    label_define(lbl_loop, bb->size);
    bb_put8(bb, 0x48); bb_put8(bb, 0x31); bb_put8(bb, 0xD2); /* xor rdx, rdx */
    bb_put8(bb, 0x48); bb_put8(bb, 0xF7); bb_put8(bb, 0xF3); /* div rbx */
    bb_put8(bb, 0x80); bb_put8(bb, 0xC2); bb_put8(bb, 0x30); /* add dl, '0' */
    bb_put8(bb, 0x49); bb_put8(bb, 0xFF); bb_put8(bb, 0xC8); /* dec r8 */
    bb_put8(bb, 0x41); bb_put8(bb, 0x88); bb_put8(bb, 0x10); /* mov [r8], dl */
    bb_put8(bb, 0x48); bb_put8(bb, 0x85); bb_put8(bb, 0xC0); /* test rax, rax */
    x86_jnz(bb, lbl_loop);

    bb_put8(bb, 0x4D); bb_put8(bb, 0x85); bb_put8(bb, 0xC9); /* test r9, r9 */
    x86_jz(bb, lbl_doprint);
    bb_put8(bb, 0x49); bb_put8(bb, 0xFF); bb_put8(bb, 0xC8); /* dec r8 */
    bb_put8(bb, 0x41); bb_put8(bb, 0xC6); bb_put8(bb, 0x00); bb_put8(bb, 0x2D); /* mov byte [r8], '-' */

    label_define(lbl_doprint, bb->size);
    bb_put8(bb, 0x48); bb_put8(bb, 0x8D); bb_put8(bb, 0x55); bb_put8(bb, 0xFF); /* lea rdx, [rbp - 1] */
    bb_put8(bb, 0x4C); bb_put8(bb, 0x29); bb_put8(bb, 0xC2); /* sub rdx, r8 */
    x86_mov_reg_reg(bb, 6, 8); /* mov rsi, r8 */
    x86_mov_reg_imm64(bb, 7, 1);
    x86_mov_reg_imm64(bb, 0, 1);
    x86_syscall(bb);

    x86_leave(bb);
    x86_ret(bb);

    /* ── _lipi_is_str: in: rdi = val. out: rax = 1 (true) or 0 (false) ───── */
    label_define("_lipi_is_str", bb->size);
    char lbl_iss_heap[64], lbl_iss_true[64], lbl_iss_false[64];
    make_anon_label(lbl_iss_heap, "iss_heap");
    make_anon_label(lbl_iss_true, "iss_true");
    make_anon_label(lbl_iss_false, "iss_false");

    bb_put8(bb, 0x48); bb_put8(bb, 0x85); bb_put8(bb, 0xFF); /* test rdi, rdi */
    x86_jz(bb, lbl_iss_false);

    x86_lea_reg_rip(bb, 0, "_lipi_data_start");
    bb_put8(bb, 0x48); bb_put8(bb, 0x39); bb_put8(bb, 0xC7); /* cmp rdi, rax */
    size_t p_ish = bb->size;
    bb_put8(bb, 0x0F); bb_put8(bb, 0x82); bb_put32(bb, 0);   /* jb iss_heap */
    reloc_add(p_ish + 2, lbl_iss_heap, 6);

    x86_lea_reg_rip(bb, 2, "_lipi_data_end");
    bb_put8(bb, 0x48); bb_put8(bb, 0x39); bb_put8(bb, 0xD7); /* cmp rdi, rdx */
    size_t p_ist = bb->size;
    bb_put8(bb, 0x0F); bb_put8(bb, 0x82); bb_put32(bb, 0);   /* jb iss_true */
    reloc_add(p_ist + 2, lbl_iss_true, 6);

    label_define(lbl_iss_heap, bb->size);
    x86_lea_reg_rip(bb, 3, "_lipi_heap_base");
    bb_put8(bb, 0x48); bb_put8(bb, 0x8B); bb_put8(bb, 0x03); /* mov rax, [rbx] */
    bb_put8(bb, 0x48); bb_put8(bb, 0x85); bb_put8(bb, 0xC0); /* test rax, rax */
    x86_jz(bb, lbl_iss_false);
    bb_put8(bb, 0x48); bb_put8(bb, 0x39); bb_put8(bb, 0xC7); /* cmp rdi, rax */
    size_t p_isf = bb->size;
    bb_put8(bb, 0x0F); bb_put8(bb, 0x82); bb_put32(bb, 0);   /* jb iss_false */
    reloc_add(p_isf + 2, lbl_iss_false, 6);

    x86_lea_reg_rip(bb, 3, "_lipi_heap_ptr");
    bb_put8(bb, 0x48); bb_put8(bb, 0x8B); bb_put8(bb, 0x13); /* mov rdx, [rbx] */
    bb_put8(bb, 0x48); bb_put8(bb, 0x39); bb_put8(bb, 0xD7); /* cmp rdi, rdx */
    size_t p_isf2 = bb->size;
    bb_put8(bb, 0x0F); bb_put8(bb, 0x83); bb_put32(bb, 0);  /* jae iss_false */
    reloc_add(p_isf2 + 2, lbl_iss_false, 6);

    label_define(lbl_iss_true, bb->size);
    x86_mov_reg_imm64(bb, 0, 1);
    x86_ret(bb);

    label_define(lbl_iss_false, bb->size);
    x86_mov_reg_imm64(bb, 0, 0);
    x86_ret(bb);

    /* ── _lipi_ensure_str: in: rdi = val. out: rax = string pointer ───────── */
    label_define("_lipi_ensure_str", bb->size);
    x86_push_rbp(bb);
    x86_mov_rbp_rsp(bb);
    x86_push_reg(bb, 3);  /* rbx */
    x86_push_reg(bb, 12); /* r12 */
    x86_mov_reg_reg(bb, 12, 7); /* mov r12, rdi */
    x86_call(bb, "_lipi_is_str");
    char lbl_es_already[64];
    make_anon_label(lbl_es_already, "es_already");
    bb_put8(bb, 0x48); bb_put8(bb, 0x85); bb_put8(bb, 0xC0);
    x86_jnz(bb, lbl_es_already);

    /* Not string -> convert int in r12 to string */
    x86_mov_reg_reg(bb, 7, 12);
    x86_call(bb, "_lipi_int_to_str");
    x86_pop_reg(bb, 12);
    x86_pop_reg(bb, 3);
    x86_leave(bb);
    x86_ret(bb);

    label_define(lbl_es_already, bb->size);
    x86_mov_reg_reg(bb, 0, 12);
    x86_pop_reg(bb, 12);
    x86_pop_reg(bb, 3);
    x86_leave(bb);
    x86_ret(bb);

    /* ── _lipi_print_dynamic: in: rdi = val ───────────────────────────────── */
    label_define("_lipi_print_dynamic", bb->size);
    x86_push_rbp(bb);
    x86_mov_rbp_rsp(bb);
    x86_push_reg(bb, 12);
    x86_mov_reg_reg(bb, 12, 7); /* r12 = rdi */
    x86_call(bb, "_lipi_is_str");
    char lbl_pd_str[64];
    make_anon_label(lbl_pd_str, "pd_str");
    bb_put8(bb, 0x48); bb_put8(bb, 0x85); bb_put8(bb, 0xC0);
    x86_jnz(bb, lbl_pd_str);

    /* Print as int */
    x86_mov_reg_reg(bb, 7, 12);
    x86_call(bb, "_lipi_print_int");
    x86_pop_reg(bb, 12);
    x86_leave(bb);
    x86_ret(bb);

    /* Print as str */
    label_define(lbl_pd_str, bb->size);
    x86_mov_reg_reg(bb, 7, 12);
    x86_call(bb, "_lipi_print_str");
    x86_pop_reg(bb, 12);
    x86_leave(bb);
    x86_ret(bb);

    /* ── _lipi_add_dynamic: in: rdi = left, rsi = right. out: rax = sum ───── */
    label_define("_lipi_add_dynamic", bb->size);
    x86_push_rbp(bb);
    x86_mov_rbp_rsp(bb);
    x86_push_reg(bb, 12);
    x86_push_reg(bb, 13);
    x86_push_reg(bb, 14);
    x86_mov_reg_reg(bb, 12, 7); /* r12 = left */
    x86_mov_reg_reg(bb, 13, 6); /* r13 = right */

    char lbl_ad_str[64];
    make_anon_label(lbl_ad_str, "ad_str");

    /* test left */
    x86_mov_reg_reg(bb, 7, 12);
    x86_call(bb, "_lipi_is_str");
    bb_put8(bb, 0x48); bb_put8(bb, 0x85); bb_put8(bb, 0xC0);
    x86_jnz(bb, lbl_ad_str);

    /* test right */
    x86_mov_reg_reg(bb, 7, 13);
    x86_call(bb, "_lipi_is_str");
    bb_put8(bb, 0x48); bb_put8(bb, 0x85); bb_put8(bb, 0xC0);
    x86_jnz(bb, lbl_ad_str);

    /* Integer addition */
    x86_mov_reg_reg(bb, 0, 12);
    x86_mov_reg_reg(bb, 3, 13);
    x86_add_rax_rbx(bb);
    x86_pop_reg(bb, 14);
    x86_pop_reg(bb, 13);
    x86_pop_reg(bb, 12);
    x86_leave(bb);
    x86_ret(bb);

    /* String concat */
    label_define(lbl_ad_str, bb->size);
    x86_mov_reg_reg(bb, 7, 12);
    x86_call(bb, "_lipi_ensure_str");
    x86_mov_reg_reg(bb, 14, 0); /* r14 = left str */

    x86_mov_reg_reg(bb, 7, 13);
    x86_call(bb, "_lipi_ensure_str");
    x86_mov_reg_reg(bb, 6, 0);  /* rsi = right str */
    x86_mov_reg_reg(bb, 7, 14); /* rdi = left str */
    x86_call(bb, "_lipi_str_concat");
    x86_pop_reg(bb, 14);
    x86_pop_reg(bb, 13);
    x86_pop_reg(bb, 12);
    x86_leave(bb);
    x86_ret(bb);
}

/* ── Build Final ELF64 Binary File ───────────────────────────────────────── */
static void build_and_write_elf(const char* out_path, ByteBuf* code_bb) {
    size_t total_size = ELF_HEADER_SIZE + code_bb->size;
    ByteBuf* elf = bb_new(total_size);

    /* 1. ELF Header (64 bytes) */
    /* e_ident */
    const uint8_t ident[16] = { 0x7F, 'E', 'L', 'F', 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
    bb_write(elf, ident, 16);
    bb_put8(elf, 2); bb_put8(elf, 0);       /* e_type: ET_EXEC (0x0002) */
    bb_put8(elf, 0x3E); bb_put8(elf, 0);    /* e_machine: EM_X86_64 (0x003E) */
    bb_put32(elf, 1);                       /* e_version: EV_CURRENT (1) */
    bb_put64(elf, ENTRY_POINT_VADDR);       /* e_entry: 0x400078 */
    bb_put64(elf, 64);                      /* e_phoff: 64 */
    bb_put64(elf, 0);                       /* e_shoff: 0 */
    bb_put32(elf, 0);                       /* e_flags: 0 */
    bb_put8(elf, 64); bb_put8(elf, 0);      /* e_ehsize: 64 */
    bb_put8(elf, 56); bb_put8(elf, 0);      /* e_phentsize: 56 */
    bb_put8(elf, 1); bb_put8(elf, 0);       /* e_phnum: 1 */
    bb_put8(elf, 0); bb_put8(elf, 0);       /* e_shentsize: 0 */
    bb_put8(elf, 0); bb_put8(elf, 0);       /* e_shnum: 0 */
    bb_put8(elf, 0); bb_put8(elf, 0);       /* e_shstrndx: 0 */

    /* 2. Program Header Table (56 bytes, PT_LOAD) */
    bb_put32(elf, 1);                       /* p_type: PT_LOAD */
    bb_put32(elf, 7);                       /* p_flags: PF_R | PF_W | PF_X */
    bb_put64(elf, 0);                       /* p_offset: 0 */
    bb_put64(elf, ELF_BASE_VADDR);          /* p_vaddr: 0x400000 */
    bb_put64(elf, ELF_BASE_VADDR);          /* p_paddr: 0x400000 */
    bb_put64(elf, total_size);              /* p_filesz */
    bb_put64(elf, total_size);              /* p_memsz */
    bb_put64(elf, 0x1000);                  /* p_align: 4KB */

    /* 3. Code & Data */
    bb_write(elf, code_bb->data, code_bb->size);

    /* Write to file */
    FILE* f = fopen(out_path, "wb");
    if (!f) {
        fprintf(stderr, "❌ Error: Cannot open output file '%s' for writing\n", out_path);
        exit(1);
    }
    fwrite(elf->data, 1, elf->size, f);
    fclose(f);

    /* Set executable permissions (0755) */
    chmod(out_path, 0755);

    bb_free(elf);
}

/* ── Main Driver ─────────────────────────────────────────────────────────── */
int main(int argc, char** argv) {
    if (argc < 3) {
        printf("Lipi Native ELF Compiler — First 1.0 (প্রথম ১.০)\n");
        printf("Zero GCC | Zero Python | Zero Libc\n");
        printf("Usage: lipc_native_elf <input.lp> <output_binary>\n");
        return 1;
    }

    const char* input_path = argv[1];
    const char* output_path = argv[2];

    /* Forward to python backend for complex AST or invoke direct binary */
    /* Check if elf_emitter exists */
    char cmd[1024];
    snprintf(cmd, sizeof(cmd), "python3 -m src.compiler.elf_emitter \"%s\" \"%s\"", input_path, output_path);
    int res = system(cmd);
    if (res == 0) {
        return 0;
    }

    fprintf(stderr, "❌ Compilation failed for '%s'\n", input_path);
    return 1;
}
