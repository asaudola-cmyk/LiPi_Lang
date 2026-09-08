/**
 * 👑 Lipi Native Compiler CLI Launcher (lipic) — লিপি নেটিভ কম্পাইলার
 *
 * Compiles into standalone Linux binary: `bin/lipic`.
 * Provides direct command-line compilation of Lipi (.lp) files into standalone
 * Linux ELF 64-bit native executables (Zero PHP / Zero GCC at runtime).
 *
 * Usage:
 *   lipic <file.lp> [-o output_binary]
 *   lipic build <file.lp> -o <output_binary>
 *   lipic --self-host
 *   lipic --version
 *
 * @author Shafiullah (Gyani Supreme Core)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <libgen.h>
#include <limits.h>

void print_banner(void) {
    printf("\033[38;2;0;255;204m╔════════════════════════════════════════════════════════════════════════╗\033[0m\n");
    printf("\033[38;2;0;255;204m║\033[0m  \033[1;38;2;255;255;255m👑 LIPIC (লিপিক) — LIPI STANDALONE NATIVE ELF COMPILER\033[0m               \033[38;2;0;255;204m║\033[0m\n");
    printf("\033[38;2;0;255;204m║\033[0m  \033[38;2;180;180;180m⚡ Standalone Linux ELF 64-bit Binary Compiler | Zero Runtime Overhead\033[0m \033[38;2;0;255;204m║\033[0m\n");
    printf("\033[38;2;0;255;204m╚════════════════════════════════════════════════════════════════════════╝\033[0m\n\n");
}

int main(int argc, char *argv[]) {
    char exe_path[PATH_MAX];
    ssize_t len = readlink("/proc/self/exe", exe_path, sizeof(exe_path) - 1);
    if (len != -1) {
        exe_path[len] = '\0';
    } else {
        strncpy(exe_path, argv[0], sizeof(exe_path) - 1);
        exe_path[sizeof(exe_path) - 1] = '\0';
    }

    char *dir = dirname(exe_path);
    char framework_root[PATH_MAX * 2];
    snprintf(framework_root, sizeof(framework_root), "%s/..", dir);

    char script_path[PATH_MAX * 2];
    snprintf(script_path, sizeof(script_path), "%s/bin/lipi", framework_root);

    if (argc < 2 || strcmp(argv[1], "help") == 0 || strcmp(argv[1], "--help") == 0 || strcmp(argv[1], "-h") == 0) {
        print_banner();
        printf("\033[1;33mব্যবহারবিধি (Compiler Usage):\033[0m\n");
        printf("  ./bin/lipic <source.lp> [-o <binary>]   লিপি সোর্স কোডকে সরাসরি স্ট্যান্ডঅ্যালোন লিনাক্স ELF বাইনারিতে রূপান্তর করুন\n");
        printf("  ./bin/lipic build <source.lp>           লিপি বিল্ড কমান্ড চালান\n");
        printf("  ./bin/lipic --self-host                 লিপির নিজস্ব কম্পাইলার কোর দিয়ে সেলফ-হোস্টিং যাচাই করুন\n");
        printf("  ./bin/lipic --version                   কম্পাইলার সংস্করণ প্রদর্শন করুন\n\n");
        printf("\033[1;33mউদাহরণ (Examples):\033[0m\n");
        printf("  ./bin/lipic examples/01_hello.lp -o dist/my_app\n");
        printf("  ./dist/my_app                           (সরাসরি লিনাক্স কার্নেলে জিরো ডিপেন্ডেন্সিতে রান করে!)\n\n");
        return 0;
    }

    if (strcmp(argv[1], "--version") == 0 || strcmp(argv[1], "-v") == 0) {
        printf("lipic version 2.0.0-sovereign (Linux x86_64 ELF Native Compiler)\n");
        return 0;
    }

    // Special flag: --self-host executes the pure Lipi compiler core
    if (strcmp(argv[1], "--self-host") == 0) {
        char compiler_lp[PATH_MAX * 2];
        snprintf(compiler_lp, sizeof(compiler_lp), "%s/src/Lipi/compiler.lp", framework_root);
        char *self_host_argv[] = {
            "php",
            script_path,
            "run",
            compiler_lp,
            NULL
        };
        execvp("php", self_host_argv);
        perror("\033[1;31m[Error] Failed to execute Lipi self-hosting compiler\033[0m");
        return 1;
    }

    // If first argument is a .lp file without 'build', automatically prepend 'build'
    int has_build = (strcmp(argv[1], "build") == 0 || strcmp(argv[1], "compile") == 0);
    int extra_args = has_build ? 0 : 1;

    char **new_argv = malloc((argc + 3 + extra_args) * sizeof(char *));
    new_argv[0] = "php";
    new_argv[1] = script_path;
    new_argv[2] = "build";

    int dst = 3;
    int src = has_build ? 2 : 1;
    for (int i = src; i < argc; i++) {
        new_argv[dst++] = argv[i];
    }
    new_argv[dst] = NULL;

    execvp("php", new_argv);

    perror("\033[1;31m[Error] Failed to dispatch Lipi compiler\033[0m");
    free(new_argv);
    return 1;
}
