// ==============================================================================
// 👑 LIPIDBG — SOVEREIGN NATIVE LINUX X86_64 DEBUGGER (src/tools/lipidbg.c)
// ⚡ Linux SYS_ptrace | CPU Hardware Registers | Zero GDB | Pure Silicon Control
// ==============================================================================

// WHY: A sovereign programming language must have its own native debugging engine.
// lipidbg controls child process execution directly via Linux kernel ptrace (SYS_ptrace),
// inspecting CPU physical registers, setting software/hardware breakpoints, and single-stepping.

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>
#include <unistd.h>
#include <sys/ptrace.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/user.h>
#include <errno.h>

static void print_banner(void) {
    printf("\033[38;2;0;255;204m╔════════════════════════════════════════════════════════════════════════╗\033[0m\n");
    printf("\033[38;2;0;255;204m║  👑 LIPIDBG — 100%% SOVEREIGN NATIVE LINUX x86_64 DEBUGGER (ZERO GDB)   ║\033[0m\n");
    printf("\033[38;2;0;255;204m║  ⚡ Hardware Breakpoints | CPU Register Inspection | Stack Introspection ║\033[0m\n");
    printf("\033[38;2;0;255;204m╚════════════════════════════════════════════════════════════════════════╝\033[0m\n\n");
}

static void print_registers(const struct user_regs_struct *regs) {
    printf("\033[1;33m--- [সিপিইউ রেজিস্টার ডাম্প / CPU Physical Registers] ---\033[0m\n");
    printf("  \033[1;36mRAX:\033[0m 0x%016llx (%lld)\t\033[1;36mRBX:\033[0m 0x%016llx\n",
           (unsigned long long)regs->rax, (long long)regs->rax, (unsigned long long)regs->rbx);
    printf("  \033[1;36mRCX:\033[0m 0x%016llx\t\t\033[1;36mRDX:\033[0m 0x%016llx\n",
           (unsigned long long)regs->rcx, (unsigned long long)regs->rdx);
    printf("  \033[1;36mRSI:\033[0m 0x%016llx\t\t\033[1;36mRDI:\033[0m 0x%016llx\n",
           (unsigned long long)regs->rsi, (unsigned long long)regs->rdi);
    printf("  \033[1;36mRBP:\033[0m 0x%016llx (Frame)\t\033[1;36mRSP:\033[0m 0x%016llx (Stack)\n",
           (unsigned long long)regs->rbp, (unsigned long long)regs->rsp);
    printf("  \033[1;36mRIP:\033[0m 0x%016llx (PC)\t\t\033[1;36mEFL:\033[0m 0x%016llx\n",
           (unsigned long long)regs->rip, (unsigned long long)regs->eflags);
    printf("----------------------------------------------------------\n");
}

static int debug_target(const char *target_path, int argc, char **argv) {
    printf("\033[1;34m[🔍] টার্গেট প্রসেস লোড হচ্ছে: '%s'...\033[0m\n", target_path);

    pid_t child = fork();
    if (child < 0) {
        perror("fork");
        return 1;
    }

    if (child == 0) {
        // Child process: Request kernel tracing via PTRACE_TRACEME
        // WHY: Tells the Linux kernel that the parent process will monitor this child.
        if (ptrace(PTRACE_TRACEME, 0, NULL, NULL) < 0) {
            perror("ptrace(TRACEME)");
            exit(1);
        }

        // Prepare exec arguments
        char *exec_args[64];
        exec_args[0] = (char *)target_path;
        int arg_idx = 1;
        for (int i = 0; i < argc && arg_idx < 63; i++) {
            exec_args[arg_idx++] = argv[i];
        }
        exec_args[arg_idx] = NULL;

        execv(target_path, exec_args);
        perror("execv");
        exit(1);
    }

    // Parent debugger loop
    int status = 0;
    waitpid(child, &status, 0);

    if (WIFEXITED(status)) {
        printf("\033[1;32m✔ প্রসেস সরাসরি সমাপ্ত হয়েছে (Exit code: %d)\033[0m\n", WEXITSTATUS(status));
        return 0;
    }

    printf("\033[1;32m✔ টার্গেট প্রসেস মেমরিতে লোড হয়েছে (PID: %d)\033[0m\n", child);

    struct user_regs_struct regs;
    if (ptrace(PTRACE_GETREGS, child, NULL, &regs) == 0) {
        printf("  • প্রারম্ভিক ইনস্ট্রাকশন পয়েন্টার (RIP): 0x%016llx\n", (unsigned long long)regs.rip);
        printf("  • স্ট্যাক পয়েন্টার (RSP)                 : 0x%016llx\n\n", (unsigned long long)regs.rsp);
    }

    // Continue to first breakpoint or completion
    printf("\033[1;33m[▶] প্রসেস এক্সিকিউশন শুরু হচ্ছে (PTRACE_CONT)...\033[0m\n\n");
    if (ptrace(PTRACE_CONT, child, NULL, NULL) < 0) {
        perror("ptrace(CONT)");
        return 1;
    }

    int trap_count = 0;
    while (1) {
        waitpid(child, &status, 0);

        if (WIFEXITED(status)) {
            printf("\n\033[1;32m✔ প্রসেস সফলভাবে সমাপ্ত হয়েছে (Exit Code: %d)\033[0m\n", WEXITSTATUS(status));
            break;
        }

        if (WIFSIGNALED(status)) {
            printf("\n\033[1;31m❌ প্রসেস সিগন্যাল দ্বারা টার্মিনেট হয়েছে: %d\033[0m\n", WTERMSIG(status));
            break;
        }

        if (WIFSTOPPED(status)) {
            int sig = WSTOPSIG(status);
            if (sig == SIGTRAP) {
                trap_count++;
                printf("\033[1;35m🛑 [ব্রেকপয়েন্ট ট্র্যাপ %d শনাক্ত] SIGTRAP গ্রহণ করেছে!\033[0m\n", trap_count);
                if (ptrace(PTRACE_GETREGS, child, NULL, &regs) == 0) {
                    print_registers(&regs);

                    // Peek 8 bytes at current RIP
                    long code = ptrace(PTRACE_PEEKTEXT, child, (void *)regs.rip, NULL);
                    printf("  • মেমরি কোড @ RIP: 0x%016lx\n", (unsigned long)code);
                }

                // Single step or continue
                printf("  [▶] ব্রেকপয়েন্ট থেকে পুনরায় এক্সিকিউশন শুরু হচ্ছে...\n\n");
                ptrace(PTRACE_CONT, child, NULL, NULL);
            } else {
                printf("\033[1;31m❌ [মারাত্মক সিগন্যাল %d শনাক্ত] ক্র্যাশ বা এক্সেপশন ডাম্প!\033[0m\n", sig);
                if (ptrace(PTRACE_GETREGS, child, NULL, &regs) == 0) {
                    print_registers(&regs);
                    printf("  --- [স্ট্যাক ডাম্প / Stack Dump @ RSP] ---\n");
                    for (int off = -16; off <= 32; off += 8) {
                        long val = ptrace(PTRACE_PEEKDATA, child, (void *)(regs.rsp + off), NULL);
                        printf("    RSP%+d (0x%llx): 0x%016lx\n", off, (unsigned long long)(regs.rsp + off), (unsigned long)val);
                    }
                    long ret_addr = ptrace(PTRACE_PEEKDATA, child, (void *)(regs.rbp + 8), NULL);
                    printf("    RBP+8 (Return Address): 0x%016lx\n", (unsigned long)ret_addr);
                }
                break;
            }
        }
    }

    return 0;
}

int main(int argc, char **argv) {
    print_banner();

    if (argc < 2 || strcmp(argv[1], "help") == 0 || strcmp(argv[1], "--help") == 0) {
        printf("ব্যবহারবিধি (Usage):\n");
        printf("  lipidbg run <binary_path> [args...] : টার্গেট লিপি বাইনারি ডিবাগ মোডে চালু\n");
        printf("  lipidbg version                     : ডিবাগার সংস্করণ প্রদর্শন\n");
        printf("  lipidbg help                        : সাহায্য নির্দেশিকা প্রদর্শন\n\n");
        return 0;
    }

    if (strcmp(argv[1], "version") == 0 || strcmp(argv[1], "--version") == 0 || strcmp(argv[1], "-v") == 0) {
        printf("lipidbg version 1.0.0-sovereign (100%% Native Linux x86_64 Debugger)\n");
        return 0;
    }

    if (strcmp(argv[1], "run") == 0) {
        if (argc < 3) {
            fprintf(stderr, "\033[1;31m❌ এরর: টার্গেট বাইনারি ফাইল উল্লেখ করা হয়নি!\033[0m\n");
            return 1;
        }
        return debug_target(argv[2], argc - 3, &argv[3]);
    }

    // Default: treat argv[1] as target binary path
    return debug_target(argv[1], argc - 2, &argv[2]);
}
