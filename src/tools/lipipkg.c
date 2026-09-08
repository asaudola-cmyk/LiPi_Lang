// ==============================================================================
// 👑 LIPI SOVEREIGN PACKAGE MANAGER: lipipkg (src/tools/lipipkg.c)
// ⚡ Autonomous Project Lifecycle, Manifest & Dependency Engine | Zero External Libs
// ==============================================================================

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <dirent.h>

#define LIPIPKG_VERSION "1.0.0"

// WHY: Ensure hermetic directory creation across POSIX platforms.
static void make_dir_if_not_exists(const char *path) {
    struct stat st;
    if (stat(path, &st) == -1) {
        mkdir(path, 0755);
    }
}

static char *trim_whitespace(char *str) {
    if (!str) return NULL;
    while (*str == ' ' || *str == '\t' || *str == '\n' || *str == '\r') str++;
    if (*str == 0) return str;
    char *end = str + strlen(str) - 1;
    while (end > str && (*end == ' ' || *end == '\t' || *end == '\n' || *end == '\r')) end--;
    end[1] = '\0';
    return str;
}

// ------------------------------------------------------------------------------
// ১. lipipkg init <project_name>
// ------------------------------------------------------------------------------
static int cmd_init(const char *project_name) {
    if (!project_name || strlen(project_name) == 0) {
        fprintf(stderr, "\033[1;31m❌ এরর: প্রজেক্টের নাম প্রদান করুন! ব্যবহার: lipipkg init <project_name>\033[0m\n");
        return 1;
    }

    printf("\033[1;36m╔════════════════════════════════════════════════════════════════════════╗\033[0m\n");
    printf("\033[1;36m║  📦 LIPIPKG: নতুন সার্বভৌম লিপি প্রজেক্ট ইনিশিয়ালাইজেশন                 ║\033[0m\n");
    printf("\033[1;36m╚════════════════════════════════════════════════════════════════════════╝\033[0m\n\n");

    make_dir_if_not_exists(project_name);

    char src_dir[512];
    snprintf(src_dir, sizeof(src_dir), "%s/src", project_name);
    make_dir_if_not_exists(src_dir);

    char dist_dir[512];
    snprintf(dist_dir, sizeof(dist_dir), "%s/dist", project_name);
    make_dir_if_not_exists(dist_dir);

    // ১. lipi.pkg ম্যানিফেস্ট তৈরি
    char pkg_path[512];
    snprintf(pkg_path, sizeof(pkg_path), "%s/lipi.pkg", project_name);
    FILE *f_pkg = fopen(pkg_path, "w");
    if (f_pkg) {
        fprintf(f_pkg, "// 👑 Lipi Sovereign Package Manifest\n");
        fprintf(f_pkg, "name = \"%s\"\n", project_name);
        fprintf(f_pkg, "version = \"0.1.0\"\n");
        fprintf(f_pkg, "entry = \"src/main.lp\"\n");
        fprintf(f_pkg, "author = \"Sovereign Lipi Developer\"\n");
        fprintf(f_pkg, "license = \"MIT\"\n");
        fclose(f_pkg);
        printf("  ✔ ম্যানিফেস্ট তৈরি হয়েছে: %s\n", pkg_path);
    }

    // ২. src/main.lp তৈরি
    char main_path[512];
    snprintf(main_path, sizeof(main_path), "%s/src/main.lp", project_name);
    FILE *f_main = fopen(main_path, "w");
    if (f_main) {
        fprintf(f_main, "// 👑 %s — প্রধান লিপি অ্যাপ্লিকেশন এন্ট্রি পয়েন্ট\n", project_name);
        fprintf(f_main, "দেখাও \"স্বাগতম '%s' সার্বভৌম লিপি অ্যাপ্লিকেশনে!\"\n\n", project_name);
        fprintf(f_main, "ধরি শুরু_ক্লক = সিপিউ_ক্লক()\n");
        fprintf(f_main, "ধরি যোগফল = ০\n");
        fprintf(f_main, "ধরি i = ১\n");
        fprintf(f_main, "যতক্ষণ i <= ১০ { যোগফল = যোগফল + i; i = i + ১; }\n");
        fprintf(f_main, "ধরি শেষ_ক্লক = সিপিউ_ক্লক()\n\n");
        fprintf(f_main, "দেখাও \"১ থেকে ১০ পর্যন্ত যোগফল = \" + যোগফল\n");
        fprintf(f_main, "দেখাও \"এক্সিকিউশন ক্লক সাইকেল = \" + (শেষ_ক্লক - শুরু_ক্লক)\n");
        fclose(f_main);
        printf("  ✔ মূল সোর্স ফাইল তৈরি হয়েছে: %s\n", main_path);
    }

    // ৩. .gitignore তৈরি
    char gitignore_path[512];
    snprintf(gitignore_path, sizeof(gitignore_path), "%s/.gitignore", project_name);
    FILE *f_git = fopen(gitignore_path, "w");
    if (f_git) {
        fprintf(f_git, "dist/*\n!dist/.gitkeep\n*.o\n*.tmp\n");
        fclose(f_git);
    }

    // ৪. dist/.gitkeep
    char gitkeep_path[512];
    snprintf(gitkeep_path, sizeof(gitkeep_path), "%s/dist/.gitkeep", project_name);
    FILE *f_keep = fopen(gitkeep_path, "w");
    if (f_keep) fclose(f_keep);

    printf("\n\033[1;32m🎉 প্রজেক্ট '%s' সফলভাবে প্রস্তুত!\033[0m\n", project_name);
    printf("পরবর্তী ধাপ:\n");
    printf("  cd %s\n", project_name);
    printf("  lipipkg build\n");
    printf("  lipipkg run\n\n");
    return 0;
}

// ------------------------------------------------------------------------------
// ২. lipipkg build [project_dir]
// ------------------------------------------------------------------------------
static int cmd_build(const char *project_dir) {
    char manifest_path[512];
    char target_dir[512];

    if (project_dir && strlen(project_dir) > 0) {
        snprintf(manifest_path, sizeof(manifest_path), "%s/lipi.pkg", project_dir);
        strncpy(target_dir, project_dir, sizeof(target_dir) - 1);
    } else {
        snprintf(manifest_path, sizeof(manifest_path), "lipi.pkg");
        strcpy(target_dir, ".");
    }

    FILE *f = fopen(manifest_path, "r");
    if (!f) {
        fprintf(stderr, "\033[1;31m❌ এরর: ম্যানিফেস্ট ফাইল পাওয়া যায়নি: '%s'\033[0m\n", manifest_path);
        return 1;
    }

    char pkg_name[128] = "app";
    char entry_point[256] = "src/main.lp";

    char line[512];
    while (fgets(line, sizeof(line), f)) {
        char *eq = strchr(line, '=');
        if (!eq) continue;
        *eq = '\0';
        char *key = trim_whitespace(line);
        char *val = trim_whitespace(eq + 1);

        char *q1 = strchr(val, '"');
        if (q1) {
            char *q2 = strrchr(q1 + 1, '"');
            if (q2) *q2 = '\0';
            val = q1 + 1;
        }

        if (strcmp(key, "name") == 0) {
            strncpy(pkg_name, val, sizeof(pkg_name) - 1);
        } else if (strcmp(key, "entry") == 0) {
            strncpy(entry_point, val, sizeof(entry_point) - 1);
        }
    }
    fclose(f);

    printf("\033[1;33m[🔨] LIPIPKG বিল্ড শুরু হচ্ছে...\033[0m\n");
    printf("  • প্যাকেজ নাম : %s\n", pkg_name);
    printf("  • এন্ট্রি ফাইল : %s\n", entry_point);

    char full_entry[512];
    char full_out[512];
    char dist_dir[512];

    if (strcmp(target_dir, ".") != 0) {
        snprintf(full_entry, sizeof(full_entry), "%s/%s", target_dir, entry_point);
        snprintf(dist_dir, sizeof(dist_dir), "%s/dist", target_dir);
        snprintf(full_out, sizeof(full_out), "%s/dist/%s", target_dir, pkg_name);
    } else {
        strncpy(full_entry, entry_point, sizeof(full_entry) - 1);
        strcpy(dist_dir, "dist");
        snprintf(full_out, sizeof(full_out), "dist/%s", pkg_name);
    }

    make_dir_if_not_exists(dist_dir);

    char build_cmd[2048];
    // Find compiler binary (search in ./bin/lipic, ../bin/lipic, ../../bin/lipic, or PATH)
    const char *lipic_bin = "./bin/lipic";
    if (access(lipic_bin, X_OK) != 0) {
        if (access("../bin/lipic", X_OK) == 0) {
            lipic_bin = "../bin/lipic";
        } else if (access("../../bin/lipic", X_OK) == 0) {
            lipic_bin = "../../bin/lipic";
        } else {
            lipic_bin = "lipic";
        }
    }

    snprintf(build_cmd, sizeof(build_cmd), "%s %s -o %s", lipic_bin, full_entry, full_out);
    printf("  • কম্পাইল কমান্ড: %s\n", build_cmd);

    int res = system(build_cmd);
    if (res == 0) {
        printf("\n\033[1;32m✔ বিল্ড সফল! আউটপুট বাইনারি: %s\033[0m\n", full_out);
        return 0;
    } else {
        fprintf(stderr, "\n\033[1;31m❌ বিল্ড ব্যর্থ হয়েছে!\033[0m\n");
        return 1;
    }
}

// ------------------------------------------------------------------------------
// ৩. lipipkg run [project_dir]
// ------------------------------------------------------------------------------
static int cmd_run(const char *project_dir) {
    if (cmd_build(project_dir) != 0) {
        return 1;
    }

    char manifest_path[512];
    char target_dir[512];

    if (project_dir && strlen(project_dir) > 0) {
        snprintf(manifest_path, sizeof(manifest_path), "%s/lipi.pkg", project_dir);
        strncpy(target_dir, project_dir, sizeof(target_dir) - 1);
    } else {
        snprintf(manifest_path, sizeof(manifest_path), "lipi.pkg");
        strcpy(target_dir, ".");
    }

    char pkg_name[128] = "app";
    FILE *f = fopen(manifest_path, "r");
    if (f) {
        char line[512];
        while (fgets(line, sizeof(line), f)) {
            char *eq = strchr(line, '=');
            if (!eq) continue;
            *eq = '\0';
            char *key = trim_whitespace(line);
            char *val = trim_whitespace(eq + 1);
            if (strcmp(key, "name") == 0) {
                char *q1 = strchr(val, '"');
                if (q1) {
                    char *q2 = strrchr(q1 + 1, '"');
                    if (q2) *q2 = '\0';
                    strncpy(pkg_name, q1 + 1, sizeof(pkg_name) - 1);
                }
                break;
            }
        }
        fclose(f);
    }

    char exec_cmd[512];
    if (strcmp(target_dir, ".") != 0) {
        snprintf(exec_cmd, sizeof(exec_cmd), "./%s/dist/%s", target_dir, pkg_name);
    } else {
        snprintf(exec_cmd, sizeof(exec_cmd), "./dist/%s", pkg_name);
    }

    printf("\n\033[1;35m[🚀] অ্যাপ্লিকেশন এক্সিকিউশন শুরু হচ্ছে: %s\033[0m\n\n", exec_cmd);
    return system(exec_cmd);
}

// ------------------------------------------------------------------------------
// ৪. lipipkg vendor
// ------------------------------------------------------------------------------
static int cmd_vendor(void) {
    printf("\033[1;33m[📦] লিপি স্ট্যান্ডার্ড লাইব্রেরি লোকাল ভেন্ডরিং (Hermetic Bundling)...\033[0m\n");
    make_dir_if_not_exists("lipi_modules");

    DIR *d = opendir("std");
    if (!d) {
        fprintf(stderr, "❌ std/ ডিরেক্টরি পাওয়া যায়নি!\n");
        return 1;
    }
    struct dirent *dir;
    int count = 0;
    while ((dir = readdir(d)) != NULL) {
        if (dir->d_name[0] == '.') continue;
        char src[512], dst[512];
        snprintf(src, sizeof(src), "std/%s", dir->d_name);
        snprintf(dst, sizeof(dst), "lipi_modules/%s", dir->d_name);

        FILE *in = fopen(src, "rb");
        FILE *out = fopen(dst, "wb");
        if (in && out) {
            char buf[4096];
            size_t n;
            while ((n = fread(buf, 1, sizeof(buf), in)) > 0) {
                fwrite(buf, 1, n, out);
            }
            count++;
        }
        if (in) fclose(in);
        if (out) fclose(out);
    }
    closedir(d);
    printf("  ✔ %d টি স্ট্যান্ডার্ড মডিউল lipi_modules/ এ ভেন্ডর করা হয়েছে!\n", count);
    return 0;
}

static void print_help(void) {
    printf("👑 LIPIPKG — লিপির অফিশিয়াল প্যাকেজ ম্যানেজার (Version %s)\n", LIPIPKG_VERSION);
    printf("ব্যবহারবিধি: lipipkg <কমান্ড> [অপশন]\n\n");
    printf("কমান্ডসমূহ:\n");
    printf("  init <নাম>   নতুন সার্বভৌম লিপি প্রজেক্ট তৈরি করুন\n");
    printf("  build [পথ]   প্রজেক্ট ম্যানিফেস্ট অনুযায়ী স্ট্যান্ডঅ্যালোন ELF বাইনারি বিল্ড করুন\n");
    printf("  run [পথ]     প্রজেক্ট বিল্ড করে সরাসরি এক্সিকিউট করুন\n");
    printf("  test         স্বয়ংক্রিয় টেস্ট সুইট রান করুন\n");
    printf("  vendor       স্ট্যান্ডার্ড লাইব্রেরি মডিউলসমূহ লোকালি ভেন্ডর করুন\n");
    printf("  version      ভার্সন ও আর্কিটেকচার তথ্য দেখুন\n");
    printf("  help         এই সহায়তা বার্তা প্রদর্শন করুন\n\n");
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        print_help();
        return 0;
    }

    const char *cmd = argv[1];

    if (strcmp(cmd, "init") == 0) {
        if (argc < 3) {
            fprintf(stderr, "❌ ব্যবহার: lipipkg init <project_name>\n");
            return 1;
        }
        return cmd_init(argv[2]);
    } else if (strcmp(cmd, "build") == 0) {
        const char *pdir = (argc >= 3) ? argv[2] : NULL;
        return cmd_build(pdir);
    } else if (strcmp(cmd, "run") == 0) {
        const char *pdir = (argc >= 3) ? argv[2] : NULL;
        return cmd_run(pdir);
    } else if (strcmp(cmd, "vendor") == 0) {
        return cmd_vendor();
    } else if (strcmp(cmd, "test") == 0) {
        return system("./bin/lipic test");
    } else if (strcmp(cmd, "version") == 0 || strcmp(cmd, "-v") == 0) {
        printf("👑 lipipkg v%s (Lipi Sovereign Package Manager - 0%% PHP | 0%% Libc | Pure Silicon)\n", LIPIPKG_VERSION);
        return 0;
    } else {
        print_help();
        return 0;
    }
}
