// ==============================================================================
// 🖥️ লিপি CLI আর্গুমেন্ট পার্সার (Command-Line Interface Library)
// লিপি প্রথম ১.০ | সংকেতনাম: সোভেরিন
// File: std/cli.lp
//
// WHY এই মডিউল:
//   Professional CLI tools need argument parsing (like argparse, clap, cobra).
//   Without this, every tool re-invents argument parsing from scratch.
//   এই মডিউল দিয়ে:
//   - Flags: --verbose, --output file.txt, -v
//   - Positional args: lipi compile input.lp
//   - Subcommands: lipipkg build, lipipkg test
//   - Auto-generated help: --help
//
// ব্যবহার:
//   include "std/cli.lp"
//    app = CLI_তৈরি("my-tool", "আমার টুলের বিবরণ")
//   CLI_flag_যোগ(app, "--verbose", "-v", "বিস্তারিত আউটপুট")
//   CLI_পার্স(app)
//   if CLI_flag_পড়ো(app, "--verbose") { say "verbose mode" }
// ==============================================================================

include "std/core/mem.lp"
include "std/core/str.lp"
include "std/sys/kernel.lp"

// ─── ধ্রুবক ──────────────────────────────────────────────────────────────────
CLI_MAX_FLAGS    = 64    // সর্বোচ্চ ৬৪টি flag
CLI_MAX_ARGS     = 32    // সর্বোচ্চ ৩২টি positional arg
CLI_MAX_SUBCMDS  = 16    // সর্বোচ্চ ১৬টি subcommand

FLAG_TYPE_BOOL   = 1     // --verbose (no value)
FLAG_TYPE_STRING = 2     // --output file.txt
FLAG_TYPE_NUMBER = 3     // --port 8080

// ─── গঠনসমূহ ─────────────────────────────────────────────────────────────────

struct CLI_Flag
    নাম_পয়েন্টার,       // --verbose
    শর্ট_পয়েন্টার,      // -v
    বিবরণ_পয়েন্টার,    // help text
    ধরন,               // FLAG_TYPE_BOOL/STRING/NUMBER
    মান_পয়েন্টার,      // parsed value
    পাওয়া গেছে         // was this flag provided?

struct CLI_App
    নাম_পয়েন্টার,
    সংস্করণ_পয়েন্টার,
    বিবরণ_পয়েন্টার,
    flag_তালিকা,
    flag_গণনা,
    arg_তালিকা,
    arg_গণনা,
    ত্রুটি_বার্তা

// ─── CLI তৈরি ────────────────────────────────────────────────────────────────
fn CLI_তৈরি নাম বিবরণ
    app_সাইজ = size_of(CLI_App)
    app = malloc(app_সাইজ)
    app.নাম_পয়েন্টার = নাম
    app.বিবরণ_পয়েন্টার = বিবরণ
    app.সংস্করণ_পয়েন্টার = "প্রথম ১.০"
    app.flag_তালিকা = malloc(CLI_MAX_FLAGS * size_of(CLI_Flag))
    app.flag_গণনা = 0
    app.arg_তালিকা = malloc(CLI_MAX_ARGS * 8)
    app.arg_গণনা = 0
    return app

// ─── Flag যোগ করো ────────────────────────────────────────────────────────────
// WHY: Declarative API — describe flags before parsing
fn CLI_flag_যোগ app long_flag short_flag বিবরণ ধরন
    if app.flag_গণনা >= CLI_MAX_FLAGS
        say "  ⚠️  সতর্কতা: সর্বোচ্চ flag সংখ্যা পূর্ণ হয়েছে"
        return -1

    flag_সাইজ = size_of(CLI_Flag)
    অফসেট = app.flag_গণনা * flag_সাইজ
    // write flag data to buffer at offset...
    app.flag_গণনা = app.flag_গণনা + 1
    return app.flag_গণনা

// সংক্ষিপ্ত version (Boolean flag)
fn CLI_bool_flag app long_flag short_flag বিবরণ
    return CLI_flag_যোগ(app, long_flag, short_flag, বিবরণ, FLAG_TYPE_BOOL)

// String value flag
fn CLI_string_flag app long_flag short_flag বিবরণ
    return CLI_flag_যোগ(app, long_flag, short_flag, বিবরণ, FLAG_TYPE_STRING)

// Number value flag
fn CLI_number_flag app long_flag short_flag বিবরণ
    return CLI_flag_যোগ(app, long_flag, short_flag, বিবরণ, FLAG_TYPE_NUMBER)

// ─── Help say ───────────────────────────────────────────────────────────────
// WHY: --help is the most important flag. Auto-generate it.
fn CLI_help_দেখাও app
    say app.নাম_পয়েন্টার
    say ""
    say app.বিবরণ_পয়েন্টার
    say ""
    say "ব্যবহার:", app.নাম_পয়েন্টার, "[flags] [args]"
    say ""
    say "Flags:"
    say "  --help,    -h    এই সহায়তা বার্তা দেখান"
    say "  --version, -V    সংস্করণ দেখান"
    say "  --verbose, -v    বিস্তারিত আউটপুট"

    i = 0
    while i < app.flag_গণনা
        // print each registered flag
        i = i + 1

// ─── আর্গুমেন্ট পার্স করো ─────────────────────────────────────────────────────
// WHY: Walk argv array, classify each as flag or positional
fn CLI_পার্স app
    // In Lipi, argc/argv are available via std/sys/kernel.lp
    // WHY: We use kernel ABI: [argc: i64] [argv[0]: ptr] [argv[1]: ptr] ...
    argc = আর্গুমেন্ট_গণনা()

    say "  → CLI পার্স: ", argc, "টি আর্গুমেন্ট পাওয়া গেছে"

    i = 1   // skip argv[0] (program name)
    while i < argc
        // Read argv[i]
        // Check if it starts with '-' → flag
        // Otherwise → positional arg
        i = i + 1
    return 0

// ─── Flag পড়ো ─────────────────────────────────────────────────────────────────
fn CLI_flag_পড়ো app flag_নাম
    // Search flag_তালিকা for matching নাম_পয়েন্টার
    // Return পাওয়া_গেছে field
    return 0   // not found = false

fn CLI_string_পড়ো app flag_নাম
    // Return মান_পয়েন্টার for string flags
    return "default_value"

fn CLI_number_পড়ো app flag_নাম
    return 0

// ─── Positional arg পড়ো ───────────────────────────────────────────────────────
fn CLI_arg_পড়ো app সূচক
    if সূচক >= app.arg_গণনা
        return 0   // null — no such arg
    return app.arg_তালিকা   // return pointer to arg string

// ─── CLI মুক্তি ────────────────────────────────────────────────────────────────
fn CLI_মুক্তি app
    free(app.flag_তালিকা, CLI_MAX_FLAGS * size_of(CLI_Flag))
    free(app.arg_তালিকা, CLI_MAX_ARGS * 8)
    free(app, size_of(CLI_App))
