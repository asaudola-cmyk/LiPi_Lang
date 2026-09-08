/**
 * 👑 Lipi Native CLI Bootstrap & Launcher (লিপি নেটিভ লঞ্চার)
 *
 * Compiles into a standalone Linux binary: `bin/lipi-native`.
 * Dynamically resolves framework root, manages execution, handles arguments,
 * and allows executing Lipi programs directly as a native system binary.
 *
 * @author Shafiullah (Gyani Supreme Core)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <libgen.h>
#include <limits.h>

void print_banner() {
    printf("\033[38;2;0;255;204m╔════════════════════════════════════════════════════════════════════════╗\033[0m\n");
    printf("\033[38;2;0;255;204m║\033[0m  \033[1;38;2;255;255;255m👑 LIPI (লিপি) — STANDALONE NATIVE SILICON CLI ENGINE\033[0m                 \033[38;2;0;255;204m║\033[0m\n");
    printf("\033[38;2;0;255;204m║\033[0m  \033[38;2;180;180;180m⚡ Native Linux ELF Launcher | Pure Bilingual Unicode | Zero Bloat\033[0m    \033[38;2;0;255;204m║\033[0m\n");
    printf("\033[38;2;0;255;204m╚════════════════════════════════════════════════════════════════════════╝\033[0m\n\n");
}

int main(int argc, char *argv[]) {
    char exe_path[PATH_MAX];
    ssize_t len = readlink("/proc/self/exe", exe_path, sizeof(exe_path) - 1);
    if (len != -1) {
        exe_path[len] = '\0';
    } else {
        strncpy(exe_path, argv[0], sizeof(exe_path));
    }

    char *dir = dirname(exe_path);
    char framework_root[PATH_MAX];
    snprintf(framework_root, sizeof(framework_root), "%s/..", dir);

    char script_path[PATH_MAX];
    snprintf(script_path, sizeof(script_path), "%s/bin/lipi", framework_root);

    if (argc < 2 || strcmp(argv[1], "help") == 0 || strcmp(argv[1], "--help") == 0 || strcmp(argv[1], "-h") == 0) {
        print_banner();
        printf("\033[1;33mব্যবহারবিধি (Usage via Native Binary):\033[0m\n");
        printf("  ./bin/lipi-native run <file.lp>       লিপি ফাইল সরাসরি রান করুন\n");
        printf("  ./bin/lipi-native build <file.lp>     লিনাক্স স্ট্যান্ডঅ্যালোন ELF বাইনারি তৈরি করুন\n");
        printf("  ./bin/lipi-native init [name]         নতুন লিপি প্রজেক্ট ও lipi.json তৈরি করুন\n");
        printf("  ./bin/lipi-native add <pkg>           প্রজেক্টে নতুন ডিপেন্ডেন্সি যুক্ত করুন\n");
        printf("  ./bin/lipi-native install             সকল lipi_modules ডিপেন্ডেন্সি ইনস্টল করুন\n");
        printf("  ./bin/lipi-native test                প্রজেক্ট টেস্ট সুইট স্বয়ংক্রিয়ভাবে চালান\n");
        printf("  ./bin/lipi-native repl                ইন্টারেক্টিভ টার্মিনাল প্রম্পট চালু করুন\n\n");
        return 0;
    }

    // Build argument vector to forward to the Lipi engine
    char **new_argv = malloc((argc + 2) * sizeof(char *));
    new_argv[0] = "php";
    new_argv[1] = script_path;
    for (int i = 1; i < argc; i++) {
        new_argv[i + 1] = argv[i];
    }
    new_argv[argc + 1] = NULL;

    execvp("php", new_argv);

    // If execvp failed (e.g. php not found in PATH), alert user
    perror("\033[1;31m[Error] Failed to dispatch Lipi command\033[0m");
    free(new_argv);
    return 1;
}
