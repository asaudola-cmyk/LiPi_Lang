/* ==============================================================================
 * Lipi Native REPL — 100% Sovereign & Independent
 * Version: First 1.0 (প্রথম ১.০)
 * File: src/runtime/native_repl.c
 * 
 * WHY: Provides an interactive Read-Eval-Print Loop using the native
 *      Lipi self-hosted compiler without any Python runtime dependency.
 * ============================================================================== */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>

#define MAX_LINE 4096
#define MAX_HISTORY 65536

static char session_code[MAX_HISTORY] = "";

int main(int argc, char** argv) {
    char line[MAX_LINE];
    char lipi_home[1024];

    /* Determine LIPI_HOME */
    const char* env_home = getenv("LIPI_HOME");
    if (env_home && strlen(env_home) > 0) {
        snprintf(lipi_home, sizeof(lipi_home), "%s", env_home);
    } else {
        /* Fallback to current working directory */
        snprintf(lipi_home, sizeof(lipi_home), ".");
    }

    printf("\n  ██╗     ██╗██████╗ ██╗\n");
    printf("  ██║     ██║██╔══██╗██║\n");
    printf("  ██║     ██║██████╔╝██║\n");
    printf("  ██║     ██║██╔═══╝ ██║\n");
    printf("  ███████╗██║██║     ██║\n");
    printf("  ╚══════╝╚═╝╚═╝     ╚═╝\n\n");
    printf("  Lipi First 1.0 (প্রথম ১.০) — Sovereign [Native REPL]\n");
    printf("  Type 'exit', 'quit' or 'বের' to quit. 'clear' to reset.\n");
    printf("  ──────────────────────────────────────────────────────────\n\n");

    while (1) {
        printf("lipi> ");
        fflush(stdout);

        if (!fgets(line, sizeof(line), stdin)) {
            printf("\n");
            break;
        }

        /* Trim newline and trailing spaces */
        size_t len = strlen(line);
        while (len > 0 && (line[len - 1] == '\n' || line[len - 1] == '\r' || line[len - 1] == ' ')) {
            line[--len] = '\0';
        }

        if (len == 0) continue;

        if (strcmp(line, "exit") == 0 || strcmp(line, "quit") == 0 ||
            strcmp(line, ":q") == 0 || strcmp(line, "বের") == 0) {
            break;
        }

        if (strcmp(line, "clear") == 0 || strcmp(line, "reset") == 0) {
            session_code[0] = '\0';
            printf("  Session state cleared.\n");
            continue;
        }

        /* Create temporary trial file with existing session + new line */
        char tmp_lp[256], tmp_bin[256], cmd[2048];
        snprintf(tmp_lp, sizeof(tmp_lp), "/tmp/lipi_repl_%d.lp", getpid());
        snprintf(tmp_bin, sizeof(tmp_bin), "/tmp/lipi_repl_%d", getpid());

        FILE* f = fopen(tmp_lp, "w");
        if (!f) {
            perror("fopen");
            continue;
        }
        /* Write session so far */
        if (strlen(session_code) > 0) {
            fputs(session_code, f);
            fputc('\n', f);
        }

        /* If line looks like an expression (not assignment, fn, if, for, while, say), wrap in say */
        if (strncmp(line, "say ", 4) != 0 &&
            strncmp(line, "print ", 6) != 0 &&
            strncmp(line, "fn ", 3) != 0 &&
            strncmp(line, "if ", 3) != 0 &&
            strncmp(line, "for ", 4) != 0 &&
            strncmp(line, "while ", 6) != 0 &&
            strncmp(line, "struct ", 7) != 0 &&
            strchr(line, '=') == NULL) {
            fprintf(f, "say %s\n", line);
        } else {
            fprintf(f, "%s\n", line);
        }
        fclose(f);

        /* Compile with bin/lipc */
        snprintf(cmd, sizeof(cmd), "%s/bin/lipc %s -o %s >/dev/null 2>&1", lipi_home, tmp_lp, tmp_bin);
        int compile_res = system(cmd);

        if (compile_res == 0) {
            /* Run the compiled binary */
            int run_res = system(tmp_bin);
            (void)run_res;

            /* Append line to session history so variable assignments and functions persist */
            strncat(session_code, line, sizeof(session_code) - strlen(session_code) - 2);
            strcat(session_code, "\n");
        } else {
            printf("❌ Compile Error: check syntax\n");
        }

        unlink(tmp_lp);
        unlink(tmp_bin);
    }

    return 0;
}
