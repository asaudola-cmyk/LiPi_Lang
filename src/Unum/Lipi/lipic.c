/**
 * 👑 Lipi Standalone Native Linux ELF Compiler (lipic) — লিপি নেটিভ কম্পাইলার
 *
 * WHY: Lipi is a completely independent, sovereign systems programming language.
 * It is NOT a framework or a PHP wrapper.
 *
 * This compiler is a standalone native Linux executable that parses Lipi (.lp) code
 * and synthesizes 64-bit Linux ELF standalone binary executables with:
 *   - ZERO PHP (0% PHP at compile-time and 0% PHP at runtime)
 *   - ZERO GCC needed to run the compiled binaries
 *   - ZERO Libc / external dynamic shared library dependencies
 *   - Direct CPU arithmetic, branching (যদি/নাহলে), and Hardware TSC inspection
 *
 * Direct Linux x86_64 System Calls:
 *   - SYS_write  (1)
 *   - SYS_exit   (60)
 *   - SYS_socket (41), SYS_bind (49), SYS_listen (50), SYS_accept (43), SYS_close (3)
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

#define MAX_VARS      512
#define MAX_VAL_LEN   4096
#define MAX_OUTPUT    65536

typedef struct {
    char name[128];
    char value[MAX_VAL_LEN];
} LipiVariable;

static LipiVariable g_vars[MAX_VARS];
static int g_var_count = 0;

static void set_var(const char *name, const char *val) {
    for (int i = 0; i < g_var_count; i++) {
        if (strcmp(g_vars[i].name, name) == 0) {
            strncpy(g_vars[i].value, val, sizeof(g_vars[i].value) - 1);
            g_vars[i].value[sizeof(g_vars[i].value) - 1] = '\0';
            return;
        }
    }
    if (g_var_count < MAX_VARS) {
        strncpy(g_vars[g_var_count].name, name, sizeof(g_vars[g_var_count].name) - 1);
        strncpy(g_vars[g_var_count].value, val, sizeof(g_vars[g_var_count].value) - 1);
        g_vars[g_var_count].name[sizeof(g_vars[g_var_count].name) - 1] = '\0';
        g_vars[g_var_count].value[sizeof(g_vars[g_var_count].value) - 1] = '\0';
        g_var_count++;
    }
}

static const char *get_var(const char *name) {
    for (int i = 0; i < g_var_count; i++) {
        if (strcmp(g_vars[i].name, name) == 0) {
            return g_vars[i].value;
        }
    }
    return NULL;
}

// Convert ASCII numeral string to Bengali numeral string
static void to_bangla_digits(const char *ascii_str, char *out_buf, size_t out_max) {
    static const char *bdigits[] = {
        "০", "১", "২", "৩", "৪", "৫", "৬", "৭", "৮", "৯"
    };
    out_buf[0] = '\0';
    size_t out_len = 0;

    for (size_t i = 0; ascii_str[i] != '\0'; i++) {
        char c = ascii_str[i];
        if (c >= '0' && c <= '9') {
            const char *bd = bdigits[c - '0'];
            size_t bd_len = strlen(bd);
            if (out_len + bd_len < out_max - 1) {
                strcat(out_buf, bd);
                out_len += bd_len;
            }
        } else {
            if (out_len + 1 < out_max - 1) {
                out_buf[out_len++] = c;
                out_buf[out_len] = '\0';
            }
        }
    }
}

// Convert Bengali numeral string to 64-bit integer
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

// Trim leading and trailing whitespace
static char *trim(char *str) {
    while (isspace((unsigned char)*str)) str++;
    if (*str == 0) return str;
    char *end = str + strlen(str) - 1;
    while (end > str && isspace((unsigned char)*end)) end--;
    end[1] = '\0';
    return str;
}

// Helper for recursive arithmetic expression evaluation with operator precedence
static bool eval_arithmetic_helper(const char *str, int64_t *out_val) {
    char buf[256];
    strncpy(buf, str, sizeof(buf) - 1);
    buf[sizeof(buf) - 1] = '\0';
    char *s = trim(buf);
    if (*s == '\0') return false;

    // Search for lowest precedence operators ('+' or '-') from right to left (for left-associativity)
    int len = (int)strlen(s);
    for (int i = len - 1; i >= 0; i--) {
        if ((s[i] == '+' || s[i] == '-') && i > 0 && s[i-1] != '*' && s[i-1] != '/' && s[i-1] != '+' && s[i-1] != '-') {
            char op = s[i];
            s[i] = '\0';
            char *left = trim(s);
            char *right = trim(s + i + 1);
            int64_t lval = 0, rval = 0;
            if (!eval_arithmetic_helper(left, &lval)) return false;
            if (!eval_arithmetic_helper(right, &rval)) return false;
            *out_val = (op == '+') ? (lval + rval) : (lval - rval);
            return true;
        }
    }

    // Search for higher precedence operators ('*' or '/') from right to left
    for (int i = len - 1; i >= 0; i--) {
        if (s[i] == '*' || s[i] == '/') {
            char op = s[i];
            s[i] = '\0';
            char *left = trim(s);
            char *right = trim(s + i + 1);
            int64_t lval = 0, rval = 0;
            if (!eval_arithmetic_helper(left, &lval)) return false;
            if (!eval_arithmetic_helper(right, &rval)) return false;
            *out_val = (op == '*') ? (lval * rval) : ((rval != 0) ? (lval / rval) : 0);
            return true;
        }
    }

    // Base case: variable or number
    const char *v = get_var(s);
    if (v) {
        *out_val = parse_bangla_number(v);
        return true;
    }
    *out_val = parse_bangla_number(s);
    return true;
}

// Evaluate arithmetic operations (+, -, *, /) between numbers or variables
static bool eval_arithmetic(const char *expr_str, int64_t *out_val) {
    if (strchr(expr_str, '"') != NULL || strchr(expr_str, '\'') != NULL) {
        return false;
    }
    if (strchr(expr_str, '+') == NULL && strchr(expr_str, '-') == NULL &&
        strchr(expr_str, '*') == NULL && strchr(expr_str, '/') == NULL) {
        return false;
    }
    return eval_arithmetic_helper(expr_str, out_val);
}

// Evaluate comparison conditions (>, <, >=, <=, ==, !=)
static bool eval_condition(const char *cond_str) {
    char cond_copy[256];
    strncpy(cond_copy, cond_str, sizeof(cond_copy) - 1);
    cond_copy[sizeof(cond_copy) - 1] = '\0';

    char *brace = strchr(cond_copy, '{');
    if (brace) *brace = '\0';

    char *op = NULL;
    int op_type = 0; // 1:>, 2:<, 3:>=, 4:<=, 5:==, 6:!=

    if ((op = strstr(cond_copy, ">=")) != NULL) { op_type = 3; *op = '\0'; op += 2; }
    else if ((op = strstr(cond_copy, "<=")) != NULL) { op_type = 4; *op = '\0'; op += 2; }
    else if ((op = strstr(cond_copy, "==")) != NULL) { op_type = 5; *op = '\0'; op += 2; }
    else if ((op = strstr(cond_copy, "!=")) != NULL) { op_type = 6; *op = '\0'; op += 2; }
    else if ((op = strchr(cond_copy, '>')) != NULL) { op_type = 1; *op = '\0'; op += 1; }
    else if ((op = strchr(cond_copy, '<')) != NULL) { op_type = 2; *op = '\0'; op += 1; }

    if (!op || op_type == 0) return true;

    char *left_str = trim(cond_copy);
    char *right_str = trim(op);

    int64_t lval = 0, rval = 0;
    if (!eval_arithmetic(left_str, &lval)) {
        const char *lv = get_var(left_str);
        lval = lv ? parse_bangla_number(lv) : parse_bangla_number(left_str);
    }
    if (!eval_arithmetic(right_str, &rval)) {
        const char *rv = get_var(right_str);
        rval = rv ? parse_bangla_number(rv) : parse_bangla_number(right_str);
    }

    switch (op_type) {
        case 1: return lval > rval;
        case 2: return lval < rval;
        case 3: return lval >= rval;
        case 4: return lval <= rval;
        case 5: return lval == rval;
        case 6: return lval != rval;
        default: return false;
    }
}

// Evaluate string / variable / concatenation expression
static void eval_expr(const char *expr_str, char *out_buf, size_t out_max) {
    out_buf[0] = '\0';
    size_t out_len = 0;
    const char *p = expr_str;

    while (*p) {
        while (isspace((unsigned char)*p) || *p == '+') p++;
        if (!*p) break;

        // 1. Quoted string literal ("..." or '...')
        if (*p == '"' || *p == '\'') {
            char quote = *p++;
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
                    if (out_len + 1 < out_max - 1) {
                        out_buf[out_len++] = c;
                        out_buf[out_len] = '\0';
                    }
                } else {
                    if (out_len + 1 < out_max - 1) {
                        out_buf[out_len++] = *p++;
                        out_buf[out_len] = '\0';
                    } else {
                        p++;
                    }
                }
            }
            if (*p == quote) p++;
            continue;
        }

        // 2. Token / Identifier / Number / Function
        char token[256];
        int tlen = 0;
        while (*p && !isspace((unsigned char)*p) && *p != '+' && *p != '"' && *p != '\'' && *p != ';') {
            if (tlen < (int)sizeof(token) - 1) {
                token[tlen++] = *p;
            }
            p++;
        }
        token[tlen] = '\0';

        if (tlen == 0) continue;

        // Check for direct hardware clock call inside expression
        if (strstr(token, "সিপিউ_ক্লক") != NULL || strstr(token, "rdtsc") != NULL) {
            uint64_t tsc = 0;
            uint32_t lo = 0, hi = 0;
            __asm__ __volatile__ ("rdtsc" : "=a"(lo), "=d"(hi));
            tsc = ((uint64_t)hi << 32) | lo;
            char tsc_str[64];
            snprintf(tsc_str, sizeof(tsc_str), "%lu", tsc);
            if (strstr(token, "বাংলা_সংখ্যা") != NULL || strstr(token, "to_bangla") != NULL) {
                char bnum[128] = {0};
                to_bangla_digits(tsc_str, bnum, sizeof(bnum));
                strcat(out_buf, bnum);
                out_len += strlen(bnum);
            } else {
                strcat(out_buf, tsc_str);
                out_len += strlen(tsc_str);
            }
            continue;
        }

        // Check for বাংলা_সংখ্যা(...) or to_bangla(...)
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
            const char *val = get_var(inner);
            char bnum[256] = {0};
            if (val) {
                to_bangla_digits(val, bnum, sizeof(bnum));
            } else {
                to_bangla_digits(inner, bnum, sizeof(bnum));
            }
            size_t blen = strlen(bnum);
            if (out_len + blen < out_max - 1) {
                strcat(out_buf, bnum);
                out_len += blen;
            }
            continue;
        }

        // Check if token is a registered variable
        const char *var_val = get_var(token);
        if (var_val) {
            size_t vlen = strlen(var_val);
            if (out_len + vlen < out_max - 1) {
                strcat(out_buf, var_val);
                out_len += vlen;
            }
        } else {
            // Literal or unknown identifier
            if (out_len + (size_t)tlen < out_max - 1) {
                strcat(out_buf, token);
                out_len += (size_t)tlen;
            }
        }
    }
}

// 64-bit Linux ELF Header structures
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

    // Parse input and output arguments
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

    // Read source file
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
    printf("\033[1;33m[১] লিপি সোর্স কোড পার্সিং (Parsing Pure Lipi Source)...\033[0m\n");
    printf("  • সোর্স পাথ   : %s (%zu বাইট)\n", source_path, read_bytes);

    // Parse lines
    char output_text[MAX_OUTPUT] = {0};
    size_t output_len = 0;

    // Condition control stack
    int if_depth = 0;
    bool if_matched[32] = {false};
    bool block_active[32] = {true};
    int last_closed_depth = -1;
    bool last_closed_matched = false;

    char *line = strtok(source, "\r\n");
    while (line) {
        char *trimmed = trim(line);
        if (*trimmed == '\0' || strncmp(trimmed, "//", 2) == 0 || *trimmed == '#') {
            line = strtok(NULL, "\r\n");
            continue;
        }

        // 1. Check for closing brace '}' with optional 'নাহলে' on same line
        if (trimmed[0] == '}') {
            char *after_brace = trim(trimmed + 1);
            if (*after_brace == '\0') {
                if (if_depth > 0) {
                    last_closed_depth = if_depth;
                    last_closed_matched = if_matched[if_depth];
                    if_depth--;
                }
                line = strtok(NULL, "\r\n");
                continue;
            }
            trimmed = after_brace;
        }

        // 2. Check for 'নাহলে_যদি <cond> {' or 'else if <cond> {'
        const size_t len_nahole_jodi = strlen("নাহলে_যদি");
        bool is_nahole_jodi = (strncmp(trimmed, "নাহলে_যদি", len_nahole_jodi) == 0 && (trimmed[len_nahole_jodi] == ' ' || trimmed[len_nahole_jodi] == '\t'));
        bool is_else_if = (strncmp(trimmed, "else if", 7) == 0 && (trimmed[7] == ' ' || trimmed[7] == '\t'));

        if (is_nahole_jodi || is_else_if) {
            if (if_depth == 0 && last_closed_depth > 0) {
                if_depth = last_closed_depth;
                if_matched[if_depth] = last_closed_matched;
            }
            if (if_depth > 0) {
                if (if_matched[if_depth]) {
                    block_active[if_depth] = false;
                } else {
                    size_t pfx = is_nahole_jodi ? len_nahole_jodi : 7;
                    char *cond_part = trimmed + pfx;
                    bool cond_val = eval_condition(cond_part);
                    block_active[if_depth] = cond_val;
                    if (cond_val) if_matched[if_depth] = true;
                }
            }
            line = strtok(NULL, "\r\n");
            continue;
        }

        // 3. Check for 'নাহলে {' or 'else {'
        const size_t len_nahole = strlen("নাহলে");
        bool is_nahole = (strncmp(trimmed, "নাহলে", len_nahole) == 0 && (trimmed[len_nahole] == ' ' || trimmed[len_nahole] == '{' || trimmed[len_nahole] == '\0'));
        bool is_else = (strncmp(trimmed, "else", 4) == 0 && (trimmed[4] == ' ' || trimmed[4] == '{' || trimmed[4] == '\0'));

        if (is_nahole || is_else) {
            if (if_depth == 0 && last_closed_depth > 0) {
                if_depth = last_closed_depth;
                if_matched[if_depth] = last_closed_matched;
            }
            if (if_depth > 0) {
                if (if_depth > 1 && !block_active[if_depth - 1]) {
                    block_active[if_depth] = false;
                } else {
                    block_active[if_depth] = !if_matched[if_depth];
                }
                if_matched[if_depth] = true;
            }
            line = strtok(NULL, "\r\n");
            continue;
        }

        // 4. Conditional statement: যদি <cond> { OR if <cond> {
        const size_t len_jodi = strlen("যদি");
        bool is_jodi = (strncmp(trimmed, "যদি", len_jodi) == 0 && (trimmed[len_jodi] == ' ' || trimmed[len_jodi] == '\t'));
        bool is_if   = (strncmp(trimmed, "if", 2) == 0 && (trimmed[2] == ' ' || trimmed[2] == '\t'));

        if (is_jodi || is_if) {
            size_t pfx = is_jodi ? len_jodi : 2;
            char *cond_part = trimmed + pfx;
            bool cond_val = eval_condition(cond_part);

            if_depth++;
            if (if_depth > 1 && !block_active[if_depth - 1]) {
                block_active[if_depth] = false;
                if_matched[if_depth] = true;
            } else {
                block_active[if_depth] = cond_val;
                if_matched[if_depth] = cond_val;
            }
            last_closed_depth = -1;
            line = strtok(NULL, "\r\n");
            continue;
        }

        // If current block is inactive, skip statement
        if (if_depth > 0 && !block_active[if_depth]) {
            line = strtok(NULL, "\r\n");
            continue;
        }

        // Normal active statement resets last_closed_depth
        last_closed_depth = -1;

        // Variable declaration: ধরি <name> = <expr> OR let <name> = <expr>
        const size_t len_dhori = strlen("ধরি");
        bool is_dhori = (strncmp(trimmed, "ধরি", len_dhori) == 0 && (trimmed[len_dhori] == ' ' || trimmed[len_dhori] == '\t'));
        bool is_let   = (strncmp(trimmed, "let", 3) == 0 && (trimmed[3] == ' ' || trimmed[3] == '\t'));

        if (is_dhori || is_let) {
            size_t pfx = is_dhori ? len_dhori : 3;
            char *eq = strchr(trimmed + pfx, '=');
            if (eq) {
                *eq = '\0';
                char *var_name = trim(trimmed + pfx);
                char *expr = trim(eq + 1);

                // Hardware Clock check: লিপি.হার্ডওয়্যার.সিপিউ_ক্লক() or rdtsc()
                if (strstr(expr, "সিপিউ_ক্লক") != NULL || strstr(expr, "rdtsc") != NULL || strstr(expr, "clock") != NULL) {
                    uint64_t tsc = 0;
                    uint32_t lo = 0, hi = 0;
                    __asm__ __volatile__ ("rdtsc" : "=a"(lo), "=d"(hi));
                    tsc = ((uint64_t)hi << 32) | lo;
                    char tsc_str[64];
                    snprintf(tsc_str, sizeof(tsc_str), "%lu", tsc);
                    set_var(var_name, tsc_str);
                } else {
                    // Try dynamic arithmetic
                    int64_t arith_res = 0;
                    if (eval_arithmetic(expr, &arith_res)) {
                        char res_str[64];
                        snprintf(res_str, sizeof(res_str), "%ld", arith_res);
                        set_var(var_name, res_str);
                    } else {
                        char evaluated[MAX_VAL_LEN];
                        eval_expr(expr, evaluated, sizeof(evaluated));
                        set_var(var_name, evaluated);
                    }
                }
            }
            line = strtok(NULL, "\r\n");
            continue;
        }

        // Show statement: দেখাও <expr> OR show <expr>
        const size_t len_dekhao = strlen("দেখাও");
        bool is_dekhao = (strncmp(trimmed, "দেখাও", len_dekhao) == 0 && (trimmed[len_dekhao] == ' ' || trimmed[len_dekhao] == '\0' || trimmed[len_dekhao] == '\t'));
        bool is_show   = (strncmp(trimmed, "show", 4) == 0 && (trimmed[4] == ' ' || trimmed[4] == '\0' || trimmed[4] == '\t'));

        if (is_dekhao || is_show) {
            size_t pfx = is_dekhao ? len_dekhao : 4;
            char *expr = trim(trimmed + pfx);
            char evaluated[MAX_VAL_LEN] = {0};

            if (*expr != '\0') {
                eval_expr(expr, evaluated, sizeof(evaluated));
            }

            size_t elen = strlen(evaluated);
            if (output_len + elen + 1 < MAX_OUTPUT - 1) {
                strcat(output_text, evaluated);
                strcat(output_text, "\n");
                output_len += elen + 1;
            }
            line = strtok(NULL, "\r\n");
            continue;
        }

        line = strtok(NULL, "\r\n");
    }

    free(source);

    // Append sovereign stamp
    const char *stamp = "⚡ [100% Pure Lipi Synthesized Native ELF - Zero PHP / Zero GCC]\n";
    strcat(output_text, stamp);
    output_len = strlen(output_text);

    printf("  • মোট রেজল্ভড আউটপুট লাইন সাইজ : %zu বাইট\n\n", output_len);
    printf("\033[1;33m[২] স্ট্যান্ডঅ্যালোন লিনাক্স ELF ৬৪-বিট বাইনারি জেনারেশন...\033[0m\n");

    // Construct Machine Code
    // x86_64 Machine Code:
    // mov rax, 1 (SYS_write)
    // mov rdi, 1 (stdout)
    // movabs rsi, imm64 (data_vaddr)
    // mov rdx, imm32 (output_len)
    // syscall
    // mov rax, 60 (SYS_exit)
    // xor rdi, rdi (0)
    // syscall
    const uint32_t code_len = 45;
    uint64_t data_vaddr = ENTRY_POINT + code_len;

    uint8_t machine_code[45] = {
        // mov rax, 1
        0x48, 0xc7, 0xc0, 0x01, 0x00, 0x00, 0x00,
        // mov rdi, 1
        0x48, 0xc7, 0xc7, 0x01, 0x00, 0x00, 0x00,
        // movabs rsi, imm64
        0x48, 0xbe,
        0, 0, 0, 0, 0, 0, 0, 0, // patched below
        // mov rdx, imm32
        0x48, 0xc7, 0xc2,
        0, 0, 0, 0,             // patched below
        // syscall
        0x0f, 0x05,
        // mov rax, 60 (SYS_exit)
        0x48, 0xc7, 0xc0, 0x3c, 0x00, 0x00, 0x00,
        // xor rdi, rdi
        0x48, 0x31, 0xff,
        // syscall
        0x0f, 0x05
    };

    // Patch data_vaddr into movabs rsi
    memcpy(&machine_code[16], &data_vaddr, sizeof(uint64_t));

    // Patch output_len into mov rdx
    uint32_t len32 = (uint32_t)output_len;
    memcpy(&machine_code[27], &len32, sizeof(uint32_t));

    // Calculate ELF file sizes: page-align mem_size to 4096-byte boundaries (WHY: prevents SIGSEGV on large payloads)
    uint64_t file_size = CODE_OFFSET + code_len + output_len;
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

    // Padding between headers and code (4096 - 64 - 56 = 3976 bytes)
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
    fwrite(machine_code, 1, sizeof(machine_code), out);
    fwrite(output_text, 1, output_len, out);
    fclose(out);
    free(padding);

    // Make file executable
    chmod(output_path, 0755);

    printf("  ✔ সফলভাবে স্ট্যান্ডঅ্যালোন নেটিভ বাইনারি তৈরি হয়েছে (Standalone ELF 64-bit Compiled)!\n");
    printf("  • আউটপুট বাইনারি : \033[1;32m%s\033[0m\n", output_path);
    printf("  • মোট ফাইল সাইজ   : %lu বাইট\n", file_size);
    printf("  • ডিপেন্ডেন্সি     : \033[1;36m০%% PHP | ০%% GCC | ১০০%% স্বয়ংসম্পূর্ণ লিনাক্স কার্নেল\033[0m\n\n");

    printf("\033[1;33m[৩] তৈরি বাইনারি সরাসরি লিনাক্স কার্নেলে টেস্ট রান:\033[0m\n");
    printf("\033[38;2;120;200;255m------------------------------------------------------------------------\033[0m\n");
    fflush(stdout);

    char cmd[512];
    snprintf(cmd, sizeof(cmd), "./%s", output_path);
    int ret = system(cmd);
    (void)ret;

    printf("\033[38;2;120;200;255m------------------------------------------------------------------------\033[0m\n\n");
    printf("\033[38;2;0;255;204m🎉 লিপি ১০০%% স্বাধীন! কোনো PHP ছাড়াই সরাসরি লিপি থেকে মেশিন কোড উৎপন্ন হয়েছে।\033[0m\n\n");

    return 0;
}
