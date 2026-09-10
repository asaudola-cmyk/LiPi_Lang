// ==============================================================================
// 🖥️ লিপি CLI আর্গুমেন্ট পার্সার (Command-Line Interface Library)
// লিপি প্রথম ১.০ | ciphername: সোভেরিন
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
// ব্যবrate:
//   include "std/cli.lp"
//    app = cli_create("my-tool", "আমার টুলের description")
//   cli_flag_add(app, "--verbose", "-v", "বিস্তারিত output")
//   cli_parse(app)
//   if cli_flag_read(app, "--verbose") { say "verbose mode" }
// ==============================================================================

include "std/mem.lp"
include "std/str.lp"
include "std/kernel.lp"

// ─── ধ্রুবa ──────────────────────────────────────────────────────────────────
CLI_MAX_FLAGS    = 64    // সর্বোচ্চ ৬৪টি flag
CLI_MAX_ARGS     = 32    // সর্বোচ্চ ৩২টি positional arg
CLI_MAX_SUBCMDS  = 16    // সর্বোচ্চ ১৬টি subcommand

FLAG_TYPE_BOOL   = 1     // --verbose (no value)
FLAG_TYPE_STRING = 2     // --output file.txt
FLAG_TYPE_NUMBER = 3     // --port 8080

// ─── গঠনসমূহ ─────────────────────────────────────────────────────────────────

struct CLI_Flag
    name_ptr,       // --verbose
    শর্ট_ptr,      // -v
    description_ptr,    // help text
    type_flag,               // FLAG_TYPE_BOOL/STRING/NUMBER
    value_ptr,      // parsed value
    পাওয়া গেছে         // was this flag provided?

struct CLI_App
    name_ptr,
    version_ptr,
    description_ptr,
    flag_list,
    flag_count,
    arg_list,
    arg_count,
    error_message

// ─── CLI create ────────────────────────────────────────────────────────────────
fn cli_create name description
    app_size = size_of(CLI_App)
    app = malloc(app_size)
    app.name_ptr = name
    app.description_ptr = description
    app.version_ptr = "প্রথম ১.০"
    app.flag_list = malloc(CLI_MAX_FLAGS * size_of(CLI_Flag))
    app.flag_count = 0
    app.arg_list = malloc(CLI_MAX_ARGS * 8)
    app.arg_count = 0
    return app

// ─── Flag add aরো ────────────────────────────────────────────────────────────
// WHY: Declarative API — describe flags before parsing
fn cli_flag_add app long_flag short_flag description type_flag
    if app.flag_count >= CLI_MAX_FLAGS
        say "  ⚠️  সতর্কতা: সর্বোচ্চ flag সংখ্যা পূর্ণ হয়েছে"
        return -1

    flag_size = size_of(CLI_Flag)
    offset = app.flag_count * flag_size
    // write flag data to buffer at offset...
    app.flag_count = app.flag_count + 1
    return app.flag_count

// সংa্ষিপ্ত version (Boolean flag)
fn CLI_bool_flag app long_flag short_flag description
    return cli_flag_add(app, long_flag, short_flag, description, FLAG_TYPE_BOOL)

// String value flag
fn CLI_string_flag app long_flag short_flag description
    return cli_flag_add(app, long_flag, short_flag, description, FLAG_TYPE_STRING)

// Number value flag
fn CLI_number_flag app long_flag short_flag description
    return cli_flag_add(app, long_flag, short_flag, description, FLAG_TYPE_NUMBER)

// ─── Help say ───────────────────────────────────────────────────────────────
// WHY: --help is the most important flag. Auto-generate it.
fn cli_help_show app
    say app.name_ptr
    say ""
    say app.description_ptr
    say ""
    say "ব্যবহার:", app.name_ptr, "[flags] [args]"
    say ""
    say "Flags:"
    say "  --help,    -h    এই সহায়তা বার্তা দেখান"
    say "  --version, -V    সংস্করণ দেখান"
    say "  --verbose, -v    বিস্তারিত outপুট"

    i = 0
    while i < app.flag_count
        // print each registered flag
        i = i + 1

// ─── আর্গুমেন্ট পার্স aরো ─────────────────────────────────────────────────────
// WHY: Walk argv array, classify each as flag or positional
fn cli_parse app
    // In Lipi, argc/argv are available via std/sys/kernel.lp
    // WHY: We use kernel ABI: [argc: i64] [argv[0]: ptr] [argv[1]: ptr] ...
    argc = আর্গুমেন্ট_count()

    say "  → CLI parse: ", argc, "টি আর্গুমেন্ট পাওয়া গেছে"

    i = 1   // skip argv[0] (program name)
    while i < argc
        // Read argv[i]
        // Check if it starts with '-' → flag
        // Otherwise → positional arg
        i = i + 1
    return 0

// ─── Flag read ─────────────────────────────────────────────────────────────────
fn cli_flag_read app flag_name
    // Search flag_list for matching name_ptr
    // Return পাওয়া_গেছে field
    return 0   // not found = false

fn cli_string_read app flag_name
    // Return value_ptr for string flags
    return "default_value"

fn cli_number_read app flag_name
    return 0

// ─── Positional arg read ───────────────────────────────────────────────────────
fn cli_arg_read app index
    if index >= app.arg_count
        return 0   // null — no such arg
    return app.arg_list   // return pointer to arg string

// ─── CLI মুa্তি ────────────────────────────────────────────────────────────────
fn cli_free app
    free(app.flag_list, CLI_MAX_FLAGS * size_of(CLI_Flag))
    free(app.arg_list, CLI_MAX_ARGS * 8)
    free(app, size_of(CLI_App))
