/**
 * 👑 Lipi Standalone Native Linux ELF Compiler (lipic) — লিপি নেটিভ সিলিকন কম্পাইলার
 *
 * WHY: Lipi is a completely independent, sovereign systems programming language.
 * It is NOT a framework or a PHP wrapper.
 *
 * This compiler is a standalone native Linux executable that parses Lipi (.lp) code
 * and synthesizes 64-bit Linux ELF standalone binary executables with REAL x86_64 MACHINE CODE:
 *   - Real stack frames (push rbp; mov rbp, rsp; sub rsp, 1024)
 *   - Real ALU machine instructions (imul, add, sub, idiv) executed by CPU hardware at runtime
 *   - Real conditional branching (cmp, jle, jg, jmp) with relative offset backpatching
 *   - Real hardware RDTSC instruction (0x0F 0x31) to read physical CPU cycle registers
 *   - Real runtime stack-allocated Bengali numeral (itoa) conversion in pure machine code
 *   - Direct Linux x86_64 raw syscalls (SYS_write: 1, SYS_exit: 60)
 *   - ZERO PHP, ZERO Libc, ZERO GCC required to run generated binaries
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

#define MAX_SYMBOLS   256
#define MAX_CODE_SIZE 65536
#define MAX_RODATA    65536
#define MAX_RELOCS    1024

// 1. Symbol Table for local stack frame variables
typedef struct {
    char name[128];
    int32_t stack_offset; // e.g. -8, -16, -24 relative to rbp
    bool is_initialized;
    bool is_string;
    size_t rodata_offset;
    size_t string_len;
    int64_t const_val;
} Symbol;

static Symbol g_syms[MAX_SYMBOLS];
static int g_sym_count = 0;
static int32_t g_current_stack_offset = -8;

static Symbol *find_symbol(const char *name) {
    for (int i = 0; i < g_sym_count; i++) {
        if (strcmp(g_syms[i].name, name) == 0) {
            return &g_syms[i];
        }
    }
    return NULL;
}

static Symbol *add_symbol(const char *name) {
    Symbol *s = find_symbol(name);
    if (s) return s;
    if (g_sym_count < MAX_SYMBOLS) {
        s = &g_syms[g_sym_count++];
        strncpy(s->name, name, sizeof(s->name) - 1);
        s->name[sizeof(s->name) - 1] = '\0';
        s->stack_offset = g_current_stack_offset;
        g_current_stack_offset -= 8;
        s->is_initialized = false;
        s->is_string = false;
        s->rodata_offset = 0;
        s->string_len = 0;
        s->const_val = 0;
        return s;
    }
    return NULL;
}

// 2. Code Buffer for x86_64 Machine Code instructions
typedef struct {
    uint8_t bytes[MAX_CODE_SIZE];
    size_t size;
} CodeBuffer;

static void emit_u8(CodeBuffer *cb, uint8_t b) {
    if (cb->size < sizeof(cb->bytes)) cb->bytes[cb->size++] = b;
}

static __attribute__((unused)) void emit_u16(CodeBuffer *cb, uint16_t v) {
    emit_u8(cb, (uint8_t)(v & 0xFF));
    emit_u8(cb, (uint8_t)((v >> 8) & 0xFF));
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

// 3. Read-Only Data (.rodata) Buffer
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

// 4. Relocation records for string addresses in machine code
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

// 5. String helper utilities
static char *trim(char *str) {
    while (isspace((unsigned char)*str)) str++;
    if (*str == 0) return str;
    char *end = str + strlen(str) - 1;
    while (end > str && isspace((unsigned char)*end)) end--;
    end[1] = '\0';
    return str;
}

// Convert Bengali or ASCII numeral string to 64-bit signed integer
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
        // Bengali UTF-8 digits start with E0 A7 (০=0xA6 to ৯=0xAF)
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

// Check if string consists purely of digits (Bengali or ASCII)
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

// 6. x86_64 Machine Code Emitter Functions

// Prologue: push rbp; mov rbp, rsp; sub rsp, 1024
static void emit_prologue(CodeBuffer *cb) {
    emit_u8(cb, 0x55);                                          // push rbp
    emit_bytes(cb, (const uint8_t[]){0x48, 0x89, 0xe5}, 3);    // mov rbp, rsp
    emit_bytes(cb, (const uint8_t[]){0x48, 0x81, 0xec}, 3);    // sub rsp, imm32
    emit_u32(cb, 1024);                                         // 1024 bytes stack frame
}

// Epilogue: mov rax, 60; xor rdi, rdi; syscall
static void emit_epilogue(CodeBuffer *cb) {
    emit_bytes(cb, (const uint8_t[]){0x48, 0xc7, 0xc0, 0x3c, 0x00, 0x00, 0x00}, 7); // mov rax, 60
    emit_bytes(cb, (const uint8_t[]){0x48, 0x31, 0xff}, 3);                         // xor rdi, rdi
    emit_bytes(cb, (const uint8_t[]){0x0f, 0x05}, 2);                               // syscall
}

// mov qword ptr [rbp + disp32], imm32
static void emit_mov_stack_imm(CodeBuffer *cb, int32_t disp32, int32_t imm32) {
    emit_bytes(cb, (const uint8_t[]){0x48, 0xc7, 0x85}, 3);
    emit_u32(cb, (uint32_t)disp32);
    emit_u32(cb, (uint32_t)imm32);
}

// mov rax, [rbp + disp32]
static void emit_mov_rax_stack(CodeBuffer *cb, int32_t disp32) {
    emit_bytes(cb, (const uint8_t[]){0x48, 0x8b, 0x85}, 3);
    emit_u32(cb, (uint32_t)disp32);
}

// mov rbx, [rbp + disp32]
static void emit_mov_rbx_stack(CodeBuffer *cb, int32_t disp32) {
    emit_bytes(cb, (const uint8_t[]){0x48, 0x8b, 0x9d}, 3);
    emit_u32(cb, (uint32_t)disp32);
}

// mov [rbp + disp32], rax
static void emit_mov_stack_rax(CodeBuffer *cb, int32_t disp32) {
    emit_bytes(cb, (const uint8_t[]){0x48, 0x89, 0x85}, 3);
    emit_u32(cb, (uint32_t)disp32);
}

// mov rbx, imm64
static void emit_mov_rbx_imm64(CodeBuffer *cb, int64_t imm64) {
    emit_bytes(cb, (const uint8_t[]){0x48, 0xbb}, 2);
    emit_u64(cb, (uint64_t)imm64);
}

// Arithmetic: imul rax, rbx
static void emit_imul_rax_rbx(CodeBuffer *cb) {
    emit_bytes(cb, (const uint8_t[]){0x48, 0x0f, 0xaf, 0xc3}, 4);
}

// Arithmetic: add rax, rbx
static void emit_add_rax_rbx(CodeBuffer *cb) {
    emit_bytes(cb, (const uint8_t[]){0x48, 0x01, 0xd8}, 3);
}

// Arithmetic: sub rax, rbx
static void emit_sub_rax_rbx(CodeBuffer *cb) {
    emit_bytes(cb, (const uint8_t[]){0x48, 0x29, 0xd8}, 3);
}

// Arithmetic: cqo; idiv rbx
static void emit_idiv_rax_rbx(CodeBuffer *cb) {
    emit_bytes(cb, (const uint8_t[]){0x48, 0x99, 0x48, 0xf7, 0xfb}, 5);
}

// Arithmetic: sub rax, imm32
static __attribute__((unused)) void emit_sub_rax_imm(CodeBuffer *cb, int32_t imm32) {
    emit_bytes(cb, (const uint8_t[]){0x48, 0x2d}, 2);
    emit_u32(cb, (uint32_t)imm32);
}

// Hardware TimeStamp Counter: rdtsc; shl rdx, 32; or rax, rdx
static void emit_rdtsc(CodeBuffer *cb, int32_t stack_disp32) {
    emit_bytes(cb, (const uint8_t[]){
        0x0f, 0x31,             // rdtsc (eax = lo, edx = hi)
        0x48, 0xc1, 0xe2, 0x20, // shl rdx, 32
        0x48, 0x09, 0xd0        // or rax, rdx
    }, 9);
    emit_mov_stack_rax(cb, stack_disp32);
}

// Direct SYS_write(1, rodata_addr, len) using rodata offset
static void emit_print_rodata_slice(CodeBuffer *cb, size_t ro_off, size_t len) {
    // mov rax, 1 (SYS_write)
    emit_bytes(cb, (const uint8_t[]){0x48, 0xc7, 0xc0, 0x01, 0x00, 0x00, 0x00}, 7);
    // mov rdi, 1 (stdout)
    emit_bytes(cb, (const uint8_t[]){0x48, 0xc7, 0xc7, 0x01, 0x00, 0x00, 0x00}, 7);
    // movabs rsi, imm64 (placeholder patched later)
    emit_bytes(cb, (const uint8_t[]){0x48, 0xbe}, 2);
    size_t patch_pos = cb->size;
    emit_u64(cb, 0); // placeholder
    add_reloc(patch_pos, ro_off);
    // mov rdx, imm32 (len)
    emit_bytes(cb, (const uint8_t[]){0x48, 0xc7, 0xc2}, 3);
    emit_u32(cb, (uint32_t)len);
    // syscall
    emit_bytes(cb, (const uint8_t[]){0x0f, 0x05}, 2);
}

// Direct SYS_write(1, rodata_addr, len) for static C string
static void emit_print_static_string(CodeBuffer *cb, RoDataBuffer *ro, const char *str, size_t len) {
    size_t ro_off = add_rodata(ro, (const uint8_t *)str, len);
    emit_print_rodata_slice(cb, ro_off, len);
}

// Emit runtime itoa routine: converts 64-bit integer in rax to UTF-8 Bengali digits
// on the stack buffer at [rbp - 256] working backwards, then prints via SYS_write
static void emit_runtime_print_bangla_num(CodeBuffer *cb, bool newline) {
    // 102 bytes of pure x86_64 machine code
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
        itoa_code[9] = 0x00; // replace \n with null/no-op
        itoa_code[12] = 0x00; // start counter at 0 instead of 1
    }

    emit_bytes(cb, itoa_code, sizeof(itoa_code));
}

// 7. Parse & Compile Expression
static void compile_rhs_arithmetic(CodeBuffer *cb, const char *expr) {
    char copy[256];
    strncpy(copy, expr, sizeof(copy) - 1);
    copy[sizeof(copy) - 1] = '\0';
    char *s = trim(copy);

    // Hardware Clock check
    if (strstr(s, "সিপিউ_ক্লক") != NULL || strstr(s, "rdtsc") != NULL || strstr(s, "clock") != NULL) {
        emit_rdtsc(cb, g_current_stack_offset);
        return;
    }

    // Search for arithmetic operator (+, -, *, /) from right to left
    int len = (int)strlen(s);
    char op = 0;
    int op_idx = -1;

    for (int i = len - 1; i >= 0; i--) {
        if ((s[i] == '+' || s[i] == '-') && i > 0 && s[i-1] != '*' && s[i-1] != '/' && s[i-1] != '+' && s[i-1] != '-') {
            op = s[i];
            op_idx = i;
            break;
        }
    }
    if (op_idx == -1) {
        for (int i = len - 1; i >= 0; i--) {
            if (s[i] == '*' || s[i] == '/') {
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

        // Load Left into RAX
        Symbol *sym_left = find_symbol(left);
        if (sym_left) {
            emit_mov_rax_stack(cb, sym_left->stack_offset);
        } else {
            int64_t lnum = parse_bangla_number(left);
            emit_bytes(cb, (const uint8_t[]){0x48, 0xb8}, 2); // mov rax, imm64
            emit_u64(cb, (uint64_t)lnum);
        }

        // Load Right into RBX
        Symbol *sym_right = find_symbol(right);
        if (sym_right) {
            emit_mov_rbx_stack(cb, sym_right->stack_offset);
        } else {
            int64_t rnum = parse_bangla_number(right);
            emit_mov_rbx_imm64(cb, rnum);
        }

        // Perform ALU operation
        switch (op) {
            case '*': emit_imul_rax_rbx(cb); break;
            case '+': emit_add_rax_rbx(cb); break;
            case '-': emit_sub_rax_rbx(cb); break;
            case '/': emit_idiv_rax_rbx(cb); break;
        }
    } else {
        // Single term
        Symbol *sym = find_symbol(s);
        if (sym) {
            emit_mov_rax_stack(cb, sym->stack_offset);
        } else {
            int64_t num = parse_bangla_number(s);
            emit_bytes(cb, (const uint8_t[]){0x48, 0xb8}, 2); // mov rax, imm64
            emit_u64(cb, (uint64_t)num);
        }
    }
}

// 8. 64-bit Linux ELF Header structures
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

void print_banner(void) {
    printf("\033[38;2;0;255;204m╔════════════════════════════════════════════════════════════════════════╗\033[0m\n");
    printf("\033[38;2;0;255;204m║\033[0m  \033[1;38;2;255;255;255m👑 LIPIC — 100%% NATIVE STANDALONE LIPI COMPILER (ZERO PHP / ZERO GCC)\033[0m \033[38;2;0;255;204m║\033[0m\n");
    printf("\033[38;2;0;255;204m║\033[0m  \033[38;2;180;180;180m⚡ Direct Linux ELF 64-bit Machine Code Generation | Pure Silicon Engine\033[0m\033[38;2;0;255;204m║\033[0m\n");
    printf("\033[38;2;0;255;204m╚════════════════════════════════════════════════════════════════════════╝\033[0m\n\n");
}

int main(int argc, char *argv[]) {
    if (argc < 2 || strcmp(argv[1], "help") == 0 || strcmp(argv[1], "--help") == 0 || strcmp(argv[1], "-h") == 0) {
        print_banner();
        printf("\033[1;33mব্যবহারবিধি (Standalone Native Usage):\033[0m\n");
        printf("  ./bin/lipic <source.lp> [-o output_binary]    লিপি সোর্স ফাইল সরাসরি লিনাক্স ELF বাইনারিতে কম্পাইল করুন\n");
        printf("  ./bin/lipic --version                         কম্পাইলার ভার্সন প্রদর্শন করুন\n\n");
        printf("\033[1;33mবৈশিষ্ট্য (Features):\033[0m\n");
        printf("  • কম্পাইল করতে কোনো PHP, GCC বা বহিরাগত টুলের প্রয়োজন নেই!\n");
        printf("  • জেনারেটকৃত বাইনারি সরাসরি লিনাক্স কার্নেলে শূন্য ডিপেন্ডেন্সিতে রান করে।\n\n");
        return 0;
    }

    if (strcmp(argv[1], "--version") == 0 || strcmp(argv[1], "-v") == 0) {
        printf("lipic version 2.0.0-sovereign (Standalone Pure Native Linux ELF Compiler)\n");
        return 0;
    }

    const char *source_path = NULL;
    const char *output_path = NULL;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-o") == 0 && i + 1 < argc) {
            output_path = argv[++i];
        } else if (strcmp(argv[i], "build") == 0 || strcmp(argv[i], "compile") == 0) {
            continue;
        } else if (source_path == NULL) {
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

    FILE *f = fopen(source_path, "rb");
    if (!f) {
        fprintf(stderr, "\033[1;31m❌ এরর: ফাইল পাওয়া যায়নি: '%s'\033[0m\n", source_path);
        return 1;
    }

    fseek(f, 0, SEEK_END);
    long fsize = ftell(f);
    fseek(f, 0, SEEK_SET);

    char *source = (char *)malloc(fsize + 1);
    if (!source) {
        fclose(f);
        fprintf(stderr, "Out of memory!\n");
        return 1;
    }

    size_t read_bytes = fread(source, 1, fsize, f);
    source[read_bytes] = '\0';
    fclose(f);

    print_banner();
    printf("\033[1;33m[১] লিপি সোর্স কোড পার্সিং ও মেশিন কোড জেনারেশন...\033[0m\n");
    printf("  • সোর্স ফাইল : %s (%zu বাইট)\n", source_path, read_bytes);

    CodeBuffer cb = { .size = 0 };
    RoDataBuffer ro = { .size = 0 };

    // Emit function prologue
    emit_prologue(&cb);

    // Conditional tracking stack for branch backpatching
    typedef struct {
        size_t else_jump_patch; // position of jle disp32
        size_t endif_jump_patch; // position of jmp disp32
        bool has_else;
    } CondStack;

    CondStack cond_stack[32];
    int cond_depth = 0;

    const size_t len_dhori = strlen("ধরি");
    const size_t len_dekhao = strlen("দেখাও");
    const size_t len_jodi = strlen("যদি");
    const size_t len_nahole = strlen("নাহলে");

    char *line = strtok(source, "\r\n");
    while (line) {
        char *trimmed = trim(line);
        if (*trimmed == '\0' || strncmp(trimmed, "//", 2) == 0 || *trimmed == '#') {
            line = strtok(NULL, "\r\n");
            continue;
        }

        // 1. Closing brace '}' with optional 'নাহলে' on same line
        if (trimmed[0] == '}') {
            char *after_brace = trim(trimmed + 1);
            if (cond_depth > 0) {
                if (cond_stack[cond_depth - 1].has_else) {
                    // Patch endif jump
                    size_t patch_pos = cond_stack[cond_depth - 1].endif_jump_patch;
                    int32_t disp = (int32_t)(cb.size - (patch_pos + 4));
                    memcpy(&cb.bytes[patch_pos], &disp, sizeof(int32_t));
                    cond_depth--;
                } else if (*after_brace == '\0') {
                    // Patch then branch jump to here
                    size_t patch_pos = cond_stack[cond_depth - 1].else_jump_patch;
                    int32_t disp = (int32_t)(cb.size - (patch_pos + 4));
                    memcpy(&cb.bytes[patch_pos], &disp, sizeof(int32_t));
                    cond_depth--;
                }
            }
            if (*after_brace == '\0') {
                line = strtok(NULL, "\r\n");
                continue;
            }
            trimmed = after_brace;
        }

        // 2. 'নাহলে {' or 'else {'
        bool is_nahole = (strncmp(trimmed, "নাহলে", len_nahole) == 0 && (trimmed[len_nahole] == ' ' || trimmed[len_nahole] == '{' || trimmed[len_nahole] == '\0'));
        bool is_else = (strncmp(trimmed, "else", 4) == 0 && (trimmed[4] == ' ' || trimmed[4] == '{' || trimmed[4] == '\0'));

        if (is_nahole || is_else) {
            if (cond_depth > 0) {
                // Emit unconditional jmp to endif
                emit_u8(&cb, 0xe9); // jmp disp32
                size_t jmp_patch = cb.size;
                emit_u32(&cb, 0); // placeholder
                cond_stack[cond_depth - 1].endif_jump_patch = jmp_patch;
                cond_stack[cond_depth - 1].has_else = true;

                // Patch the previous jle to jump right here (start of else block)
                size_t else_patch = cond_stack[cond_depth - 1].else_jump_patch;
                int32_t disp = (int32_t)(cb.size - (else_patch + 4));
                memcpy(&cb.bytes[else_patch], &disp, sizeof(int32_t));
            }
            line = strtok(NULL, "\r\n");
            continue;
        }

        // 3. Conditional: যদি <cond> { OR if <cond> {
        bool is_jodi = (strncmp(trimmed, "যদি", len_jodi) == 0 && (trimmed[len_jodi] == ' ' || trimmed[len_jodi] == '\t'));
        bool is_if   = (strncmp(trimmed, "if", 2) == 0 && (trimmed[2] == ' ' || trimmed[2] == '\t'));

        if (is_jodi || is_if) {
            size_t pfx = is_jodi ? len_jodi : 2;
            char *cond_part = trim(trimmed + pfx);
            char *brace = strchr(cond_part, '{');
            if (brace) *brace = '\0';
            cond_part = trim(cond_part);

            char *op = NULL;
            int op_type = 0; // 1:>, 2:<, 3:>=, 4:<=, 5:==, 6:!=
            if ((op = strstr(cond_part, ">=")) != NULL) { op_type = 3; *op = '\0'; op += 2; }
            else if ((op = strstr(cond_part, "<=")) != NULL) { op_type = 4; *op = '\0'; op += 2; }
            else if ((op = strstr(cond_part, "==")) != NULL) { op_type = 5; *op = '\0'; op += 2; }
            else if ((op = strstr(cond_part, "!=")) != NULL) { op_type = 6; *op = '\0'; op += 2; }
            else if ((op = strchr(cond_part, '>')) != NULL) { op_type = 1; *op = '\0'; op += 1; }
            else if ((op = strchr(cond_part, '<')) != NULL) { op_type = 2; *op = '\0'; op += 1; }

            char *left = trim(cond_part);
            char *right = op ? trim(op) : NULL;

            // Load left into RAX
            Symbol *sym_l = find_symbol(left);
            if (sym_l) {
                emit_mov_rax_stack(&cb, sym_l->stack_offset);
            } else {
                int64_t lval = parse_bangla_number(left);
                emit_bytes(&cb, (const uint8_t[]){0x48, 0xb8}, 2);
                emit_u64(&cb, (uint64_t)lval);
            }

            // Load right into RBX
            if (right) {
                Symbol *sym_r = find_symbol(right);
                if (sym_r) {
                    emit_mov_rbx_stack(&cb, sym_r->stack_offset);
                } else {
                    int64_t rval = parse_bangla_number(right);
                    emit_mov_rbx_imm64(&cb, rval);
                }
            } else {
                emit_mov_rbx_imm64(&cb, 0);
            }

            // cmp rax, rbx
            emit_bytes(&cb, (const uint8_t[]){0x48, 0x39, 0xd8}, 3);

            // Inverted jump to ELSE if condition is FALSE:
            // > (1)  -> jump if <= (jle: 0x0f 0x8e)
            // < (2)  -> jump if >= (jge: 0x0f 0x8d)
            // >= (3) -> jump if <  (jl:  0x0f 0x8c)
            // <= (4) -> jump if >  (jg:  0x0f 0x8f)
            // == (5) -> jump if != (jne: 0x0f 0x85)
            // != (6) -> jump if == (je:  0x0f 0x84)
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
            emit_bytes(&cb, jcc, 2);
            size_t patch_pos = cb.size;
            emit_u32(&cb, 0); // placeholder

            if (cond_depth < 32) {
                cond_stack[cond_depth].else_jump_patch = patch_pos;
                cond_stack[cond_depth].endif_jump_patch = 0;
                cond_stack[cond_depth].has_else = false;
                cond_depth++;
            }

            line = strtok(NULL, "\r\n");
            continue;
        }

        // 4. Variable declaration: ধরি <name> = <expr> OR let <name> = <expr>
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
                        while (*expr && *expr != quote) {
                            if (*expr == '\\' && *(expr + 1)) {
                                expr++;
                                char esc = *expr++;
                                char c = (esc == 'n') ? '\n' : ((esc == 't') ? '\t' : ((esc == 'r') ? '\r' : esc));
                                if (s_len < sizeof(str_buf) - 1) str_buf[s_len++] = c;
                            } else {
                                if (s_len < sizeof(str_buf) - 1) str_buf[s_len++] = *expr++;
                                else expr++;
                            }
                        }
                        str_buf[s_len] = '\0';
                        sym->is_string = true;
                        sym->rodata_offset = add_rodata(&ro, (const uint8_t *)str_buf, s_len);
                        sym->string_len = s_len;
                        sym->is_initialized = true;
                    } else if (is_numeric_str(expr)) {
                        int64_t val = parse_bangla_number(expr);
                        sym->const_val = val;
                        sym->is_initialized = true;
                        sym->is_string = false;
                        // mov qword ptr [rbp + stack_offset], imm32
                        emit_mov_stack_imm(&cb, sym->stack_offset, (int32_t)val);
                    } else {
                        // Compile RHS expression
                        compile_rhs_arithmetic(&cb, expr);
                        emit_mov_stack_rax(&cb, sym->stack_offset);
                        sym->is_initialized = true;
                        sym->is_string = false;
                    }
                }
            }
            line = strtok(NULL, "\r\n");
            continue;
        }

        // 5. Show statement: দেখাও <expr> OR show <expr>
        bool is_dekhao = (strncmp(trimmed, "দেখাও", len_dekhao) == 0 && (trimmed[len_dekhao] == ' ' || trimmed[len_dekhao] == '\0' || trimmed[len_dekhao] == '\t'));
        bool is_show   = (strncmp(trimmed, "show", 4) == 0 && (trimmed[4] == ' ' || trimmed[4] == '\0' || trimmed[4] == '\t'));

        if (is_dekhao || is_show) {
            size_t pfx = is_dekhao ? len_dekhao : 4;
            char *expr = trim(trimmed + pfx);

            // Parse concatenation (+ operators)
            const char *p = expr;
            while (*p) {
                while (isspace((unsigned char)*p) || *p == '+') p++;
                if (!*p) break;

                // Quoted string literal ("..." or '...')
                if (*p == '"' || *p == '\'') {
                    char quote = *p++;
                    char str_buf[4096];
                    size_t s_len = 0;
                    while (*p && *p != quote) {
                        if (*p == '\\' && *(p + 1)) {
                            p++;
                            char esc = *p++;
                            char c = 0;
                            if (esc == 'n') c = '\n';
                            else if (esc == 't') c = '\t';
                            else if (esc == 'r') c = '\r';
                            else if (esc == 'e') c = '\033';
                            else if (esc == '0' && *p == '3' && *(p + 1) == '3') {
                                c = '\033';
                                p += 2;
                            } else if (esc == 'x' && isxdigit((unsigned char)*p) && isxdigit((unsigned char)*(p + 1))) {
                                char hex[3] = { *p, *(p + 1), '\0' };
                                c = (char)strtol(hex, NULL, 16);
                                p += 2;
                            } else {
                                c = esc;
                            }
                            if (s_len < sizeof(str_buf) - 1) str_buf[s_len++] = c;
                        } else {
                            if (s_len < sizeof(str_buf) - 1) str_buf[s_len++] = *p++;
                            else p++;
                        }
                    }
                    if (*p == quote) p++;
                    str_buf[s_len] = '\0';
                    emit_print_static_string(&cb, &ro, str_buf, s_len);
                    continue;
                }

                // Identifier / Number / Function token
                char token[256];
                int tlen = 0;
                while (*p && !isspace((unsigned char)*p) && *p != '+' && *p != '"' && *p != '\'' && *p != ';') {
                    if (tlen < (int)sizeof(token) - 1) token[tlen++] = *p;
                    p++;
                }
                token[tlen] = '\0';
                if (tlen == 0) continue;

                // Check for বাংলা_সংখ্যা(var) or to_bangla(var)
                if (strncmp(token, "বাংলা_সংখ্যা(", strlen("বাংলা_সংখ্যা(")) == 0 ||
                    strncmp(token, "to_bangla(", strlen("to_bangla(")) == 0) {
                    char inner[128] = {0};
                    char *start = strchr(token, '(');
                    if (start) {
                        start++;
                        char *end = strchr(start, ')');
                        if (end) *end = '\0';
                        strncpy(inner, start, sizeof(inner) - 1);
                    }
                    Symbol *sym = find_symbol(inner);
                    if (sym) {
                        emit_mov_rax_stack(&cb, sym->stack_offset);
                        emit_runtime_print_bangla_num(&cb, false);
                    } else if (is_numeric_str(inner)) {
                        int64_t n = parse_bangla_number(inner);
                        emit_bytes(&cb, (const uint8_t[]){0x48, 0xb8}, 2);
                        emit_u64(&cb, (uint64_t)n);
                        emit_runtime_print_bangla_num(&cb, false);
                    }
                    continue;
                }

                // Check if token is a variable
                Symbol *sym = find_symbol(token);
                if (sym) {
                    if (sym->is_string) {
                        emit_print_rodata_slice(&cb, sym->rodata_offset, sym->string_len);
                    } else {
                        emit_mov_rax_stack(&cb, sym->stack_offset);
                        emit_runtime_print_bangla_num(&cb, false);
                    }
                } else if (is_numeric_str(token)) {
                    int64_t n = parse_bangla_number(token);
                    emit_bytes(&cb, (const uint8_t[]){0x48, 0xb8}, 2);
                    emit_u64(&cb, (uint64_t)n);
                    emit_runtime_print_bangla_num(&cb, false);
                }
            }

            // Emit newline at end of দেখাও
            emit_print_static_string(&cb, &ro, "\n", 1);
            line = strtok(NULL, "\r\n");
            continue;
        }

        line = strtok(NULL, "\r\n");
    }

    free(source);

    // Append sovereign stamp
    const char *stamp = "⚡ [100% Sovereign Lipi Synthesized Native ELF - Hardware CPU Execution]\n";
    emit_print_static_string(&cb, &ro, stamp, strlen(stamp));

    // Emit function epilogue (SYS_exit 0)
    emit_epilogue(&cb);

    // Patch all string virtual addresses (.rodata relocations)
    uint64_t rodata_base_vaddr = ENTRY_POINT + cb.size;
    for (int i = 0; i < g_reloc_count; i++) {
        uint64_t final_vaddr = rodata_base_vaddr + g_relocs[i].rodata_offset;
        memcpy(&cb.bytes[g_relocs[i].code_patch_pos], &final_vaddr, sizeof(uint64_t));
    }

    printf("  • মোট জেনারেটকৃত মেশিন কোড : %zu বাইট (Pure x86_64 Instructions)\n", cb.size);
    printf("  • মোট রিড-অনলি ডেটা (.rodata): %zu বাইট\n", ro.size);
    printf("  • মোট সিম্বল ভেরিয়েবল      : %d টি\n\n", g_sym_count);

    // Calculate ELF sizes
    uint64_t file_size = CODE_OFFSET + cb.size + ro.size;
    uint64_t mem_size = ((file_size + 4095ULL) / 4096ULL) * 4096ULL;
    if (mem_size < 0x2000) mem_size = 0x2000;

    // ELF Header (64 bytes)
    Elf64_Ehdr ehdr;
    memset(&ehdr, 0, sizeof(ehdr));
    memcpy(ehdr.e_ident, "\x7f\x45\x4c\x46\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00", 16);
    ehdr.e_type = 2;        // ET_EXEC
    ehdr.e_machine = 62;    // EM_X86_64
    ehdr.e_version = 1;     // EV_CURRENT
    ehdr.e_entry = ENTRY_POINT;
    ehdr.e_phoff = 64;      // Program Header immediately follows ELF Header
    ehdr.e_shoff = 0;
    ehdr.e_flags = 0;
    ehdr.e_ehsize = sizeof(Elf64_Ehdr);
    ehdr.e_phentsize = sizeof(Elf64_Phdr);
    ehdr.e_phnum = 1;
    ehdr.e_shentsize = 0;
    ehdr.e_shnum = 0;
    ehdr.e_shstrndx = 0;

    // Program Header (56 bytes, PT_LOAD)
    Elf64_Phdr phdr;
    memset(&phdr, 0, sizeof(phdr));
    phdr.p_type = 1;        // PT_LOAD
    phdr.p_flags = 7;       // PF_R | PF_W | PF_X
    phdr.p_offset = 0;
    phdr.p_vaddr = BASE_VADDR;
    phdr.p_paddr = BASE_VADDR;
    phdr.p_filesz = file_size;
    phdr.p_memsz = mem_size;
    phdr.p_align = CODE_OFFSET;

    // Padding (4096 - 64 - 56 = 3976 bytes)
    size_t padding_len = CODE_OFFSET - (sizeof(ehdr) + sizeof(phdr));
    uint8_t *padding = (uint8_t *)calloc(padding_len, 1);

    // Create target directory if needed
    char out_copy[512];
    snprintf(out_copy, sizeof(out_copy), "%s", output_path);
    char *slash = strrchr(out_copy, '/');
    if (slash) {
        *slash = '\0';
        mkdir(out_copy, 0755);
    }

    // Write Standalone Native ELF Binary File
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

    printf("\033[1;33m[৩] তৈরি বাইনারি সরাসরি লিনাক্স কার্নেলে টেস্ট রান:\033[0m\n");
    printf("\033[38;2;120;200;255m------------------------------------------------------------------------\033[0m\n");
    fflush(stdout);

    char cmd[512];
    snprintf(cmd, sizeof(cmd), "./%s", output_path);
    int ret = system(cmd);
    (void)ret;

    printf("\033[38;2;120;200;255m------------------------------------------------------------------------\033[0m\n\n");
    printf("\033[38;2;0;255;204m🎉 লিপি ১০০%% সার্বভৌম! কোনো PHP ছাড়াই সরাসরি লিপি থেকে মেশিন কোড উৎপন্ন হয়েছে।\033[0m\n\n");

    return 0;
}
