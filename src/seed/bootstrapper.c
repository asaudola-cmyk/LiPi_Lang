/**
 * 👑 Lipi Standalone Native Linux ELF Bootstrapper Seed (lipic / lipi-seed)
 *
 * WHY: Lipi is a completely independent, sovereign systems programming language.
 * This bootstrapper is the minimal, standalone Stage 0 Seed compiler written in standard C
 * that parses Lipi (.lp) code and synthesizes 64-bit Linux ELF standalone binary executables
 * with REAL x86_64 MACHINE CODE:
 *   - Two-Pass Flat ELF Code Generation (Jump over functions to main entry point)
 *   - Real stack frames (push rbp; mov rbp, rsp; sub rsp, 4096)
 *   - First-Class Functions (কাজ / fn) with System V AMD64 ABI (rdi, rsi, rdx, rcx, r8, r9)
 *   - Arbitrary recursive function calls (call rel32, leave, ret) with backpatched relocations
 *   - Direct Linux x86_64 Kernel Syscalls (সিসকল / syscall) with full register ABI (rax, rdi, rsi, rdx, r10, r8, r9)
 *   - Multi-file Module Import (অন্তর্ভুক্ত / import) with circular dependency prevention
 *   - 64KB Writeable BSS Buffer (বাফার / buffer) for in-memory file I/O operations
 *   - Arbitrary recursive expression trees (push/pop rax/rbx stack machine evaluation)
 *   - Real ALU machine instructions (imul, add, sub, idiv) executed by CPU hardware at runtime
 *   - Real conditional branching (cmp, jle, jg, je, jne, jmp) with relative offset backpatching
 *   - Real loop control flow (যতক্ষণ / while) with backward loop jumps and exit backpatching
 *   - Real hardware RDTSC instruction (0x0F 0x31) to read physical CPU cycle registers
 *   - Real runtime stack-allocated Bengali numeral (itoa) conversion in pure machine code
 *   - Interactive Native REPL shell (lipi repl) and automated test runner (lipi test)
 *   - ZERO PHP, ZERO Libc at runtime, ZERO GCC required to run generated binaries
 *
 * @author Shafiullah (Gyani Supreme Core)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <unistd.h>
#include <sys/stat.h>
#include <ctype.h>

#define BASE_VADDR    0x400000ULL
#define CODE_OFFSET   0x1000ULL
#define ENTRY_POINT   (BASE_VADDR + CODE_OFFSET) // 0x401000

#define MAX_SYMBOLS   1024
#define MAX_FUNCTIONS 128
#define MAX_CODE_SIZE 262144
#define MAX_RODATA    262144
#define MAX_RELOCS    4096
#define MAX_BLOCKS    64

// 1. Symbol Table for local stack frame variables
typedef struct {
    char name[128];
    int32_t stack_offset;
    bool is_initialized;
    bool is_string;
    size_t rodata_offset;
    size_t string_len;
    int64_t const_val;
    char func_scope[128]; // Empty for global/main, or function name
    char struct_type[64]; // Stores struct type if known (মহাদিগন্ত ১১: গঠন / Structs)
} Symbol;

static Symbol g_syms[MAX_SYMBOLS];
static int g_sym_count = 0;
static int32_t g_current_stack_offset = -8;
static char g_active_scope[128] = "";

static Symbol *find_symbol(const char *name) {
    if (g_active_scope[0] != '\0') {
        for (int i = 0; i < g_sym_count; i++) {
            if (strcmp(g_syms[i].func_scope, g_active_scope) == 0 && strcmp(g_syms[i].name, name) == 0) {
                return &g_syms[i];
            }
        }
    }
    for (int i = 0; i < g_sym_count; i++) {
        if (g_syms[i].func_scope[0] == '\0' && strcmp(g_syms[i].name, name) == 0) {
            return &g_syms[i];
        }
    }
    return NULL;
}

static Symbol *add_symbol(const char *name) {
    Symbol *s = find_symbol(name);
    if (s && strcmp(s->func_scope, g_active_scope) == 0) return s;
    if (g_sym_count < MAX_SYMBOLS) {
        s = &g_syms[g_sym_count++];
        snprintf(s->name, sizeof(s->name), "%s", name);
        snprintf(s->func_scope, sizeof(s->func_scope), "%s", g_active_scope);
        s->stack_offset = g_current_stack_offset;
        g_current_stack_offset -= 8;
        s->is_initialized = false;
        s->is_string = false;
        s->rodata_offset = 0;
        s->string_len = 0;
        s->const_val = 0;
        s->struct_type[0] = '\0';
        return s;
    }
    return NULL;
}

// 2. Function Table & Calling Convention
typedef struct {
    char name[128];
    size_t code_offset;
    int param_count;
    char params[6][64];
    int32_t frame_size;
} Function;

static Function g_funcs[MAX_FUNCTIONS];
static int g_func_count = 0;

static Function *find_function(const char *name) {
    for (int i = 0; i < g_func_count; i++) {
        if (strcmp(g_funcs[i].name, name) == 0) {
            return &g_funcs[i];
        }
    }
    return NULL;
}

static Function *add_function(const char *name) {
    Function *fn = find_function(name);
    if (fn) return fn;
    if (g_func_count < MAX_FUNCTIONS) {
        fn = &g_funcs[g_func_count++];
        strncpy(fn->name, name, sizeof(fn->name) - 1);
        fn->name[sizeof(fn->name) - 1] = '\0';
        fn->code_offset = 0;
        fn->param_count = 0;
        fn->frame_size = 512;
        return fn;
    }
    return NULL;
}

// Function call relocations
typedef struct {
    size_t code_patch_pos;
    char func_name[128];
} FuncReloc;

static FuncReloc g_func_relocs[1024];
static int g_func_reloc_count = 0;

static void add_func_reloc(size_t pos, const char *name) {
    if (g_func_reloc_count < 1024) {
        g_func_relocs[g_func_reloc_count].code_patch_pos = pos;
        strncpy(g_func_relocs[g_func_reloc_count].func_name, name, 127);
        g_func_relocs[g_func_reloc_count].func_name[127] = '\0';
        g_func_reloc_count++;
    }
}

// 3. Code Buffer for x86_64 Machine Code instructions
typedef struct {
    uint8_t bytes[MAX_CODE_SIZE];
    size_t size;
} CodeBuffer;

static void emit_u8(CodeBuffer *cb, uint8_t b) {
    if (cb->size < sizeof(cb->bytes)) cb->bytes[cb->size++] = b;
}

static void emit_u32(CodeBuffer *cb, uint32_t v) {
    emit_u8(cb, (uint8_t)(v & 0xFF));
    emit_u8(cb, (uint8_t)((v >> 8) & 0xFF));
    emit_u8(cb, (uint8_t)((v >> 16) & 0xFF));
    emit_u8(cb, (uint8_t)((v >> 24) & 0xFF));
}

static void emit_u64(CodeBuffer *cb, uint64_t v) {
    emit_u32(cb, (uint32_t)(v & 0xFFFFFFFF));
    emit_u32(cb, (uint32_t)((v >> 32) & 0xFFFFFFFF));
}

static void emit_bytes(CodeBuffer *cb, const uint8_t *data, size_t len) {
    for (size_t i = 0; i < len; i++) emit_u8(cb, data[i]);
}

// 4. Read-Only Data (.rodata) Buffer
typedef struct {
    uint8_t bytes[MAX_RODATA];
    size_t size;
} RoDataBuffer;

static size_t add_rodata(RoDataBuffer *ro, const uint8_t *data, size_t len) {
    size_t offset = ro->size;
    if (ro->size + len <= sizeof(ro->bytes)) {
        memcpy(&ro->bytes[ro->size], data, len);
        ro->size += len;
    }
    return offset;
}

// 5. Relocation records for string addresses (.rodata) and writeable buffer (.bss)
typedef struct {
    size_t code_patch_pos;
    size_t rodata_offset;
} RelocRecord;

static RelocRecord g_relocs[MAX_RELOCS];
static int g_reloc_count = 0;

static void add_reloc(size_t code_pos, size_t rodata_off) {
    if (g_reloc_count < MAX_RELOCS) {
        g_relocs[g_reloc_count].code_patch_pos = code_pos;
        g_relocs[g_reloc_count].rodata_offset = rodata_off;
        g_reloc_count++;
    }
}

typedef struct {
    size_t code_patch_pos;
    size_t bss_offset;
} BssReloc;

static BssReloc g_bss_relocs[MAX_RELOCS];
static int g_bss_reloc_count = 0;

static void add_bss_reloc(size_t code_pos, size_t bss_off) {
    if (g_bss_reloc_count < MAX_RELOCS) {
        g_bss_relocs[g_bss_reloc_count].code_patch_pos = code_pos;
        g_bss_relocs[g_bss_reloc_count].bss_offset = bss_off;
        g_bss_reloc_count++;
    }
}

// 6. String helper utilities
static char *trim(char *str) {
    while (isspace((unsigned char)*str)) str++;
    if (*str == 0) return str;
    char *end = str + strlen(str) - 1;
    while (end > str && isspace((unsigned char)*end)) end--;
    end[1] = '\0';
    return str;
}

static void strip_inline_comments(char *str) {
    bool in_quote = false;
    char quote_char = 0;
    for (char *p = str; *p; p++) {
        if (!in_quote && (*p == '"' || *p == '\'')) {
            in_quote = true;
            quote_char = *p;
        } else if (in_quote && *p == quote_char) {
            if (*(p - 1) != '\\') in_quote = false;
        } else if (!in_quote) {
            if (*p == '/' && *(p + 1) == '/') {
                *p = '\0';
                break;
            }
            if (*p == '#') {
                *p = '\0';
                break;
            }
        }
    }
}

// Struct definition representation for Custom Types (মহাদিগন্ত ১১: গঠন / Structs)
// WHY: Allows custom data structures with named fields, automatic 8-byte alignment, and dot syntax.
typedef struct {
    char name[64];
    int field_count;
    char field_names[16][64];
    int field_offsets[16];
    int total_size;
} StructDef;

static StructDef g_structs[32];
static int g_struct_count = 0;

static StructDef *find_struct(const char *name) {
    for (int i = 0; i < g_struct_count; i++) {
        if (strcmp(g_structs[i].name, name) == 0) return &g_structs[i];
    }
    return NULL;
}

static int find_struct_field_offset_in(const char *struct_name, const char *field_name) {
    StructDef *sd = find_struct(struct_name);
    if (sd) {
        for (int j = 0; j < sd->field_count; j++) {
            if (strcmp(sd->field_names[j], field_name) == 0) {
                return sd->field_offsets[j];
            }
        }
    }
    return -1;
}

static int find_struct_field_offset(const char *field_name) {
    for (int i = 0; i < g_struct_count; i++) {
        for (int j = 0; j < g_structs[i].field_count; j++) {
            if (strcmp(g_structs[i].field_names[j], field_name) == 0) {
                return g_structs[i].field_offsets[j];
            }
        }
    }
    return -1;
}

static void parse_all_structs(const char *source) {
    const char *p = source;
    const size_t len_gothon = strlen("গঠন");

    while (*p) {
        bool is_gothon = (strncmp(p, "গঠন", len_gothon) == 0 && (p[len_gothon] == ' ' || p[len_gothon] == '\t'));
        bool is_struct = (strncmp(p, "struct", 6) == 0 && (p[6] == ' ' || p[6] == '\t'));

        if (is_gothon || is_struct) {
            size_t pfx = is_gothon ? len_gothon : 6;
            p += pfx;
            while (*p && isspace((unsigned char)*p)) p++;

            const char *name_start = p;
            while (*p && !isspace((unsigned char)*p) && *p != '{') p++;
            size_t name_len = (size_t)(p - name_start);

            while (*p && *p != '{') p++;
            if (*p == '{') {
                p++;
                const char *body_start = p;
                int depth = 1;
                while (*p && depth > 0) {
                    if (*p == '{') depth++;
                    else if (*p == '}') depth--;
                    if (depth > 0) p++;
                }
                const char *body_end = p;

                if (g_struct_count < 32 && name_len > 0) {
                    StructDef *sd = &g_structs[g_struct_count++];
                    memset(sd, 0, sizeof(StructDef));
                    if (name_len < sizeof(sd->name)) {
                        strncpy(sd->name, name_start, name_len);
                        sd->name[name_len] = '\0';
                    }

                    char body_copy[4096];
                    size_t blen = (size_t)(body_end - body_start);
                    if (blen < sizeof(body_copy)) {
                        strncpy(body_copy, body_start, blen);
                        body_copy[blen] = '\0';

                        char *saveptr = NULL;
                        char *field_tok = strtok_r(body_copy, ",\r\n;", &saveptr);
                        while (field_tok && sd->field_count < 16) {
                            char *fn = trim(field_tok);
                            char *c1 = strstr(fn, "//");
                            if (c1) *c1 = '\0';
                            char *c2 = strchr(fn, '#');
                            if (c2) *c2 = '\0';
                            fn = trim(fn);
                            if (*fn != '\0') {
                                strncpy(sd->field_names[sd->field_count], fn, 63);
                                sd->field_names[sd->field_count][63] = '\0';
                                sd->field_offsets[sd->field_count] = sd->field_count * 8;
                                sd->field_count++;
                            }
                            field_tok = strtok_r(NULL, ",\r\n;", &saveptr);
                        }
                        sd->total_size = sd->field_count * 8;
                    }
                }
                if (*p == '}') p++;
                continue;
            }
        }
        p++;
    }
}

static void parse_escaped_string(const char **p_src, char quote, char *out_buf, size_t max_out, size_t *out_len) {
    const char *p = *p_src;
    size_t slen = 0;
    while (*p && *p != quote) {
        if (*p == '\\' && *(p + 1)) {
            p++;
            if (*p == '0' && *(p + 1) == '3' && *(p + 2) == '3') {
                p += 3;
                if (slen < max_out - 1) out_buf[slen++] = '\033';
            } else if (*p == 'e') {
                p++;
                if (slen < max_out - 1) out_buf[slen++] = '\033';
            } else if (*p == 'x' && isxdigit((unsigned char)*(p + 1)) && isxdigit((unsigned char)*(p + 2))) {
                char hex[3] = {*(p + 1), *(p + 2), '\0'};
                p += 3;
                if (slen < max_out - 1) out_buf[slen++] = (char)strtol(hex, NULL, 16);
            } else {
                char esc = *p++;
                char c = (esc == 'n') ? '\n' : ((esc == 't') ? '\t' : ((esc == 'r') ? '\r' : esc));
                if (slen < max_out - 1) out_buf[slen++] = c;
            }
        } else {
            if (slen < max_out - 1) out_buf[slen++] = *p++;
            else p++;
        }
    }
    if (*p == quote) p++;
    out_buf[slen] = '\0';
    *out_len = slen;
    *p_src = p;
}

static int64_t parse_bangla_number(const char *str) {
    int64_t val = 0;
    bool neg = false;
    const unsigned char *p = (const unsigned char *)str;
    while (*p && isspace(*p)) p++;
    if (*p == '-') {
        neg = true;
        p++;
    } else if (*p == '+') {
        p++;
    }
    while (*p) {
        if (*p >= '0' && *p <= '9') {
            val = val * 10 + (*p - '0');
            p++;
            continue;
        }
        if (p[0] == 0xE0 && p[1] == 0xA7 && (p[2] >= 0xA6 && p[2] <= 0xAF)) {
            int d = p[2] - 0xA6;
            val = val * 10 + d;
            p += 3;
            continue;
        }
        p++;
    }
    return neg ? -val : val;
}

static bool is_numeric_str(const char *str) {
    const unsigned char *p = (const unsigned char *)str;
    while (*p && isspace(*p)) p++;
    if (*p == '-' || *p == '+') p++;
    if (!*p) return false;
    while (*p) {
        if (*p >= '0' && *p <= '9') { p++; continue; }
        if (p[0] == 0xE0 && p[1] == 0xA7 && (p[2] >= 0xA6 && p[2] <= 0xAF)) { p += 3; continue; }
        if (isspace(*p)) { p++; continue; }
        return false;
    }
    return true;
}

// 7. x86_64 Machine Code Emitter Functions
static void emit_prologue(CodeBuffer *cb, int32_t frame_size) {
    emit_u8(cb, 0x55);                                          // push rbp
    emit_bytes(cb, (const uint8_t[]){0x48, 0x89, 0xe5}, 3);    // mov rbp, rsp
    emit_bytes(cb, (const uint8_t[]){0x48, 0x81, 0xec}, 3);    // sub rsp, imm32
    emit_u32(cb, (uint32_t)frame_size);
}

static void emit_main_epilogue(CodeBuffer *cb) {
    emit_bytes(cb, (const uint8_t[]){0x48, 0xc7, 0xc0, 0x3c, 0x00, 0x00, 0x00}, 7); // mov rax, 60
    emit_bytes(cb, (const uint8_t[]){0x48, 0x31, 0xff}, 3);                         // xor rdi, rdi
    emit_bytes(cb, (const uint8_t[]){0x0f, 0x05}, 2);                               // syscall
}

static void emit_func_epilogue(CodeBuffer *cb) {
    emit_u8(cb, 0xc9); // leave
    emit_u8(cb, 0xc3); // ret
}

static void emit_mov_stack_imm(CodeBuffer *cb, int32_t disp32, int32_t imm32) {
    emit_bytes(cb, (const uint8_t[]){0x48, 0xc7, 0x85}, 3);
    emit_u32(cb, (uint32_t)disp32);
    emit_u32(cb, (uint32_t)imm32);
}

static void emit_mov_rax_stack(CodeBuffer *cb, int32_t disp32) {
    emit_bytes(cb, (const uint8_t[]){0x48, 0x8b, 0x85}, 3);
    emit_u32(cb, (uint32_t)disp32);
}

static void emit_mov_stack_rax(CodeBuffer *cb, int32_t disp32) {
    emit_bytes(cb, (const uint8_t[]){0x48, 0x89, 0x85}, 3);
    emit_u32(cb, (uint32_t)disp32);
}

static void emit_mov_rbx_imm64(CodeBuffer *cb, int64_t imm64) {
    emit_bytes(cb, (const uint8_t[]){0x48, 0xbb}, 2);
    emit_u64(cb, (uint64_t)imm64);
}

static void emit_imul_rax_rbx(CodeBuffer *cb) {
    emit_bytes(cb, (const uint8_t[]){0x48, 0x0f, 0xaf, 0xc3}, 4);
}

static void emit_add_rax_rbx(CodeBuffer *cb) {
    emit_bytes(cb, (const uint8_t[]){0x48, 0x01, 0xd8}, 3);
}

static void emit_sub_rax_rbx(CodeBuffer *cb) {
    emit_bytes(cb, (const uint8_t[]){0x48, 0x29, 0xd8}, 3);
}

static void emit_idiv_rax_rbx(CodeBuffer *cb) {
    emit_bytes(cb, (const uint8_t[]){0x48, 0x99, 0x48, 0xf7, 0xfb}, 5);
}

static void emit_imod_rax_rbx(CodeBuffer *cb) {
    // 0x48 0x99 : cqo (sign-extend RAX into RDX:RAX)
    // 0x48 0xf7 0xfb : idiv rbx (divide RDX:RAX by RBX; quotient in RAX, remainder in RDX)
    // 0x48 0x89 0xd0 : mov rax, rdx (copy remainder from RDX to RAX for modulo result)
    emit_bytes(cb, (const uint8_t[]){0x48, 0x99, 0x48, 0xf7, 0xfb, 0x48, 0x89, 0xd0}, 8);
}

static void emit_rdtsc(CodeBuffer *cb, int32_t stack_disp32) {
    emit_bytes(cb, (const uint8_t[]){
        0x0f, 0x31,             // rdtsc (eax = lo, edx = hi)
        0x48, 0xc1, 0xe2, 0x20, // shl rdx, 32
        0x48, 0x09, 0xd0        // or rax, rdx
    }, 9);
    emit_mov_stack_rax(cb, stack_disp32);
}

static void emit_print_rodata_slice(CodeBuffer *cb, size_t ro_off, size_t len) {
    emit_bytes(cb, (const uint8_t[]){0x48, 0xc7, 0xc0, 0x01, 0x00, 0x00, 0x00}, 7); // mov rax, 1
    emit_bytes(cb, (const uint8_t[]){0x48, 0xc7, 0xc7, 0x01, 0x00, 0x00, 0x00}, 7); // mov rdi, 1
    emit_bytes(cb, (const uint8_t[]){0x48, 0xbe}, 2);                               // movabs rsi, imm64
    size_t patch_pos = cb->size;
    emit_u64(cb, 0); // placeholder
    add_reloc(patch_pos, ro_off);
    emit_bytes(cb, (const uint8_t[]){0x48, 0xc7, 0xc2}, 3);                         // mov rdx, imm32
    emit_u32(cb, (uint32_t)len);
    emit_bytes(cb, (const uint8_t[]){0x0f, 0x05}, 2);                               // syscall
}

static void emit_print_static_string(CodeBuffer *cb, RoDataBuffer *ro, const char *str, size_t len) {
    size_t ro_off = add_rodata(ro, (const uint8_t *)str, len);
    emit_print_rodata_slice(cb, ro_off, len);
}

static void emit_runtime_print_bangla_num(CodeBuffer *cb, bool newline) {
    uint8_t itoa_code[] = {
        0x48, 0x8d, 0xb5, 0x00, 0xff, 0xff, 0xff, // lea rsi, [rbp - 256]
        0xc6, 0x06, 0x0a,                         // mov byte ptr [rsi], 0x0A (\n)
        0x41, 0xb8, 0x01, 0x00, 0x00, 0x00,       // mov r8d, 1 (counter)
        0x48, 0x85, 0xc0,                         // test rax, rax
        0x75, 0x18,                               // jnz .loop (+24 bytes)
        // Zero case:
        0x48, 0xff, 0xce,                         // dec rsi
        0xc6, 0x06, 0xa6,                         // mov byte ptr [rsi], 0xa6 ('০' byte 3)
        0x48, 0xff, 0xce,                         // dec rsi
        0xc6, 0x06, 0xa7,                         // mov byte ptr [rsi], 0xa7 ('০' byte 2)
        0x48, 0xff, 0xce,                         // dec rsi
        0xc6, 0x06, 0xe0,                         // mov byte ptr [rsi], 0xe0 ('০' byte 1)
        0x49, 0x83, 0xc0, 0x03,                   // add r8, 3
        0xeb, 0x2a,                               // jmp .done (+42 bytes)
        // .loop:
        0x48, 0x85, 0xc0,                         // test rax, rax
        0x74, 0x25,                               // jz .done (+37 bytes)
        0x48, 0x31, 0xd2,                         // xor rdx, rdx
        0xbb, 0x0a, 0x00, 0x00, 0x00,             // mov ebx, 10
        0x48, 0xf7, 0xf3,                         // div rbx (rax = quotient, rdx = remainder)
        0x80, 0xc2, 0xa6,                         // add dl, 0xa6 (Bengali digit byte 3)
        0x48, 0xff, 0xce,                         // dec rsi
        0x88, 0x16,                               // mov [rsi], dl
        0x48, 0xff, 0xce,                         // dec rsi
        0xc6, 0x06, 0xa7,                         // mov byte ptr [rsi], 0xa7
        0x48, 0xff, 0xce,                         // dec rsi
        0xc6, 0x06, 0xe0,                         // mov byte ptr [rsi], 0xe0
        0x49, 0x83, 0xc0, 0x03,                   // add r8, 3
        0xeb, 0xd6,                               // jmp .loop (-42 bytes)
        // .done:
        0xb8, 0x01, 0x00, 0x00, 0x00,             // mov eax, 1 (SYS_write)
        0xbf, 0x01, 0x00, 0x00, 0x00,             // mov edi, 1 (stdout)
        0x4c, 0x89, 0xc2,                         // mov rdx, r8 (length)
        0x0f, 0x05                                // syscall
    };

    if (!newline) {
        itoa_code[9] = 0x00;
        itoa_code[12] = 0x00;
    }

    emit_bytes(cb, itoa_code, sizeof(itoa_code));
}

// Runtime dynamic null-terminated UTF-8 C-string printer via SYS_write
static void emit_runtime_print_cstr(CodeBuffer *cb) {
    // Expects null-terminated string pointer in RAX
    emit_bytes(cb, (const uint8_t[]){
        0x48, 0x85, 0xc0,                         // test rax, rax
        0x74, 0x20,                               // jz .Ldone (+32)
        0x48, 0x89, 0xc6,                         // mov rsi, rax
        0x31, 0xd2,                               // xor edx, edx
        0x80, 0x3c, 0x16, 0x00,                   // cmp byte ptr [rsi + rdx], 0
        0x74, 0x05,                               // je .Lwrite (+5)
        0x48, 0xff, 0xc2,                         // inc rdx
        0xeb, 0xf5,                               // jmp .Lloop (-11)
        0x85, 0xd2,                               // test edx, edx
        0x74, 0x0c,                               // jz .Ldone (+12)
        0xb8, 0x01, 0x00, 0x00, 0x00,             // mov eax, 1 (SYS_write)
        0xbf, 0x01, 0x00, 0x00, 0x00,             // mov edi, 1 (stdout)
        0x0f, 0x05                                // syscall
    }, 37);
}

// Runtime dynamic null-terminated UTF-8 string byte length calculation (strlen)
static void emit_runtime_strlen(CodeBuffer *cb) {
    // Expects null-terminated UTF-8 string pointer in RAX, returns byte count in RAX
    emit_bytes(cb, (const uint8_t[]){
        0x48, 0x85, 0xc0,                         // test rax, rax
        0x74, 0x10,                               // jz .Ldone (+16)
        0x48, 0x89, 0xc6,                         // mov rsi, rax
        0x31, 0xc0,                               // xor eax, eax
        0x80, 0x3c, 0x06, 0x00,                   // cmp byte ptr [rsi + rax], 0
        0x74, 0x05,                               // je .Ldone (+5)
        0x48, 0xff, 0xc0,                         // inc rax
        0xeb, 0xf5                                // jmp .Lloop (-11)
    }, 21);
}

// Forward declaration
static void compile_expression_recursive(CodeBuffer *cb, RoDataBuffer *ro, const char *expr);

// Find matching closing parenthesis respecting quotes and nested parentheses
static char *find_matching_close_paren(char *start_after_open) {
    bool in_quote = false;
    char quote_char = 0;
    int depth = 1;
    for (char *p = start_after_open; *p; p++) {
        if (!in_quote && (*p == '"' || *p == '\'')) {
            in_quote = true;
            quote_char = *p;
        } else if (in_quote && *p == quote_char) {
            if (p > start_after_open && *(p - 1) == '\\') {
                // Escaped quote character
            } else {
                in_quote = false;
                quote_char = 0;
            }
        } else if (!in_quote && *p == '(') {
            depth++;
        } else if (!in_quote && *p == ')') {
            depth--;
            if (depth == 0) {
                return p;
            }
        }
    }
    return NULL;
}

// Parse comma-separated arguments respecting string quotes, nested parentheses, and brackets
static int parse_call_arguments(char *args_part, char out_args[8][1024]) {
    int count = 0;
    char current[1024];
    int c_idx = 0;
    bool in_quote = false;
    char quote_char = 0;
    int paren_depth = 0;
    int bracket_depth = 0;

    for (char *p = args_part; *p; p++) {
        if (!in_quote && (*p == '"' || *p == '\'')) {
            in_quote = true;
            quote_char = *p;
            if (c_idx < 1023) current[c_idx++] = *p;
        } else if (in_quote && *p == quote_char) {
            if (p > args_part && *(p - 1) == '\\') {
                if (c_idx < 1023) current[c_idx++] = *p;
            } else {
                in_quote = false;
                quote_char = 0;
                if (c_idx < 1023) current[c_idx++] = *p;
            }
        } else if (!in_quote && *p == '(') {
            paren_depth++;
            if (c_idx < 1023) current[c_idx++] = *p;
        } else if (!in_quote && *p == ')') {
            paren_depth--;
            if (c_idx < 1023) current[c_idx++] = *p;
        } else if (!in_quote && *p == '[') {
            bracket_depth++;
            if (c_idx < 1023) current[c_idx++] = *p;
        } else if (!in_quote && *p == ']') {
            bracket_depth--;
            if (c_idx < 1023) current[c_idx++] = *p;
        } else if (!in_quote && paren_depth == 0 && bracket_depth == 0 && *p == ',') {
            current[c_idx] = '\0';
            char *trimmed = trim(current);
            if (*trimmed != '\0' && count < 8) {
                strncpy(out_args[count++], trimmed, 1023);
                out_args[count - 1][1023] = '\0';
            }
            c_idx = 0;
        } else {
            if (c_idx < 1023) current[c_idx++] = *p;
        }
    }

    if (c_idx > 0) {
        current[c_idx] = '\0';
        char *trimmed = trim(current);
        if (*trimmed != '\0' && count < 8) {
            strncpy(out_args[count++], trimmed, 1023);
            out_args[count - 1][1023] = '\0';
        }
    }

    return count;
}

// Check if an expression represents a single function call identifier(...)
static bool is_function_call_expr(const char *s) {
    const char *p = s;
    while (*p && isspace((unsigned char)*p)) p++;
    if (!*p || *p == '"' || *p == '\'' || isdigit((unsigned char)*p)) return false;

    const char *open_p = strchr(p, '(');
    if (!open_p || open_p == p) return false;

    for (const char *c = p; c < open_p; c++) {
        if (*c == '+' || *c == '-' || *c == '*' || *c == '/' || *c == '%' || isspace((unsigned char)*c)) {
            return false;
        }
    }

    char *close_p = find_matching_close_paren((char *)open_p + 1);
    if (!close_p) return false;

    const char *end = close_p + 1;
    while (*end && isspace((unsigned char)*end)) end++;
    return (*end == '\0');
}

// Direct Linux x86_64 raw kernel syscall emitter (সিসকল / syscall)
static void emit_syscall(CodeBuffer *cb, RoDataBuffer *ro, const char *call_expr) {
    char copy[4096];
    strncpy(copy, call_expr, sizeof(copy) - 1);
    copy[sizeof(copy) - 1] = '\0';

    char *open_p = strchr(copy, '(');
    if (!open_p) return;
    *open_p = '\0';
    char *args_part = open_p + 1;
    char *close_p = find_matching_close_paren(args_part);
    if (close_p) *close_p = '\0';

    char args[8][1024];
    int arg_count = parse_call_arguments(args_part, args);
    if (arg_count == 0) return;

    // Evaluate each argument and push rax to stack:
    for (int i = 0; i < arg_count; i++) {
        char *a = args[i];
        if (a[0] == '"' || a[0] == '\'') {
            char q = a[0];
            char str_buf[4096];
            size_t slen = 0;
            const char *p = a + 1;
            parse_escaped_string(&p, q, str_buf, sizeof(str_buf), &slen);
            size_t ro_off = add_rodata(ro, (const uint8_t *)str_buf, slen + 1);
            emit_bytes(cb, (const uint8_t[]){0x48, 0xb8}, 2); // movabs rax, imm64
            size_t patch = cb->size;
            emit_u64(cb, 0);
            add_reloc(patch, ro_off);
            emit_u8(cb, 0x50); // push rax
        } else if (strcmp(a, "বাফার()") == 0 || strcmp(a, "বাফার") == 0 || strcmp(a, "buffer()") == 0 || strcmp(a, "buffer") == 0) {
            emit_bytes(cb, (const uint8_t[]){0x48, 0xb8}, 2); // movabs rax, imm64
            size_t patch = cb->size;
            emit_u64(cb, 0);
            add_bss_reloc(patch, 0);
            emit_u8(cb, 0x50); // push rax
        } else {
            Symbol *s = find_symbol(a);
            if (s && s->is_string && s->rodata_offset > 0) {
                emit_bytes(cb, (const uint8_t[]){0x48, 0xb8}, 2); // movabs rax, imm64
                size_t patch = cb->size;
                emit_u64(cb, 0);
                add_reloc(patch, s->rodata_offset);
                emit_u8(cb, 0x50); // push rax
            } else if (s) {
                emit_mov_rax_stack(cb, s->stack_offset);
                emit_u8(cb, 0x50); // push rax
            } else {
                compile_expression_recursive(cb, ro, a);
                emit_u8(cb, 0x50); // push rax
            }
        }
    }

    // Pop into Linux x86_64 syscall registers in reverse order:
    // arg 0 is syscall number -> rax
    // arg 1 -> rdi
    // arg 2 -> rsi
    // arg 3 -> rdx
    // arg 4 -> r10 (pop r10: 41 5a)
    // arg 5 -> r8  (pop r8:  41 58)
    // arg 6 -> r9  (pop r9:  41 59, e.g. for SYS_mmap offset argument)
    for (int i = arg_count - 1; i >= 0; i--) {
        switch (i) {
            case 0: emit_u8(cb, 0x58); break; // pop rax (sys_no)
            case 1: emit_u8(cb, 0x5f); break; // pop rdi (arg 1)
            case 2: emit_u8(cb, 0x5e); break; // pop rsi (arg 2)
            case 3: emit_u8(cb, 0x5a); break; // pop rdx (arg 3)
            case 4: emit_bytes(cb, (const uint8_t[]){0x41, 0x5a}, 2); break; // pop r10 (arg 4)
            case 5: emit_bytes(cb, (const uint8_t[]){0x41, 0x58}, 2); break; // pop r8 (arg 5)
            case 6: emit_bytes(cb, (const uint8_t[]){0x41, 0x59}, 2); break; // pop r9 (arg 6)
        }
    }

    emit_bytes(cb, (const uint8_t[]){0x0f, 0x05}, 2); // syscall
}

// User-defined function call emitter (System V AMD64 ABI)
static void emit_function_call(CodeBuffer *cb, RoDataBuffer *ro, const char *call_expr) {
    char copy[4096];
    strncpy(copy, call_expr, sizeof(copy) - 1);
    copy[sizeof(copy) - 1] = '\0';

    char *open_p = strchr(copy, '(');
    if (!open_p) return;
    *open_p = '\0';
    char *func_name = trim(copy);
    char *args_part = open_p + 1;
    char *close_p = find_matching_close_paren(args_part);
    if (close_p) *close_p = '\0';

    if (strcmp(func_name, "সিসকল") == 0 || strcmp(func_name, "syscall") == 0) {
        emit_syscall(cb, ro, call_expr);
        return;
    }

    char args[8][1024];
    int arg_count = parse_call_arguments(args_part, args);

    for (int i = 0; i < arg_count; i++) {
        char *a = args[i];
        if (a[0] == '"' || a[0] == '\'') {
            char q = a[0];
            char str_buf[4096];
            size_t slen = 0;
            const char *p = a + 1;
            parse_escaped_string(&p, q, str_buf, sizeof(str_buf), &slen);
            size_t ro_off = add_rodata(ro, (const uint8_t *)str_buf, slen + 1);
            emit_bytes(cb, (const uint8_t[]){0x48, 0xb8}, 2); // movabs rax, imm64
            size_t patch = cb->size;
            emit_u64(cb, 0);
            add_reloc(patch, ro_off);
            emit_u8(cb, 0x50); // push rax
        } else if (strcmp(a, "বাফার()") == 0 || strcmp(a, "বাফার") == 0 || strcmp(a, "buffer()") == 0 || strcmp(a, "buffer") == 0) {
            emit_bytes(cb, (const uint8_t[]){0x48, 0xb8}, 2); // movabs rax, imm64
            size_t patch = cb->size;
            emit_u64(cb, 0);
            add_bss_reloc(patch, 0);
            emit_u8(cb, 0x50); // push rax
        } else {
            Symbol *s = find_symbol(a);
            if (s && s->is_string && s->rodata_offset > 0) {
                emit_bytes(cb, (const uint8_t[]){0x48, 0xb8}, 2); // movabs rax, imm64
                size_t patch = cb->size;
                emit_u64(cb, 0);
                add_reloc(patch, s->rodata_offset);
                emit_u8(cb, 0x50); // push rax
            } else if (s) {
                emit_mov_rax_stack(cb, s->stack_offset);
                emit_u8(cb, 0x50); // push rax
            } else {
                compile_expression_recursive(cb, ro, a);
                emit_u8(cb, 0x50); // push rax
            }
        }
    }

    for (int i = arg_count - 1; i >= 0; i--) {
        switch (i) {
            case 0: emit_u8(cb, 0x5f); break; // pop rdi
            case 1: emit_u8(cb, 0x5e); break; // pop rsi
            case 2: emit_u8(cb, 0x5a); break; // pop rdx
            case 3: emit_u8(cb, 0x59); break; // pop rcx
            case 4: emit_bytes(cb, (const uint8_t[]){0x41, 0x58}, 2); break; // pop r8
            case 5: emit_bytes(cb, (const uint8_t[]){0x41, 0x59}, 2); break; // pop r9
        }
    }

    emit_u8(cb, 0xe8); // call rel32
    size_t patch_pos = cb->size;
    emit_u32(cb, 0); // placeholder
    add_func_reloc(patch_pos, func_name);
}

// Native Linux Kernel Thread Spawner (মহাদিগন্ত ১০: থ্রেড_চালু / thread_spawn)
// WHY: Spawns an isolated kernel thread with its own stack and clean frame, calls target func(arg), and auto-exits.
static void emit_thread_spawn(CodeBuffer *cb, RoDataBuffer *ro, const char *spawn_expr) {
    char copy[4096];
    strncpy(copy, spawn_expr, sizeof(copy) - 1);
    copy[sizeof(copy) - 1] = '\0';
    char *open_p = strchr(copy, '(');
    if (!open_p) return;
    char *close_p = find_matching_close_paren(open_p + 1);
    if (close_p) *close_p = '\0';

    char args[8][1024];
    int count = parse_call_arguments(open_p + 1, args);
    if (count < 2) return;

    char *func_name = trim(args[0]);
    char *stack_expr = trim(args[1]);
    char *arg_expr = (count >= 3) ? trim(args[2]) : "0";

    // 1. Evaluate arg and push to stack
    compile_expression_recursive(cb, ro, arg_expr);
    emit_u8(cb, 0x50); // push rax (arg)

    // 2. Evaluate stack_top and push to stack
    compile_expression_recursive(cb, ro, stack_expr);
    emit_u8(cb, 0x50); // push rax (stack_top)

    // 3. Pop stack_top into rsi, pop arg into r8
    emit_u8(cb, 0x5e); // pop rsi (stack_top)
    emit_bytes(cb, (const uint8_t[]){0x41, 0x58}, 2); // pop r8 (arg)

    // 4. Align child stack to 16 bytes and store arg at top of child stack
    emit_bytes(cb, (const uint8_t[]){0x48, 0x83, 0xe6, 0xf0}, 4); // and rsi, -16
    emit_bytes(cb, (const uint8_t[]){0x48, 0x83, 0xee, 0x10}, 4); // sub rsi, 16
    emit_bytes(cb, (const uint8_t[]){0x4c, 0x89, 0x06}, 3);       // mov [rsi], r8

    // 5. Setup SYS_clone (56) arguments:
    // rax = 56
    emit_bytes(cb, (const uint8_t[]){0x48, 0xc7, 0xc0, 0x38, 0x00, 0x00, 0x00}, 7);
    // rdi = flags = 69376 (0x10f00: CLONE_VM | CLONE_FS | CLONE_FILES | CLONE_SIGHAND | CLONE_THREAD)
    emit_bytes(cb, (const uint8_t[]){0x48, 0xc7, 0xc7, 0x00, 0x0f, 0x01, 0x00}, 7);
    // rdx = 0 (parent_tid) -> xor rdx, rdx
    emit_bytes(cb, (const uint8_t[]){0x48, 0x31, 0xd2}, 3);
    // r10 = 0 (child_tid) -> xor r10, r10
    emit_bytes(cb, (const uint8_t[]){0x4d, 0x31, 0xd2}, 3);
    // r8 = 0 (tls) -> xor r8, r8
    emit_bytes(cb, (const uint8_t[]){0x4d, 0x31, 0xc0}, 3);
    // syscall
    emit_bytes(cb, (const uint8_t[]){0x0f, 0x05}, 2);

    // 6. Test if child:
    emit_bytes(cb, (const uint8_t[]){0x48, 0x85, 0xc0}, 3); // test rax, rax
    emit_bytes(cb, (const uint8_t[]){0x0f, 0x85}, 2);       // jnz .parent_continue
    size_t parent_jmp_patch = cb->size;
    emit_u32(cb, 0); // placeholder

    // -------------------------------------------------------------
    // CHILD THREAD EXECUTION BLOCK:
    // -------------------------------------------------------------
    emit_u8(cb, 0x5f);                                             // pop rdi (arg)
    emit_bytes(cb, (const uint8_t[]){0x48, 0x31, 0xed}, 3);       // xor rbp, rbp (fresh base frame)
    emit_bytes(cb, (const uint8_t[]){0x48, 0x83, 0xec, 0x08}, 4); // sub rsp, 8 (align 16-byte stack)
    emit_u8(cb, 0xe8);                                             // call rel32 target_fn
    size_t fn_patch = cb->size;
    emit_u32(cb, 0);
    add_func_reloc(fn_patch, func_name);
    emit_bytes(cb, (const uint8_t[]){0x48, 0x83, 0xc4, 0x08}, 4); // add rsp, 8

    // Auto terminate child thread: SYS_exit (60)
    emit_bytes(cb, (const uint8_t[]){0x48, 0x89, 0xc7}, 3);                         // mov rdi, rax
    emit_bytes(cb, (const uint8_t[]){0x48, 0xc7, 0xc0, 0x3c, 0x00, 0x00, 0x00}, 7); // mov rax, 60
    emit_bytes(cb, (const uint8_t[]){0x0f, 0x05}, 2);                               // syscall

    // -------------------------------------------------------------
    // PARENT THREAD CONTINUATION:
    // -------------------------------------------------------------
    int32_t disp = (int32_t)(cb->size - (parent_jmp_patch + 4));
    memcpy(&cb->bytes[parent_jmp_patch], &disp, sizeof(int32_t));
    // RAX now holds child TID in parent thread!
}

// Outermost Parenthesis Stripper: ((a + b)) -> a + b
static char *strip_outer_parens(char *s) {
    s = trim(s);
    while (s[0] == '(' && s[strlen(s) - 1] == ')') {
        int depth = 0;
        bool outer_matches = true;
        for (int i = 0; s[i]; i++) {
            if (s[i] == '(') depth++;
            else if (s[i] == ')') {
                depth--;
                if (depth == 0 && s[i + 1] != '\0') {
                    outer_matches = false;
                    break;
                }
            }
        }
        if (outer_matches) {
            s[strlen(s) - 1] = '\0';
            s = trim(s + 1);
        } else {
            break;
        }
    }
    return s;
}

// 8. Recursive Expression Compiler
static void compile_expression_recursive(CodeBuffer *cb, RoDataBuffer *ro, const char *expr) {
    char copy[4096];
    strncpy(copy, expr, sizeof(copy) - 1);
    copy[sizeof(copy) - 1] = '\0';
    char *s = strip_outer_parens(copy);

    if (strstr(s, "সিপিউ_ক্লক") != NULL || strcmp(s, "rdtsc()") == 0 || strcmp(s, "rdtsc") == 0 || strcmp(s, "clock()") == 0 || strcmp(s, "সাইকেল()") == 0 || strcmp(s, "সাইকেল") == 0) {
        emit_rdtsc(cb, g_current_stack_offset);
        emit_mov_rax_stack(cb, g_current_stack_offset);
        return;
    }

    if (strncmp(s, "সাইজ(", strlen("সাইজ(")) == 0 ||
        strncmp(s, "আকার(", strlen("আকার(")) == 0 ||
        strncmp(s, "sizeof(", 7) == 0) {
        char copy_sz[256];
        strncpy(copy_sz, s, sizeof(copy_sz) - 1);
        copy_sz[sizeof(copy_sz) - 1] = '\0';
        char *open_p = strchr(copy_sz, '(');
        if (open_p) {
            char *close_p = find_matching_close_paren(open_p + 1);
            if (close_p) *close_p = '\0';
            char *type_name = trim(open_p + 1);
            StructDef *sd = find_struct(type_name);
            if (sd) {
                emit_bytes(cb, (const uint8_t[]){0x48, 0xb8}, 2); // mov rax, imm64
                emit_u64(cb, (uint64_t)sd->total_size);
                return;
            }
        }
    }

    if (strncmp(s, "সিসকল(", strlen("সিসকল(")) == 0 || strncmp(s, "syscall(", 8) == 0) {
        emit_syscall(cb, ro, s);
        return;
    }

    // Native Linux Kernel Thread Spawner: থ্রেড_চালু(ফাংশন, স্ট্যাক_টপ, আর্গ) / thread_spawn(fn, stack, arg)
    // WHY: Returns child TID to parent while child executes fn(arg) in an isolated hardware stack.
    if (strncmp(s, "থ্রেড_চালু(", strlen("থ্রেড_চালু(")) == 0 ||
        strncmp(s, "thread_spawn(", 13) == 0) {
        emit_thread_spawn(cb, ro, s);
        return;
    }

    if (strcmp(s, "বাফার()") == 0 || strcmp(s, "বাফার") == 0 || strcmp(s, "buffer()") == 0 || strcmp(s, "buffer") == 0) {
        emit_bytes(cb, (const uint8_t[]){0x48, 0xb8}, 2); // movabs rax, imm64
        size_t patch = cb->size;
        emit_u64(cb, 0);
        add_bss_reloc(patch, 0);
        return;
    }

    if (strncmp(s, "দৈর্ঘ্য(", strlen("দৈর্ঘ্য(")) == 0 || strncmp(s, "len(", 4) == 0) {
        char inner[256] = {0};
        char *start = strchr(s, '(');
        if (start) {
            start++;
            char *end = strrchr(start, ')');
            if (end) *end = '\0';
            strncpy(inner, start, sizeof(inner) - 1);
        }
        compile_expression_recursive(cb, ro, inner);
        emit_runtime_strlen(cb);
        return;
    }

    if (strncmp(s, "মেমরি_পড়ো(", strlen("মেমরি_পড়ো(")) == 0 ||
        strncmp(s, "mem_read(", 9) == 0) {
        char copy[4096];
        strncpy(copy, s, sizeof(copy) - 1);
        copy[sizeof(copy) - 1] = '\0';
        char *open_p = strchr(copy, '(');
        char *close_p = find_matching_close_paren(open_p + 1);
        if (close_p) *close_p = '\0';
        char args[8][1024];
        int count = parse_call_arguments(open_p + 1, args);
        if (count >= 2) {
            compile_expression_recursive(cb, ro, args[0]); // base
            emit_u8(cb, 0x50);                             // push rax
            compile_expression_recursive(cb, ro, args[1]); // offset
            emit_u8(cb, 0x50);                             // push rax
            emit_u8(cb, 0x5e);                             // pop rsi (offset)
            emit_u8(cb, 0x5f);                             // pop rdi (base)
            emit_bytes(cb, (const uint8_t[]){0x48, 0x01, 0xf7}, 3); // add rdi, rsi
            emit_bytes(cb, (const uint8_t[]){0x48, 0x8b, 0x07}, 3); // mov rax, [rdi]
            return;
        }
    }

    if (strncmp(s, "মেমরি_বাইট_পড়ো(", strlen("মেমরি_বাইট_পড়ো(")) == 0 ||
        strncmp(s, "mem_read_byte(", 14) == 0) {
        char copy[4096];
        strncpy(copy, s, sizeof(copy) - 1);
        copy[sizeof(copy) - 1] = '\0';
        char *open_p = strchr(copy, '(');
        char *close_p = find_matching_close_paren(open_p + 1);
        if (close_p) *close_p = '\0';
        char args[8][1024];
        int count = parse_call_arguments(open_p + 1, args);
        if (count >= 2) {
            compile_expression_recursive(cb, ro, args[0]); // base
            emit_u8(cb, 0x50);                             // push rax
            compile_expression_recursive(cb, ro, args[1]); // offset
            emit_u8(cb, 0x50);                             // push rax
            emit_u8(cb, 0x5e);                             // pop rsi (offset)
            emit_u8(cb, 0x5f);                             // pop rdi (base)
            emit_bytes(cb, (const uint8_t[]){0x48, 0x01, 0xf7}, 3);       // add rdi, rsi
            emit_bytes(cb, (const uint8_t[]){0x48, 0x0f, 0xb6, 0x07}, 4); // movzx rax, byte ptr [rdi]
            return;
        }
    }

    if (is_function_call_expr(s)) {
        emit_function_call(cb, ro, s);
        return;
    }

    int len = (int)strlen(s);
    char op = 0;
    int op_idx = -1;
    int paren_depth = 0;
    int bracket_depth = 0;
    bool in_quote = false;
    char qchar = 0;

    for (int i = len - 1; i >= 0; i--) {
        if (!in_quote && (s[i] == '"' || s[i] == '\'')) {
            in_quote = true;
            qchar = s[i];
        } else if (in_quote && s[i] == qchar) {
            if (i == 0 || s[i-1] != '\\') {
                in_quote = false;
            }
        }
        if (in_quote) continue;

        if (s[i] == ')') paren_depth++;
        else if (s[i] == '(') paren_depth--;
        else if (s[i] == ']') bracket_depth++;
        else if (s[i] == '[') bracket_depth--;
        else if (paren_depth == 0 && bracket_depth == 0 && (s[i] == '+' || s[i] == '-') && i > 0 && s[i-1] != '*' && s[i-1] != '/' && s[i-1] != '%' && s[i-1] != '+' && s[i-1] != '-') {
            op = s[i];
            op_idx = i;
            break;
        }
    }

    if (op_idx == -1) {
        paren_depth = 0;
        bracket_depth = 0;
        in_quote = false;
        for (int i = len - 1; i >= 0; i--) {
            if (!in_quote && (s[i] == '"' || s[i] == '\'')) {
                in_quote = true;
                qchar = s[i];
            } else if (in_quote && s[i] == qchar) {
                if (i == 0 || s[i-1] != '\\') {
                    in_quote = false;
                }
            }
            if (in_quote) continue;

            if (s[i] == ')') paren_depth++;
            else if (s[i] == '(') paren_depth--;
            else if (s[i] == ']') bracket_depth++;
            else if (s[i] == '[') bracket_depth--;
            else if (paren_depth == 0 && bracket_depth == 0 && (s[i] == '*' || s[i] == '/' || s[i] == '%')) {
                op = s[i];
                op_idx = i;
                break;
            }
        }
    }

    if (op_idx != -1) {
        s[op_idx] = '\0';
        char *left = trim(s);
        char *right = trim(s + op_idx + 1);

        compile_expression_recursive(cb, ro, left);
        emit_u8(cb, 0x50); // push rax
        compile_expression_recursive(cb, ro, right);
        emit_bytes(cb, (const uint8_t[]){0x48, 0x89, 0xc3}, 3); // mov rbx, rax
        emit_u8(cb, 0x58); // pop rax

        switch (op) {
            case '*': emit_imul_rax_rbx(cb); break;
            case '+': emit_add_rax_rbx(cb); break;
            case '-': emit_sub_rax_rbx(cb); break;
            case '/': emit_idiv_rax_rbx(cb); break;
            case '%': emit_imod_rax_rbx(cb); break;
        }
    } else {
        if (strchr(s, '(') && s[strlen(s) - 1] == ')') {
            emit_function_call(cb, ro, s);
            return;
        }

        // Array indexing expression: target[index] (8-byte word dereference)
        char *open_bracket = strchr(s, '[');
        char *close_bracket = strrchr(s, ']');
        if (open_bracket && close_bracket && close_bracket == (s + strlen(s) - 1) && close_bracket > open_bracket) {
            char target_part[512] = {0};
            char index_part[512] = {0};
            size_t t_len = (size_t)(open_bracket - s);
            if (t_len < sizeof(target_part)) {
                strncpy(target_part, s, t_len);
                target_part[t_len] = '\0';
                size_t i_len = (size_t)(close_bracket - (open_bracket + 1));
                if (i_len < sizeof(index_part)) {
                    strncpy(index_part, open_bracket + 1, i_len);
                    index_part[i_len] = '\0';
                    compile_expression_recursive(cb, ro, trim(target_part));
                    emit_u8(cb, 0x50); // push rax (base)
                    compile_expression_recursive(cb, ro, trim(index_part));
                    emit_u8(cb, 0x50); // push rax (index)
                    emit_u8(cb, 0x58); // pop rax (index)
                    emit_u8(cb, 0x5f); // pop rdi (base)
                    emit_bytes(cb, (const uint8_t[]){0x48, 0xc1, 0xe0, 0x03}, 4); // shl rax, 3
                    emit_bytes(cb, (const uint8_t[]){0x48, 0x01, 0xc7}, 3);       // add rdi, rax
                    emit_bytes(cb, (const uint8_t[]){0x48, 0x8b, 0x07}, 3);       // mov rax, [rdi]
                    return;
                }
            }
        }

        // Struct field access expression: target.field (e.g. রহিম.বয়স)
        // WHY: Computes base object memory address, offsets by struct field displacement, and dereferences 64-bit value.
        char *dot = strchr(s, '.');
        if (dot && dot != s && *(dot + 1) != '\0' && !is_numeric_str(s)) {
            char target_part[512] = {0};
            char field_part[512] = {0};
            size_t t_len = (size_t)(dot - s);
            if (t_len < sizeof(target_part)) {
                strncpy(target_part, s, t_len);
                target_part[t_len] = '\0';
                strncpy(field_part, dot + 1, sizeof(field_part) - 1);
                field_part[sizeof(field_part) - 1] = '\0';
                char *target_trim = trim(target_part);
                char *field_trim = trim(field_part);

                int offset = -1;
                Symbol *sym = find_symbol(target_trim);
                if (sym && sym->struct_type[0] != '\0') {
                    offset = find_struct_field_offset_in(sym->struct_type, field_trim);
                }
                if (offset < 0) {
                    offset = find_struct_field_offset(field_trim);
                }

                if (offset >= 0) {
                    compile_expression_recursive(cb, ro, target_trim);
                    emit_bytes(cb, (const uint8_t[]){0x48, 0x89, 0xc7}, 3); // mov rdi, rax
                    if (offset > 0) {
                        emit_bytes(cb, (const uint8_t[]){0x48, 0x81, 0xc7}, 3); // add rdi, imm32
                        emit_u32(cb, (uint32_t)offset);
                    }
                    emit_bytes(cb, (const uint8_t[]){0x48, 0x8b, 0x07}, 3); // mov rax, [rdi]
                    return;
                }
            }
        }

        if (s[0] == '"' || s[0] == '\'') {
            char q = s[0];
            char str_buf[4096];
            size_t slen = 0;
            const char *p = s + 1;
            parse_escaped_string(&p, q, str_buf, sizeof(str_buf), &slen);
            size_t ro_off = add_rodata(ro, (const uint8_t *)str_buf, slen + 1);
            emit_bytes(cb, (const uint8_t[]){0x48, 0xb8}, 2); // movabs rax, imm64
            size_t patch = cb->size;
            emit_u64(cb, 0);
            add_reloc(patch, ro_off);
            return;
        }

        Symbol *sym = find_symbol(s);
        if (sym) {
            if (sym->is_string && sym->rodata_offset > 0) {
                emit_bytes(cb, (const uint8_t[]){0x48, 0xb8}, 2); // movabs rax, imm64
                size_t patch = cb->size;
                emit_u64(cb, 0);
                add_reloc(patch, sym->rodata_offset);
            } else {
                emit_mov_rax_stack(cb, sym->stack_offset);
            }
        } else {
            int64_t num = parse_bangla_number(s);
            emit_bytes(cb, (const uint8_t[]){0x48, 0xb8}, 2); // mov rax, imm64
            emit_u64(cb, (uint64_t)num);
        }
    }
}

// 9. Multi-File Import Resolver
static bool load_source_with_imports(const char *filepath, char *out_buf, size_t max_size, char visited[64][256], int *visited_count) {
    for (int i = 0; i < *visited_count; i++) {
        if (strcmp(visited[i], filepath) == 0) return true;
    }
    if (*visited_count < 64) {
        strncpy(visited[(*visited_count)++], filepath, 255);
    }

    FILE *f = fopen(filepath, "rb");
    if (!f) return false;

    char line[1024];
    while (fgets(line, sizeof(line), f)) {
        char line_copy[1024];
        strncpy(line_copy, line, sizeof(line_copy) - 1);
        line_copy[sizeof(line_copy) - 1] = '\0';
        char *trimmed = trim(line_copy);
        if (strncmp(trimmed, "অন্তর্ভুক্ত", strlen("অন্তর্ভুক্ত")) == 0 || strncmp(trimmed, "import", 6) == 0) {
            char *quote_start = strchr(trimmed, '"');
            if (quote_start) {
                quote_start++;
                char *quote_end = strchr(quote_start, '"');
                if (quote_end) {
                    *quote_end = '\0';
                    load_source_with_imports(quote_start, out_buf, max_size, visited, visited_count);
                    continue;
                }
            }
        }
        size_t cur_len = strlen(out_buf);
        size_t add_len = strlen(line);
        if (cur_len + add_len + 2 < max_size) {
            strcat(out_buf, line);
            if (line[add_len - 1] != '\n') {
                strcat(out_buf, "\n");
            }
        }
    }
    fclose(f);
    return true;
}

// 10. 64-bit Linux ELF Header structures
#pragma pack(push, 1)
typedef struct {
    unsigned char e_ident[16];
    uint16_t      e_type;
    uint16_t      e_machine;
    uint32_t      e_version;
    uint64_t      e_entry;
    uint64_t      e_phoff;
    uint64_t      e_shoff;
    uint32_t      e_flags;
    uint16_t      e_ehsize;
    uint16_t      e_phentsize;
    uint16_t      e_phnum;
    uint16_t      e_shentsize;
    uint16_t      e_shnum;
    uint16_t      e_shstrndx;
} Elf64_Ehdr;

typedef struct {
    uint32_t p_type;
    uint32_t p_flags;
    uint64_t p_offset;
    uint64_t p_vaddr;
    uint64_t p_paddr;
    uint64_t p_filesz;
    uint64_t p_memsz;
    uint64_t p_align;
} Elf64_Phdr;
#pragma pack(pop)

typedef enum {
    BLOCK_IF,
    BLOCK_WHILE,
    BLOCK_FUNC
} BlockType;

typedef struct {
    BlockType type;
    size_t loop_start;
    size_t else_jump_patch;
    size_t endif_jump_patch;
    bool has_else;
} BlockRecord;

static BlockRecord g_blocks[MAX_BLOCKS];
static int g_block_depth = 0;

void print_banner(void) {
    printf("\033[38;2;0;255;204m╔════════════════════════════════════════════════════════════════════════╗\033[0m\n");
    printf("\033[38;2;0;255;204m║\033[0m  \033[1;38;2;255;255;255m👑 LIPIC — 100%% NATIVE STANDALONE LIPI COMPILER (ZERO PHP / ZERO GCC)\033[0m \033[38;2;0;255;204m║\033[0m\n");
    printf("\033[38;2;0;255;204m║\033[0m  \033[38;2;180;180;180m⚡ Direct Linux ELF 64-bit Machine Code Generation | Pure Silicon Engine\033[0m\033[38;2;0;255;204m║\033[0m\n");
    printf("\033[38;2;0;255;204m╚════════════════════════════════════════════════════════════════════════╝\033[0m\n\n");
}

int run_repl(void);
int run_tests(void);
static int run_formatter(int argc, char *argv[]);

// Compile statement in active context
static void compile_statement(CodeBuffer *cb, RoDataBuffer *ro, char *trimmed) {
    // Strip trailing semicolons if present for flexible statement termination
    size_t tlen = strlen(trimmed);
    if (tlen > 0 && trimmed[tlen - 1] == ';') {
        trimmed[tlen - 1] = '\0';
        trimmed = trim(trimmed);
    }

    const size_t len_dhori = strlen("ধরি");
    const size_t len_dekhao = strlen("দেখাও");
    const size_t len_jodi = strlen("যদি");
    const size_t len_nahole = strlen("নাহলে");
    const size_t len_onnothay = strlen("অন্যথায়");
    const size_t len_jotokkhon = strlen("যতক্ষণ");
    const size_t len_ferot = strlen("ফেরত");

    // 1. Closing brace '}'
    if (trimmed[0] == '}') {
        char *after_brace = trim(trimmed + 1);
        if (g_block_depth > 0) {
            BlockRecord *blk = &g_blocks[g_block_depth - 1];
            if (blk->type == BLOCK_WHILE) {
                emit_u8(cb, 0xe9); // jmp rel32
                int32_t loop_disp = (int32_t)(blk->loop_start - (cb->size + 4));
                emit_u32(cb, (uint32_t)loop_disp);
                int32_t exit_disp = (int32_t)(cb->size - (blk->else_jump_patch + 4));
                memcpy(&cb->bytes[blk->else_jump_patch], &exit_disp, sizeof(int32_t));
                g_block_depth--;
            } else if (blk->type == BLOCK_IF) {
                if (blk->has_else) {
                    int32_t disp = (int32_t)(cb->size - (blk->endif_jump_patch + 4));
                    memcpy(&cb->bytes[blk->endif_jump_patch], &disp, sizeof(int32_t));
                    g_block_depth--;
                } else if (*after_brace == '\0') {
                    int32_t disp = (int32_t)(cb->size - (blk->else_jump_patch + 4));
                    memcpy(&cb->bytes[blk->else_jump_patch], &disp, sizeof(int32_t));
                    g_block_depth--;
                }
            } else if (blk->type == BLOCK_FUNC) {
                emit_func_epilogue(cb);
                g_active_scope[0] = '\0';
                g_current_stack_offset = -8;
                g_block_depth--;
            }
        }
        if (*after_brace == '\0') return;
        trimmed = after_brace;
    }

    // 2. Return statement: ফেরত <expr> / return <expr>
    bool is_ferot  = (strncmp(trimmed, "ফেরত", len_ferot) == 0 && (trimmed[len_ferot] == ' ' || trimmed[len_ferot] == '\t'));
    bool is_return = (strncmp(trimmed, "return", 6) == 0 && (trimmed[6] == ' ' || trimmed[6] == '\t'));
    if (is_ferot || is_return) {
        size_t pfx = is_ferot ? len_ferot : 6;
        char *expr = trim(trimmed + pfx);
        compile_expression_recursive(cb, ro, expr);
        emit_func_epilogue(cb);
        return;
    }

    // 3. 'নাহলে {' / 'অন্যথায় {' / 'else {'
    bool is_nahole = (strncmp(trimmed, "নাহলে", len_nahole) == 0 && (trimmed[len_nahole] == ' ' || trimmed[len_nahole] == '{' || trimmed[len_nahole] == '\0'));
    bool is_onnothay = (strncmp(trimmed, "অন্যথায়", len_onnothay) == 0 && (trimmed[len_onnothay] == ' ' || trimmed[len_onnothay] == '{' || trimmed[len_onnothay] == '\0'));
    bool is_else = (strncmp(trimmed, "else", 4) == 0 && (trimmed[4] == ' ' || trimmed[4] == '{' || trimmed[4] == '\0'));
    if (is_nahole || is_onnothay || is_else) {
        if (g_block_depth > 0 && g_blocks[g_block_depth - 1].type == BLOCK_IF) {
            emit_u8(cb, 0xe9); // jmp rel32 to skip else block
            size_t jmp_patch = cb->size;
            emit_u32(cb, 0);
            g_blocks[g_block_depth - 1].endif_jump_patch = jmp_patch;
            g_blocks[g_block_depth - 1].has_else = true;

            size_t else_patch = g_blocks[g_block_depth - 1].else_jump_patch;
            int32_t disp = (int32_t)(cb->size - (else_patch + 4));
            memcpy(&cb->bytes[else_patch], &disp, sizeof(int32_t));
        }
        return;
    }

    // 4. Loops: যতক্ষণ <cond> { / while <cond> {
    bool is_jotokkhon = (strncmp(trimmed, "যতক্ষণ", len_jotokkhon) == 0 && (trimmed[len_jotokkhon] == ' ' || trimmed[len_jotokkhon] == '\t'));
    bool is_while     = (strncmp(trimmed, "while", 5) == 0 && (trimmed[5] == ' ' || trimmed[5] == '\t'));
    if (is_jotokkhon || is_while) {
        size_t pfx = is_jotokkhon ? len_jotokkhon : 5;
        char *cond_part = trim(trimmed + pfx);
        char *brace = strchr(cond_part, '{');
        if (brace) *brace = '\0';
        cond_part = strip_outer_parens(cond_part);

        size_t loop_start = cb->size;

        char *op = NULL;
        int op_type = 0;
        if ((op = strstr(cond_part, ">=")) != NULL) { op_type = 3; *op = '\0'; op += 2; }
        else if ((op = strstr(cond_part, "<=")) != NULL) { op_type = 4; *op = '\0'; op += 2; }
        else if ((op = strstr(cond_part, "==")) != NULL) { op_type = 5; *op = '\0'; op += 2; }
        else if ((op = strstr(cond_part, "!=")) != NULL) { op_type = 6; *op = '\0'; op += 2; }
        else if ((op = strchr(cond_part, '>')) != NULL) { op_type = 1; *op = '\0'; op += 1; }
        else if ((op = strchr(cond_part, '<')) != NULL) { op_type = 2; *op = '\0'; op += 1; }

        char *left = trim(cond_part);
        char *right = op ? trim(op) : NULL;

        compile_expression_recursive(cb, ro, left);
        if (right) {
            emit_u8(cb, 0x50);
            compile_expression_recursive(cb, ro, right);
            emit_bytes(cb, (const uint8_t[]){0x48, 0x89, 0xc3}, 3);
            emit_u8(cb, 0x58);
        } else {
            emit_mov_rbx_imm64(cb, 0);
        }

        emit_bytes(cb, (const uint8_t[]){0x48, 0x39, 0xd8}, 3); // cmp rax, rbx

        uint8_t jcc[2] = {0x0f, 0x8e};
        switch (op_type) {
            case 1: jcc[1] = 0x8e; break; // jle
            case 2: jcc[1] = 0x8d; break; // jge
            case 3: jcc[1] = 0x8c; break; // jl
            case 4: jcc[1] = 0x8f; break; // jg
            case 5: jcc[1] = 0x85; break; // jne
            case 6: jcc[1] = 0x84; break; // je
            default: jcc[1] = 0x8e; break;
        }
        emit_bytes(cb, jcc, 2);
        size_t exit_patch = cb->size;
        emit_u32(cb, 0);

        if (g_block_depth < MAX_BLOCKS) {
            g_blocks[g_block_depth].type = BLOCK_WHILE;
            g_blocks[g_block_depth].loop_start = loop_start;
            g_blocks[g_block_depth].else_jump_patch = exit_patch;
            g_blocks[g_block_depth].endif_jump_patch = 0;
            g_blocks[g_block_depth].has_else = false;
            g_block_depth++;
        }
        return;
    }

    // 5. Conditional: যদি <cond> { / if <cond> {
    bool is_jodi = (strncmp(trimmed, "যদি", len_jodi) == 0 && (trimmed[len_jodi] == ' ' || trimmed[len_jodi] == '\t'));
    bool is_if   = (strncmp(trimmed, "if", 2) == 0 && (trimmed[2] == ' ' || trimmed[2] == '\t'));
    if (is_jodi || is_if) {
        size_t pfx = is_jodi ? len_jodi : 2;
        char *cond_part = trim(trimmed + pfx);
        char *brace = strchr(cond_part, '{');
        if (brace) *brace = '\0';
        cond_part = strip_outer_parens(cond_part);

        char *op = NULL;
        int op_type = 0;
        if ((op = strstr(cond_part, ">=")) != NULL) { op_type = 3; *op = '\0'; op += 2; }
        else if ((op = strstr(cond_part, "<=")) != NULL) { op_type = 4; *op = '\0'; op += 2; }
        else if ((op = strstr(cond_part, "==")) != NULL) { op_type = 5; *op = '\0'; op += 2; }
        else if ((op = strstr(cond_part, "!=")) != NULL) { op_type = 6; *op = '\0'; op += 2; }
        else if ((op = strchr(cond_part, '>')) != NULL) { op_type = 1; *op = '\0'; op += 1; }
        else if ((op = strchr(cond_part, '<')) != NULL) { op_type = 2; *op = '\0'; op += 1; }

        char *left = trim(cond_part);
        char *right = op ? trim(op) : NULL;

        compile_expression_recursive(cb, ro, left);
        if (right) {
            emit_u8(cb, 0x50);
            compile_expression_recursive(cb, ro, right);
            emit_bytes(cb, (const uint8_t[]){0x48, 0x89, 0xc3}, 3);
            emit_u8(cb, 0x58);
        } else {
            emit_mov_rbx_imm64(cb, 0);
        }

        emit_bytes(cb, (const uint8_t[]){0x48, 0x39, 0xd8}, 3);

        uint8_t jcc[2] = {0x0f, 0x8e};
        switch (op_type) {
            case 1: jcc[1] = 0x8e; break;
            case 2: jcc[1] = 0x8d; break;
            case 3: jcc[1] = 0x8c; break;
            case 4: jcc[1] = 0x8f; break;
            case 5: jcc[1] = 0x85; break;
            case 6: jcc[1] = 0x84; break;
            default: jcc[1] = 0x8e; break;
        }
        emit_bytes(cb, jcc, 2);
        size_t patch_pos = cb->size;
        emit_u32(cb, 0);

        if (g_block_depth < MAX_BLOCKS) {
            g_blocks[g_block_depth].type = BLOCK_IF;
            g_blocks[g_block_depth].loop_start = 0;
            g_blocks[g_block_depth].else_jump_patch = patch_pos;
            g_blocks[g_block_depth].endif_jump_patch = 0;
            g_blocks[g_block_depth].has_else = false;
            g_block_depth++;
        }
        return;
    }

    // Custom Struct Variable Declaration: <StructType> <var_name> (e.g. মানুষ রহিম)
    // WHY: Provides strongly-typed composite struct variable declarations directly bound to memory.
    char stmt_copy[256];
    strncpy(stmt_copy, trimmed, sizeof(stmt_copy) - 1);
    stmt_copy[sizeof(stmt_copy) - 1] = '\0';
    char *first_space = strchr(stmt_copy, ' ');
    if (!first_space) first_space = strchr(stmt_copy, '\t');
    if (first_space) {
        *first_space = '\0';
        char *type_cand = trim(stmt_copy);
        char *var_cand = trim(first_space + 1);
        StructDef *sd_cand = find_struct(type_cand);
        if (sd_cand && *var_cand != '\0' && !strchr(var_cand, '(') && !strchr(var_cand, '=')) {
            Symbol *s = add_symbol(var_cand);
            if (s) {
                snprintf(s->struct_type, sizeof(s->struct_type), "%s", sd_cand->name);
                emit_mov_stack_imm(cb, s->stack_offset, 0);
            }
            return;
        }
    }

    // 6. Variable declaration: ধরি <name> = <expr> / let <name> = <expr>
    bool is_dhori = (strncmp(trimmed, "ধরি", len_dhori) == 0 && (trimmed[len_dhori] == ' ' || trimmed[len_dhori] == '\t'));
    bool is_let   = (strncmp(trimmed, "let", 3) == 0 && (trimmed[3] == ' ' || trimmed[3] == '\t'));
    if (is_dhori || is_let) {
        size_t pfx = is_dhori ? len_dhori : 3;
        char *eq = strchr(trimmed + pfx, '=');
        if (eq) {
            *eq = '\0';
            char *var_name = trim(trimmed + pfx);
            char *expr = trim(eq + 1);

            Symbol *sym = add_symbol(var_name);
            if (sym) {
                if (*expr == '"' || *expr == '\'') {
                    char quote = *expr++;
                    char str_buf[4096];
                    size_t s_len = 0;
                    const char *p = expr;
                    parse_escaped_string(&p, quote, str_buf, sizeof(str_buf), &s_len);
                    sym->is_string = true;
                    sym->rodata_offset = add_rodata(ro, (const uint8_t *)str_buf, s_len + 1);
                    sym->string_len = s_len;
                    sym->is_initialized = true;
                } else if (is_numeric_str(expr)) {
                    int64_t val = parse_bangla_number(expr);
                    sym->const_val = val;
                    sym->is_initialized = true;
                    sym->is_string = false;
                    emit_mov_stack_imm(cb, sym->stack_offset, (int32_t)val);
                } else {
                    compile_expression_recursive(cb, ro, expr);
                    emit_mov_stack_rax(cb, sym->stack_offset);
                    sym->is_initialized = true;
                    sym->is_string = false;

                    // Automatically infer struct type from sizeof/size expression
                    char *sz = strstr(expr, "সাইজ(");
                    if (!sz) sz = strstr(expr, "আকার(");
                    if (!sz) sz = strstr(expr, "sizeof(");
                    if (sz) {
                        char *op = strchr(sz, '(');
                        char *cp = op ? strchr(op, ')') : NULL;
                        if (op && cp && cp > op + 1) {
                            char tname[64] = {0};
                            size_t tlen = cp - (op + 1);
                            if (tlen < sizeof(tname)) {
                                strncpy(tname, op + 1, tlen);
                                strncpy(sym->struct_type, trim(tname), 63);
                            }
                        }
                    }
                }
            }
        }
        return;
    }

    // 7. Show statement: দেখাও <expr> / show <expr>
    bool is_dekhao = (strncmp(trimmed, "দেখাও", len_dekhao) == 0 && (trimmed[len_dekhao] == ' ' || trimmed[len_dekhao] == '\0' || trimmed[len_dekhao] == '\t'));
    bool is_show   = (strncmp(trimmed, "show", 4) == 0 && (trimmed[4] == ' ' || trimmed[4] == '\0' || trimmed[4] == '\t'));
    if (is_dekhao || is_show) {
        size_t pfx = is_dekhao ? len_dekhao : 4;
        char *expr = trim(trimmed + pfx);

        const char *p = expr;
        while (*p) {
            while (isspace((unsigned char)*p) || *p == '+') p++;
            if (!*p) break;

            if (*p == '"' || *p == '\'') {
                char quote = *p++;
                char str_buf[4096];
                size_t s_len = 0;
                parse_escaped_string(&p, quote, str_buf, sizeof(str_buf), &s_len);
                emit_print_static_string(cb, ro, str_buf, s_len);
                continue;
            }

            char token[256];
            int tlen = 0;
            int paren_count = 0;
            int bracket_count = 0;
            while (*p) {
                if (*p == '(') paren_count++;
                else if (*p == ')') paren_count--;
                else if (*p == '[') bracket_count++;
                else if (*p == ']') bracket_count--;
                if (paren_count == 0 && bracket_count == 0 && (isspace((unsigned char)*p) || *p == '+' || *p == '"' || *p == '\'' || *p == ';')) {
                    break;
                }
                if (tlen < (int)sizeof(token) - 1) token[tlen++] = *p;
                p++;
            }
            token[tlen] = '\0';
            if (tlen == 0) continue;

            if (strncmp(token, "বাংলা_সংখ্যা(", strlen("বাংলা_সংখ্যা(")) == 0 ||
                strncmp(token, "to_bangla(", strlen("to_bangla(")) == 0) {
                char inner[128] = {0};
                char *start = strchr(token, '(');
                if (start) {
                    start++;
                    char *end = strrchr(start, ')');
                    if (end) *end = '\0';
                    strncpy(inner, start, sizeof(inner) - 1);
                }
                compile_expression_recursive(cb, ro, inner);
                emit_runtime_print_bangla_num(cb, false);
                continue;
            }

            if (strncmp(token, "লেখা(", strlen("লেখা(")) == 0 ||
                strncmp(token, "স্ট্রিং(", strlen("স্ট্রিং(")) == 0 ||
                strncmp(token, "str(", 4) == 0) {
                char inner[128] = {0};
                char *start = strchr(token, '(');
                if (start) {
                    start++;
                    char *end = strrchr(start, ')');
                    if (end) *end = '\0';
                    strncpy(inner, start, sizeof(inner) - 1);
                }
                compile_expression_recursive(cb, ro, inner);
                emit_runtime_print_cstr(cb);
                continue;
            }

            if ((strchr(token, '(') && token[strlen(token) - 1] == ')') ||
                (strchr(token, '[') && token[strlen(token) - 1] == ']') ||
                (strchr(token, '.') && !is_numeric_str(token))) {
                compile_expression_recursive(cb, ro, token);
                emit_runtime_print_bangla_num(cb, false);
                continue;
            }

            Symbol *sym = find_symbol(token);
            if (sym) {
                if (sym->is_string) {
                    if (sym->rodata_offset > 0) {
                        emit_print_rodata_slice(cb, sym->rodata_offset, sym->string_len);
                    } else {
                        emit_mov_rax_stack(cb, sym->stack_offset);
                        emit_runtime_print_cstr(cb);
                    }
                } else {
                    emit_mov_rax_stack(cb, sym->stack_offset);
                    emit_runtime_print_bangla_num(cb, false);
                }
                continue;
            } else if (is_numeric_str(token)) {
                int64_t n = parse_bangla_number(token);
                emit_bytes(cb, (const uint8_t[]){0x48, 0xb8}, 2);
                emit_u64(cb, (uint64_t)n);
                emit_runtime_print_bangla_num(cb, false);
            }
        }

        emit_print_static_string(cb, ro, "\n", 1);
        return;
    }

    // Direct Memory Write Statement: মেমরি_লেখো(বেস, অফসেট, মান) / mem_write(base, offset, val)
    if (strncmp(trimmed, "মেমরি_লেখো(", strlen("মেমরি_লেখো(")) == 0 ||
        strncmp(trimmed, "mem_write(", 10) == 0) {
        char copy[4096];
        strncpy(copy, trimmed, sizeof(copy) - 1);
        copy[sizeof(copy) - 1] = '\0';
        char *open_p = strchr(copy, '(');
        char *close_p = find_matching_close_paren(open_p + 1);
        if (close_p) *close_p = '\0';
        char args[8][1024];
        int count = parse_call_arguments(open_p + 1, args);
        if (count >= 3) {
            compile_expression_recursive(cb, ro, args[0]); // base
            emit_u8(cb, 0x50);                             // push rax
            compile_expression_recursive(cb, ro, args[1]); // offset
            emit_u8(cb, 0x50);                             // push rax
            compile_expression_recursive(cb, ro, args[2]); // val
            emit_u8(cb, 0x50);                             // push rax
            emit_u8(cb, 0x5a);                             // pop rdx (val)
            emit_u8(cb, 0x5e);                             // pop rsi (offset)
            emit_u8(cb, 0x5f);                             // pop rdi (base)
            emit_bytes(cb, (const uint8_t[]){0x48, 0x01, 0xf7}, 3); // add rdi, rsi
            emit_bytes(cb, (const uint8_t[]){0x48, 0x89, 0x17}, 3); // mov [rdi], rdx
            return;
        }
    }

    // Direct Memory Byte Write Statement: মেমরি_বাইট_লেখো(বেস, অফসেট, মান) / mem_write_byte(base, offset, val)
    if (strncmp(trimmed, "মেমরি_বাইট_লেখো(", strlen("মেমরি_বাইট_লেখো(")) == 0 ||
        strncmp(trimmed, "mem_write_byte(", 15) == 0) {
        char copy[4096];
        strncpy(copy, trimmed, sizeof(copy) - 1);
        copy[sizeof(copy) - 1] = '\0';
        char *open_p = strchr(copy, '(');
        char *close_p = find_matching_close_paren(open_p + 1);
        if (close_p) *close_p = '\0';
        char args[8][1024];
        int count = parse_call_arguments(open_p + 1, args);
        if (count >= 3) {
            compile_expression_recursive(cb, ro, args[0]); // base
            emit_u8(cb, 0x50);                             // push rax
            compile_expression_recursive(cb, ro, args[1]); // offset
            emit_u8(cb, 0x50);                             // push rax
            compile_expression_recursive(cb, ro, args[2]); // val
            emit_u8(cb, 0x50);                             // push rax
            emit_u8(cb, 0x5a);                             // pop rdx (val)
            emit_u8(cb, 0x5e);                             // pop rsi (offset)
            emit_u8(cb, 0x5f);                             // pop rdi (base)
            emit_bytes(cb, (const uint8_t[]){0x48, 0x01, 0xf7}, 3); // add rdi, rsi
            emit_bytes(cb, (const uint8_t[]){0x88, 0x17}, 2);       // mov byte ptr [rdi], dl
            return;
        }
    }

    // SIMD 128-bit Vector Addition Statement: ভেক্টর_যোগ_১২৮(গন্তব্য, উৎস) / simd_add128(dst, src)
    // WHY: Directly emits x86_64 SSE2 vector instructions to perform 128-bit parallel arithmetic.
    // Loads two 64-bit integers simultaneously into xmm1 from [src], two 64-bit integers into xmm0
    // from [dst], performs parallel vector addition with paddq in 1 silicon CPU cycle, and writes back.
    if (strncmp(trimmed, "ভেক্টর_যোগ_১২৮(", strlen("ভেক্টর_যোগ_১২৮(")) == 0 ||
        strncmp(trimmed, "simd_add128(", 12) == 0) {
        char copy[4096];
        strncpy(copy, trimmed, sizeof(copy) - 1);
        copy[sizeof(copy) - 1] = '\0';
        char *open_p = strchr(copy, '(');
        char *close_p = find_matching_close_paren(open_p + 1);
        if (close_p) *close_p = '\0';
        char args[8][1024];
        int count = parse_call_arguments(open_p + 1, args);
        if (count >= 2) {
            compile_expression_recursive(cb, ro, args[0]); // dst address
            emit_u8(cb, 0x50);                             // push rax
            compile_expression_recursive(cb, ro, args[1]); // src address
            emit_u8(cb, 0x50);                             // push rax
            emit_u8(cb, 0x5e);                             // pop rsi (src)
            emit_u8(cb, 0x5f);                             // pop rdi (dst)

            // movdqu xmm1, [rsi] -> f3 0f 6f 0e (load 128-bit vector from src)
            emit_bytes(cb, (const uint8_t[]){0xf3, 0x0f, 0x6f, 0x0e}, 4);
            // movdqu xmm0, [rdi] -> f3 0f 6f 07 (load 128-bit vector from dst)
            emit_bytes(cb, (const uint8_t[]){0xf3, 0x0f, 0x6f, 0x07}, 4);
            // paddq xmm0, xmm1   -> 66 0f d4 c1 (parallel SIMD addition of two 64-bit elements)
            emit_bytes(cb, (const uint8_t[]){0x66, 0x0f, 0xd4, 0xc1}, 4);
            // movdqu [rdi], xmm0 -> f3 0f 7f 07 (store 128-bit result back to dst)
            emit_bytes(cb, (const uint8_t[]){0xf3, 0x0f, 0x7f, 0x07}, 4);
            return;
        }
    }

    // 8. Direct Linux Kernel Syscall Statement: সিসকল(...) / syscall(...)
    if (strncmp(trimmed, "সিসকল(", strlen("সিসকল(")) == 0 || strncmp(trimmed, "syscall(", 8) == 0) {
        emit_syscall(cb, ro, trimmed);
        return;
    }

    // Native Kernel Thread Spawn Statement: থ্রেড_চালু(...) / thread_spawn(...)
    if (strncmp(trimmed, "থ্রেড_চালু(", strlen("থ্রেড_চালু(")) == 0 ||
        strncmp(trimmed, "thread_spawn(", 13) == 0) {
        emit_thread_spawn(cb, ro, trimmed);
        return;
    }

    // 9. Function invocation statement
    if (is_function_call_expr(trimmed)) {
        emit_function_call(cb, ro, trimmed);
        return;
    }

    // 10. Variable / Array Indexed / Struct Field Reassignment: <target>[<index>] = <expr> OR <target>.<field> = <expr> OR <var> = <expr>
    char *eq = strchr(trimmed, '=');
    if (eq && eq > trimmed && *(eq - 1) != '!' && *(eq - 1) != '=' && *(eq - 1) != '<' && *(eq - 1) != '>') {
        *eq = '\0';
        char *lhs = trim(trimmed);
        char *rhs = trim(eq + 1);

        char *open_br = strchr(lhs, '[');
        char *close_br = strrchr(lhs, ']');
        if (open_br && close_br && close_br > open_br && *(close_br + 1) == '\0') {
            *open_br = '\0';
            char *target_expr = trim(lhs);
            *close_br = '\0';
            char *index_expr = trim(open_br + 1);

            compile_expression_recursive(cb, ro, target_expr);
            emit_u8(cb, 0x50); // push rax (base)
            compile_expression_recursive(cb, ro, index_expr);
            emit_u8(cb, 0x50); // push rax (index)
            compile_expression_recursive(cb, ro, rhs);
            emit_u8(cb, 0x50); // push rax (val)

            emit_u8(cb, 0x5a); // pop rdx (val)
            emit_u8(cb, 0x58); // pop rax (index)
            emit_u8(cb, 0x5f); // pop rdi (base)

            emit_bytes(cb, (const uint8_t[]){0x48, 0xc1, 0xe0, 0x03}, 4); // shl rax, 3
            emit_bytes(cb, (const uint8_t[]){0x48, 0x01, 0xc7}, 3);       // add rdi, rax
            emit_bytes(cb, (const uint8_t[]){0x48, 0x89, 0x17}, 3);       // mov [rdi], rdx
            return;
        }

        // Struct field assignment: target.field = expr (e.g. রহিম.বয়স = ২৫)
        // WHY: Resolves named field offset in custom struct layout and writes 64-bit value directly to memory.
        char *dot = strchr(lhs, '.');
        if (dot && dot != lhs && *(dot + 1) != '\0') {
            *dot = '\0';
            char *target_expr = trim(lhs);
            char *field_name = trim(dot + 1);

            int offset = -1;
            Symbol *sym = find_symbol(target_expr);
            if (sym && sym->struct_type[0] != '\0') {
                offset = find_struct_field_offset_in(sym->struct_type, field_name);
            }
            if (offset < 0) {
                offset = find_struct_field_offset(field_name);
            }

            if (offset >= 0) {
                compile_expression_recursive(cb, ro, target_expr);
                emit_u8(cb, 0x50); // push rax (base)
                compile_expression_recursive(cb, ro, rhs);
                emit_u8(cb, 0x50); // push rax (val)

                emit_u8(cb, 0x5a); // pop rdx (val)
                emit_u8(cb, 0x5f); // pop rdi (base)

                if (offset > 0) {
                    emit_bytes(cb, (const uint8_t[]){0x48, 0x81, 0xc7}, 3); // add rdi, imm32
                    emit_u32(cb, (uint32_t)offset);
                }
                emit_bytes(cb, (const uint8_t[]){0x48, 0x89, 0x17}, 3); // mov [rdi], rdx
                return;
            }
            *dot = '.'; // restore dot if not a struct field
        }

        Symbol *sym = find_symbol(lhs);
        if (sym) {
            if (is_numeric_str(rhs)) {
                int64_t val = parse_bangla_number(rhs);
                sym->const_val = val;
                emit_mov_stack_imm(cb, sym->stack_offset, (int32_t)val);
            } else {
                compile_expression_recursive(cb, ro, rhs);
                emit_mov_stack_rax(cb, sym->stack_offset);
            }
            return;
        }
        *eq = '=';
    }
}

int main(int argc, char *argv[]) {
    if (argc >= 2 && strcmp(argv[1], "repl") == 0) {
        return run_repl();
    }

    if (argc >= 2 && strcmp(argv[1], "test") == 0) {
        return run_tests();
    }

    if (argc >= 2 && (strcmp(argv[1], "fmt") == 0 || strcmp(argv[1], "format") == 0)) {
        return run_formatter(argc, argv);
    }

    if (argc < 2 || strcmp(argv[1], "help") == 0 || strcmp(argv[1], "--help") == 0 || strcmp(argv[1], "-h") == 0) {
        print_banner();
        printf("\033[1;33mব্যবহারবিধি (Standalone Native Usage):\033[0m\n");
        printf("  ./bin/lipic build <source.lp> [-o binary]    লিপি সোর্স ফাইল সরাসরি লিনাক্স ELF বাইনারিতে কম্পাইল করুন\n");
        printf("  ./bin/lipic run <source.lp>                  লিপি ফাইল সরাসরি কম্পাইল ও রান করুন\n");
        printf("  ./bin/lipic fmt <source.lp> [-w]             লিপি সোর্স ফাইল স্বয়ংক্রিয়ভাবে প্রমিত ফরম্যাট করুন\n");
        printf("  ./bin/lipic test                             সমস্ত টেস্ট সুইট স্বয়ংক্রিয়ভাবে এক্সিকিউট করুন\n");
        printf("  ./bin/lipic repl                             ইন্টারেক্টিভ সিলিকন টার্মিনাল প্রম্পট চালু করুন\n");
        printf("  ./bin/lipic --version                         কম্পাইলার ভার্সন প্রদর্শন করুন\n\n");
        printf("\033[1;33mবৈশিষ্ট্য (Features):\033[0m\n");
        printf("  • প্রথম শ্রেণীর ফাংশন (কাজ/fn) ও System V AMD64 ABI কলিং কনভেনশন\n");
        printf("  • সরাসরি লিনাক্স কার্নেল সিসকল ইঞ্জিন (সিসকল/syscall) ও র নেটওয়ার্কিং/ফাইল আইও\n");
        printf("  • ডাইনামিক কার্নেল হিপ মেমরি (SYS_mmap, মেমরি_পড়ো, মেমরি_লেখো) ও অ্যারে তালিকা[i]\n");
        printf("  • ৬৪কেবি রাইটেবল বিএসএস মেমরি বাফার (বাফার/buffer)\n");
        printf("  • মাল্টি-ফাইল মডিউল ইমপোর্ট (অন্তর্ভুক্ত/import)\n");
        printf("  • কম্পাইল করতে কোনো PHP, GCC বা বহিরাগত রানটাইম লাইব্রেরির প্রয়োজন নেই!\n");
        printf("  • জেনারেটকৃত বাইনারি সরাসরি লিনাক্স কার্নেলে শূন্য ডিপেন্ডেন্সিতে ১০০%% নেটিভে রান করে।\n\n");
        return 0;
    }

    if (strcmp(argv[1], "--version") == 0 || strcmp(argv[1], "-v") == 0) {
        printf("lipic version 3.0.0-sovereign (Standalone Pure Native Linux ELF Compiler)\n");
        return 0;
    }

    const char *source_path = NULL;
    const char *output_path = NULL;
    bool execute_after_build = false;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-o") == 0 && i + 1 < argc) {
            output_path = argv[++i];
        } else if (strcmp(argv[i], "build") == 0 || strcmp(argv[i], "compile") == 0) {
            continue;
        } else if (strcmp(argv[i], "run") == 0) {
            execute_after_build = true;
        } else if (!source_path && argv[i][0] != '-') {
            source_path = argv[i];
        }
    }

    if (!source_path) {
        fprintf(stderr, "\033[1;31m❌ এরর: কোনো সোর্স ফাইল দেওয়া হয়নি!\033[0m\n");
        return 1;
    }

    char default_out[256];
    if (!output_path) {
        const char *base = strrchr(source_path, '/');
        base = base ? base + 1 : source_path;
        snprintf(default_out, sizeof(default_out), "dist/%.*s", (int)(strcspn(base, ".")), base);
        output_path = default_out;
    }

    char visited_files[64][256];
    int visited_count = 0;
    size_t max_src = 1048576;
    char *full_source = (char *)calloc(max_src, 1);
    if (!load_source_with_imports(source_path, full_source, max_src, visited_files, &visited_count)) {
        fprintf(stderr, "\033[1;31m❌ এরর: ফাইল পাওয়া যায়নি: '%s'\033[0m\n", source_path);
        free(full_source);
        return 1;
    }

    size_t read_bytes = strlen(full_source);

    print_banner();
    printf("\033[1;33m[১] লিপি সোর্স কোড ও মডিউল পার্সিং...\033[0m\n");
    printf("  • মূল সোর্স ফাইল : %s (%zu বাইট)\n", source_path, read_bytes);
    if (visited_count > 1) {
        printf("  • অন্তর্ভুক্ত মডিউলসমূহ (%d টি):\n", visited_count - 1);
        for (int i = 1; i < visited_count; i++) {
            printf("    ├── %s\n", visited_files[i]);
        }
    }

    // Reset all compiler state
    g_sym_count = 0;
    g_func_count = 0;
    g_reloc_count = 0;
    g_bss_reloc_count = 0;
    g_func_reloc_count = 0;
    g_block_depth = 0;
    g_active_scope[0] = '\0';
    g_current_stack_offset = -8;

    // Parse all struct definitions first (মহাদিগন্ত ১১: কাস্টম গঠন / Structs)
    g_struct_count = 0;
    parse_all_structs(full_source);
    if (g_struct_count > 0) {
        printf("  • সনাক্তকৃত কাস্টম ডেটা গঠন (Structs) : %d টি\n", g_struct_count);
        for (int s_i = 0; s_i < g_struct_count; s_i++) {
            printf("    ├── গঠন '%s' (%d টি ফিল্ড, সাইজ: %d বাইট)\n",
                   g_structs[s_i].name, g_structs[s_i].field_count, g_structs[s_i].total_size);
        }
    }

    CodeBuffer cb = { .size = 0 };
    RoDataBuffer ro = { .size = 0 };

    // Emit initial jump over functions to main entry point: jmp main_entry
    emit_u8(&cb, 0xe9); // jmp rel32
    size_t main_jmp_patch = cb.size;
    emit_u32(&cb, 0); // placeholder

    const size_t len_kaj = strlen("কাজ");
    const size_t len_pangson = strlen("ফাংশন");
    const size_t len_gothon = strlen("গঠন");

    // Copy full_source for Pass 1 and Pass 2
    char *pass1_src = strdup(full_source);
    char *pass2_src = strdup(full_source);

    // =========================================================================
    // PASS 1: Compile all functions (কাজ / ফাংশন / fn / func)
    // =========================================================================
    char *saveptr1 = NULL;
    char *line1 = strtok_r(pass1_src, "\r\n", &saveptr1);
    bool in_func = false;
    bool skip_struct1 = false;
    int struct_depth1 = 0;

    while (line1) {
        strip_inline_comments(line1);
        char *trimmed = trim(line1);
        if (*trimmed != '\0') {
            bool is_gothon = (strncmp(trimmed, "গঠন", len_gothon) == 0 && (trimmed[len_gothon] == ' ' || trimmed[len_gothon] == '\t' || trimmed[len_gothon] == '{'));
            bool is_struct = (strncmp(trimmed, "struct", 6) == 0 && (trimmed[6] == ' ' || trimmed[6] == '\t' || trimmed[6] == '{'));

            if (is_gothon || is_struct) {
                skip_struct1 = true;
                struct_depth1 = 0;
                for (char *c = trimmed; *c; c++) {
                    if (*c == '{') struct_depth1++;
                    else if (*c == '}') struct_depth1--;
                }
                if (struct_depth1 <= 0) skip_struct1 = false;
                line1 = strtok_r(NULL, "\r\n", &saveptr1);
                continue;
            }
            if (skip_struct1) {
                for (char *c = trimmed; *c; c++) {
                    if (*c == '{') struct_depth1++;
                    else if (*c == '}') {
                        struct_depth1--;
                        if (struct_depth1 <= 0) {
                            skip_struct1 = false;
                            break;
                        }
                    }
                }
                line1 = strtok_r(NULL, "\r\n", &saveptr1);
                continue;
            }

            bool is_kaj     = (strncmp(trimmed, "কাজ", len_kaj) == 0 && (trimmed[len_kaj] == ' ' || trimmed[len_kaj] == '\t'));
            bool is_pangson = (strncmp(trimmed, "ফাংশন", len_pangson) == 0 && (trimmed[len_pangson] == ' ' || trimmed[len_pangson] == '\t'));
            bool is_fn      = (strncmp(trimmed, "fn", 2) == 0 && (trimmed[2] == ' ' || trimmed[2] == '\t'));
            bool is_func    = (strncmp(trimmed, "func", 4) == 0 && (trimmed[4] == ' ' || trimmed[4] == '\t'));

            if (is_kaj || is_pangson || is_fn || is_func) {
                in_func = true;
                size_t pfx = is_kaj ? len_kaj : (is_pangson ? len_pangson : (is_fn ? 2 : 4));
                char *decl = trim(trimmed + pfx);
                char *open_p = strchr(decl, '(');
                if (open_p) {
                    *open_p = '\0';
                    char *func_name = trim(decl);
                    char *params_str = trim(open_p + 1);
                    char *close_p = strchr(params_str, ')');
                    if (close_p) *close_p = '\0';

                    Function *fn = add_function(func_name);
                    fn->code_offset = cb.size;
                    emit_prologue(&cb, fn->frame_size);

                    strncpy(g_active_scope, func_name, sizeof(g_active_scope) - 1);
                    g_current_stack_offset = -8;

                    char *saveptr_param = NULL;
                    char *tok = strtok_r(params_str, ",", &saveptr_param);
                    while (tok && fn->param_count < 6) {
                        char *pname = trim(tok);
                        strncpy(fn->params[fn->param_count], pname, 63);
                        Symbol *sym = add_symbol(pname);
                        if (sym && (strstr(pname, "বার্তা") || strstr(pname, "লেখা") || strstr(pname, "শিরোনাম") ||
                            strstr(pname, "পথ") || strstr(pname, "স্ট্রিং") || strstr(pname, "str") ||
                            strstr(pname, "msg") || strstr(pname, "txt"))) {
                            sym->is_string = true;
                            sym->rodata_offset = 0; // dynamic string pointer passed in function call frame
                        }

                        switch (fn->param_count) {
                            case 0: emit_bytes(&cb, (const uint8_t[]){0x48, 0x89, 0xbd}, 3); emit_u32(&cb, (uint32_t)sym->stack_offset); break;
                            case 1: emit_bytes(&cb, (const uint8_t[]){0x48, 0x89, 0xb5}, 3); emit_u32(&cb, (uint32_t)sym->stack_offset); break;
                            case 2: emit_bytes(&cb, (const uint8_t[]){0x48, 0x89, 0x95}, 3); emit_u32(&cb, (uint32_t)sym->stack_offset); break;
                            case 3: emit_bytes(&cb, (const uint8_t[]){0x48, 0x89, 0x8d}, 3); emit_u32(&cb, (uint32_t)sym->stack_offset); break;
                            case 4: emit_bytes(&cb, (const uint8_t[]){0x4c, 0x89, 0x85}, 3); emit_u32(&cb, (uint32_t)sym->stack_offset); break;
                            case 5: emit_bytes(&cb, (const uint8_t[]){0x4c, 0x89, 0x8d}, 3); emit_u32(&cb, (uint32_t)sym->stack_offset); break;
                        }

                        fn->param_count++;
                        tok = strtok_r(NULL, ",", &saveptr_param);
                    }

                    if (g_block_depth < MAX_BLOCKS) {
                        g_blocks[g_block_depth].type = BLOCK_FUNC;
                        g_blocks[g_block_depth].loop_start = 0;
                        g_blocks[g_block_depth].else_jump_patch = 0;
                        g_blocks[g_block_depth].endif_jump_patch = 0;
                        g_blocks[g_block_depth].has_else = false;
                        g_block_depth++;
                    }
                }
            } else if (in_func) {
                compile_statement(&cb, &ro, trimmed);
                if (g_block_depth == 0) {
                    in_func = false;
                }
            }
        }
        line1 = strtok_r(NULL, "\r\n", &saveptr1);
    }
    free(pass1_src);

    // =========================================================================
    // Patch Jump to Main Entry Point
    // =========================================================================
    int32_t main_disp = (int32_t)(cb.size - (main_jmp_patch + 4));
    memcpy(&cb.bytes[main_jmp_patch], &main_disp, sizeof(int32_t));

    // Reset scope for Main
    g_active_scope[0] = '\0';
    g_current_stack_offset = -8;
    g_block_depth = 0;

    // Main Prologue
    emit_prologue(&cb, 4096);

    // =========================================================================
    // PASS 2: Compile Top-Level Statements (skipping function bodies)
    // =========================================================================
    char *saveptr2 = NULL;
    char *line2 = strtok_r(pass2_src, "\r\n", &saveptr2);
    bool skip_func = false;
    int func_depth = 0;
    bool skip_struct2 = false;
    int struct_depth2 = 0;

    while (line2) {
        strip_inline_comments(line2);
        char *trimmed = trim(line2);
        if (*trimmed != '\0') {
            bool is_gothon = (strncmp(trimmed, "গঠন", len_gothon) == 0 && (trimmed[len_gothon] == ' ' || trimmed[len_gothon] == '\t' || trimmed[len_gothon] == '{'));
            bool is_struct = (strncmp(trimmed, "struct", 6) == 0 && (trimmed[6] == ' ' || trimmed[6] == '\t' || trimmed[6] == '{'));

            if (is_gothon || is_struct) {
                skip_struct2 = true;
                struct_depth2 = 0;
                for (char *c = trimmed; *c; c++) {
                    if (*c == '{') struct_depth2++;
                    else if (*c == '}') struct_depth2--;
                }
                if (struct_depth2 <= 0) skip_struct2 = false;
                line2 = strtok_r(NULL, "\r\n", &saveptr2);
                continue;
            }
            if (skip_struct2) {
                for (char *c = trimmed; *c; c++) {
                    if (*c == '{') struct_depth2++;
                    else if (*c == '}') {
                        struct_depth2--;
                        if (struct_depth2 <= 0) {
                            skip_struct2 = false;
                            break;
                        }
                    }
                }
                line2 = strtok_r(NULL, "\r\n", &saveptr2);
                continue;
            }

            bool is_kaj     = (strncmp(trimmed, "কাজ", len_kaj) == 0 && (trimmed[len_kaj] == ' ' || trimmed[len_kaj] == '\t'));
            bool is_pangson = (strncmp(trimmed, "ফাংশন", len_pangson) == 0 && (trimmed[len_pangson] == ' ' || trimmed[len_pangson] == '\t'));
            bool is_fn      = (strncmp(trimmed, "fn", 2) == 0 && (trimmed[2] == ' ' || trimmed[2] == '\t'));
            bool is_func    = (strncmp(trimmed, "func", 4) == 0 && (trimmed[4] == ' ' || trimmed[4] == '\t'));

            if (is_kaj || is_pangson || is_fn || is_func) {
                skip_func = true;
                func_depth = 0;
                for (char *c = trimmed; *c; c++) {
                    if (*c == '{') func_depth++;
                    else if (*c == '}') func_depth--;
                }
            } else if (skip_func) {
                for (char *c = trimmed; *c; c++) {
                    if (*c == '{') func_depth++;
                    else if (*c == '}') {
                        func_depth--;
                        if (func_depth <= 0) {
                            skip_func = false;
                            break;
                        }
                    }
                }
            } else {
                compile_statement(&cb, &ro, trimmed);
            }
        }
        line2 = strtok_r(NULL, "\r\n", &saveptr2);
    }
    free(pass2_src);
    free(full_source);

    // Append sovereign stamp
    const char *stamp = "⚡ [100% Sovereign Lipi Synthesized Native ELF - Hardware CPU Execution]\n";
    emit_print_static_string(&cb, &ro, stamp, strlen(stamp));

    // Emit main epilogue (SYS_exit 0)
    emit_main_epilogue(&cb);

    // Patch all string virtual addresses (.rodata relocations)
    uint64_t rodata_base_vaddr = ENTRY_POINT + cb.size;
    for (int i = 0; i < g_reloc_count; i++) {
        uint64_t final_vaddr = rodata_base_vaddr + g_relocs[i].rodata_offset;
        memcpy(&cb.bytes[g_relocs[i].code_patch_pos], &final_vaddr, sizeof(uint64_t));
    }

    // Patch all BSS writeable memory buffer relocations
    uint64_t bss_base_vaddr = ENTRY_POINT + cb.size + ro.size;
    for (int i = 0; i < g_bss_reloc_count; i++) {
        uint64_t final_vaddr = bss_base_vaddr + g_bss_relocs[i].bss_offset;
        memcpy(&cb.bytes[g_bss_relocs[i].code_patch_pos], &final_vaddr, sizeof(uint64_t));
    }

    // Patch all function call relative offsets
    for (int i = 0; i < g_func_reloc_count; i++) {
        Function *fn = find_function(g_func_relocs[i].func_name);
        if (fn) {
            int32_t disp = (int32_t)(fn->code_offset - (g_func_relocs[i].code_patch_pos + 4));
            memcpy(&cb.bytes[g_func_relocs[i].code_patch_pos], &disp, sizeof(int32_t));
        } else {
            fprintf(stderr, "\033[1;31m❌ এরর: অনির্ধারিত ফাংশন কল: '%s'\033[0m\n", g_func_relocs[i].func_name);
            return 1;
        }
    }

    printf("  • মোট জেনারেটকৃত মেশিন কোড : %zu বাইট (Pure x86_64 Instructions)\n", cb.size);
    printf("  • মোট রিড-অনলি ডেটা (.rodata): %zu বাইট\n", ro.size);
    printf("  • মোট ডিক্লেয়ার্ড ফাংশন       : %d টি\n", g_func_count);
    printf("  • মোট সিম্বল ভেরিয়েবল      : %d টি\n\n", g_sym_count);

    uint64_t file_size = CODE_OFFSET + cb.size + ro.size;
    uint64_t mem_size = ((file_size + 65536ULL + 4095ULL) / 4096ULL) * 4096ULL;
    if (mem_size < 0x2000) mem_size = 0x2000;

    Elf64_Ehdr ehdr;
    memset(&ehdr, 0, sizeof(ehdr));
    memcpy(ehdr.e_ident, "\x7f\x45\x4c\x46\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00", 16);
    ehdr.e_type = 2;
    ehdr.e_machine = 62;
    ehdr.e_version = 1;
    ehdr.e_entry = ENTRY_POINT;
    ehdr.e_phoff = 64;
    ehdr.e_shoff = 0;
    ehdr.e_flags = 0;
    ehdr.e_ehsize = sizeof(Elf64_Ehdr);
    ehdr.e_phentsize = sizeof(Elf64_Phdr);
    ehdr.e_phnum = 1;

    Elf64_Phdr phdr;
    memset(&phdr, 0, sizeof(phdr));
    phdr.p_type = 1;
    phdr.p_flags = 7; // PF_R | PF_W | PF_X
    phdr.p_offset = 0;
    phdr.p_vaddr = BASE_VADDR;
    phdr.p_paddr = BASE_VADDR;
    phdr.p_filesz = file_size;
    phdr.p_memsz = mem_size;
    phdr.p_align = CODE_OFFSET;

    size_t padding_len = CODE_OFFSET - (sizeof(ehdr) + sizeof(phdr));
    uint8_t *padding = (uint8_t *)calloc(padding_len, 1);

    char out_copy[512];
    snprintf(out_copy, sizeof(out_copy), "%s", output_path);
    char *slash = strrchr(out_copy, '/');
    if (slash) {
        *slash = '\0';
        mkdir(out_copy, 0755);
    }

    FILE *out = fopen(output_path, "wb");
    if (!out) {
        fprintf(stderr, "\033[1;31m❌ এরর: আউটপুট ফাইল তৈরি করা যায়নি: '%s'\033[0m\n", output_path);
        free(padding);
        return 1;
    }

    fwrite(&ehdr, 1, sizeof(ehdr), out);
    fwrite(&phdr, 1, sizeof(phdr), out);
    fwrite(padding, 1, padding_len, out);
    fwrite(cb.bytes, 1, cb.size, out);
    fwrite(ro.bytes, 1, ro.size, out);
    fclose(out);
    free(padding);

    chmod(output_path, 0755);

    printf("\033[1;33m[২] স্ট্যান্ডঅ্যালোন লিনাক্স ELF ৬৪-বিট বাইনারি জেনারেশন সম্পন্ন...\033[0m\n");
    printf("  ✔ সফলভাবে স্ট্যান্ডঅ্যালোন নেটিভ বাইনারি তৈরি হয়েছে (Standalone ELF 64-bit Compiled)!\n");
    printf("  • আউটপুট বাইনারি : \033[1;32m%s\033[0m\n", output_path);
    printf("  • মোট ফাইল সাইজ   : %lu বাইট\n", file_size);
    printf("  • মেমরি পেজ বরাদ্দ : %lu বাইট\n", mem_size);
    printf("  • ডিপেন্ডেন্সি     : \033[1;36m০%% PHP | ০%% Libc | ০%% GCC | সরাসরি সিলিকন প্রসেসর\033[0m\n\n");

    if (execute_after_build) {
        printf("\033[1;33m[৩] তৈরি বাইনারি সরাসরি লিনাক্স কার্নেলে টেস্ট রান:\033[0m\n");
        printf("\033[38;2;120;200;255m------------------------------------------------------------------------\033[0m\n");
        fflush(stdout);

        char cmd[512];
        snprintf(cmd, sizeof(cmd), "./%s", output_path);
        int ret = system(cmd);
        (void)ret;

        printf("\033[38;2;120;200;255m------------------------------------------------------------------------\033[0m\n\n");
        printf("\033[38;2;0;255;204m🎉 লিপি ১০০%% সার্বভৌম! কোনো PHP ছাড়াই সরাসরি লিপি থেকে মেশিন কোড উৎপন্ন হয়েছে।\033[0m\n\n");
    }

    return 0;
}

int run_repl(void) {
    print_banner();
    printf("\033[1;32mস্বাগতম লিপি ইন্টারেক্টিভ সিলিকন শেলের (REPL) মধ্যে!\033[0m\n");
    printf("সরাসরি লিপি কোড লিখুন। প্রস্থান করতে 'প্রস্থান' অথবা 'exit' লিখুন।\n\n");

    char line_buf[1024];
    while (1) {
        printf("\033[38;2;0;255;204mলিপি > \033[0m");
        fflush(stdout);
        if (!fgets(line_buf, sizeof(line_buf), stdin)) break;
        char *cmd = trim(line_buf);
        if (strcmp(cmd, "exit") == 0 || strcmp(cmd, "quit") == 0 || strcmp(cmd, "প্রস্থান") == 0) {
            printf("\033[1;33mলিপি শেল সমাপ্ত। খোদা হাফেজ!\033[0m\n");
            break;
        }
        if (strlen(cmd) == 0) continue;

        FILE *tmp = fopen("/tmp/lipi_repl_tmp.lp", "w");
        if (!tmp) continue;
        if (strncmp(cmd, "দেখাও", strlen("দেখাও")) != 0 && strncmp(cmd, "show", 4) != 0 && strchr(cmd, '=') == NULL) {
            fprintf(tmp, "দেখাও %s\n", cmd);
        } else {
            fprintf(tmp, "%s\n", cmd);
        }
        fclose(tmp);

        char compile_cmd[512];
        snprintf(compile_cmd, sizeof(compile_cmd), "./bin/lipic /tmp/lipi_repl_tmp.lp -o /tmp/lipi_repl_bin > /dev/null 2>&1 && /tmp/lipi_repl_bin | grep -v '⚡'");
        int ret = system(compile_cmd);
        (void)ret;
    }
    return 0;
}

// 10. Lipi Code Formatter Engine (lipi fmt)
// WHY: Enforces consistent, readable code formatting across sovereign Lipi codebases.
static int run_formatter(int argc, char *argv[]) {
    const char *file_path = NULL;
    bool write_back = false;

    for (int i = 2; i < argc; i++) {
        if (strcmp(argv[i], "-w") == 0 || strcmp(argv[i], "--write") == 0) {
            write_back = true;
        } else if (!file_path && argv[i][0] != '-') {
            file_path = argv[i];
        }
    }

    if (!file_path) {
        fprintf(stderr, "\033[1;31m❌ এরর: ফরম্যাট করার জন্য ফাইল পাথ উল্লেখ করুন (যেমন: ./bin/lipic fmt <file.lp> [-w])\033[0m\n");
        return 1;
    }

    FILE *f = fopen(file_path, "rb");
    if (!f) {
        fprintf(stderr, "\033[1;31m❌ এরর: ফাইল ওপেন করা যায়নি: '%s'\033[0m\n", file_path);
        return 1;
    }

    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    fseek(f, 0, SEEK_SET);

    char *src = (char *)malloc(sz + 1);
    if (!src) { fclose(f); return 1; }
    size_t r = fread(src, 1, sz, f);
    src[r] = '\0';
    fclose(f);

    size_t out_cap = sz * 2 + 8192;
    char *out = (char *)malloc(out_cap);
    if (!out) { free(src); return 1; }
    out[0] = '\0';
    size_t out_len = 0;

    int indent_level = 0;
    char *saveptr = NULL;
    char *line = strtok_r(src, "\r\n", &saveptr);
    bool prev_empty = false;

    while (line != NULL) {
        char *t = trim(line);
        if (*t == '\0') {
            if (!prev_empty) {
                if (out_len + 2 < out_cap) {
                    out[out_len++] = '\n';
                    out[out_len] = '\0';
                }
                prev_empty = true;
            }
            line = strtok_r(NULL, "\r\n", &saveptr);
            continue;
        }
        prev_empty = false;

        // Check closing brace '}' at start of line
        if (t[0] == '}') {
            if (indent_level > 0) indent_level--;
        }

        // Emit indentation spaces (4 spaces per indent level)
        for (int i = 0; i < indent_level * 4; i++) {
            if (out_len + 2 < out_cap) {
                out[out_len++] = ' ';
            }
        }
        out[out_len] = '\0';

        size_t t_len = strlen(t);
        if (out_len + t_len + 2 < out_cap) {
            memcpy(out + out_len, t, t_len);
            out_len += t_len;
            out[out_len++] = '\n';
            out[out_len] = '\0';
        }

        // Count braces outside comments and string literals
        int open_count = 0;
        int close_count = 0;
        bool in_q = false;
        char q_ch = 0;
        for (size_t i = 0; i < t_len; i++) {
            if (!in_q && (t[i] == '"' || t[i] == '\'')) {
                in_q = true; q_ch = t[i];
            } else if (in_q && t[i] == q_ch) {
                if (i == 0 || t[i-1] != '\\') in_q = false;
            } else if (!in_q) {
                if (t[i] == '/' && i + 1 < t_len && t[i+1] == '/') break;
                if (t[i] == '{') open_count++;
                if (t[i] == '}') close_count++;
            }
        }

        if (t[0] == '}') {
            indent_level += (open_count - (close_count - 1));
        } else {
            indent_level += (open_count - close_count);
        }
        if (indent_level < 0) indent_level = 0;

        line = strtok_r(NULL, "\r\n", &saveptr);
    }

    if (write_back) {
        FILE *wf = fopen(file_path, "wb");
        if (!wf) {
            fprintf(stderr, "\033[1;31m❌ এরর: ফাইলে লিখতে ব্যর্থ: '%s'\033[0m\n", file_path);
            free(src); free(out);
            return 1;
        }
        fwrite(out, 1, out_len, wf);
        fclose(wf);
        printf("\033[1;32m✔ ফরম্যাটিং সফলভাবে সংরক্ষিত হয়েছে: %s\033[0m\n", file_path);
    } else {
        fputs(out, stdout);
    }

    free(src);
    free(out);
    return 0;
}

int run_tests(void) {
    print_banner();
    printf("\033[1;33m[🧪] লিপি স্বয়ংক্রিয় সার্বভৌম টেস্ট সুইট শুরু হচ্ছে...\033[0m\n\n");

    const char *test_files[] = {
        "examples/01_hello.lp",
        "examples/02_math_fibonacci.lp",
        "examples/12_native_silicon_logic.lp",
        "examples/13_sovereign_cpu_arithmetic.lp",
        "examples/14_sovereign_loop_and_logic.lp",
        "examples/15_functions_and_recursion.lp",
        "examples/16_kernel_syscalls_file_io.lp",
        "examples/17_standard_library_import.lp",
        "examples/18_native_web_server.lp",
        "examples/19_heap_memory_and_pointers.lp",
        "examples/20_grand_stdlib_expansion.lp",
        "examples/21_kernel_multithreading.lp",
        "examples/22_custom_structs_and_types.lp",
        "examples/23_native_database_engine.lp",
        "examples/24_silicon_matrix_ai.lp",
        NULL
    };

    int total_count = 0;
    while (test_files[total_count] != NULL) total_count++;

    int passed = 0;
    int total = 0;

    for (int i = 0; test_files[i] != NULL; i++) {
        total++;
        char out_bin[256];
        snprintf(out_bin, sizeof(out_bin), "dist/test_%02d", i + 1);

        char build_cmd[512];
        snprintf(build_cmd, sizeof(build_cmd), "./bin/lipic %s -o %s > /dev/null 2>&1", test_files[i], out_bin);
        int b_res = system(build_cmd);

        if (b_res != 0) {
            printf("  ❌ [%02d/%02d] কম্পাইলেশন ব্যর্থ: %s\n", i + 1, total_count, test_files[i]);
            continue;
        }

        char run_cmd[512];
        snprintf(run_cmd, sizeof(run_cmd), "./%s > /dev/null 2>&1", out_bin);
        int r_res = system(run_cmd);

        if (r_res == 0) {
            printf("  ✔ \033[1;32m[%02d/%02d] সফলভাবে উত্তীর্ণ:\033[0m %s\n", i + 1, total_count, test_files[i]);
            passed++;
        } else {
            printf("  ❌ [%02d/%02d] রানটাইম ত্রুটি: %s\n", i + 1, total_count, test_files[i]);
        }
    }

    printf("\n\033[1;33mটেস্ট ফলাফল সারসংক্ষেপ:\033[0m %d / %d টি টেস্ট সফল হয়েছে (১০০%% সার্বভৌম সিলিকন এক্সিকিউশন)!\n\n", passed, total);
    return (passed == total) ? 0 : 1;
}
