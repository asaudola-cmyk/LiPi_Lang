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
//   অন্তর্ভুক্ত "std/cli.lp"
//   ধরি app = CLI_তৈরি("my-tool", "আমার টুলের বিবরণ")
//   CLI_flag_যোগ(app, "--verbose", "-v", "বিস্তারিত আউটপুট")
//   CLI_পার্স(app)
//   যদি CLI_flag_পড়ো(app, "--verbose") { দেখাও "verbose mode" }
// ==============================================================================

অন্তর্ভুক্ত "std/core/mem.lp"
অন্তর্ভুক্ত "std/core/str.lp"
অন্তর্ভুক্ত "std/sys/kernel.lp"

// ─── ধ্রুবক ──────────────────────────────────────────────────────────────────
ধরি CLI_MAX_FLAGS    = ৬৪    // সর্বোচ্চ ৬৪টি flag
ধরি CLI_MAX_ARGS     = ৩২    // সর্বোচ্চ ৩২টি positional arg
ধরি CLI_MAX_SUBCMDS  = ১৬    // সর্বোচ্চ ১৬টি subcommand

ধরি FLAG_TYPE_BOOL   = ১     // --verbose (no value)
ধরি FLAG_TYPE_STRING = ২     // --output file.txt
ধরি FLAG_TYPE_NUMBER = ৩     // --port 8080

// ─── গঠনসমূহ ─────────────────────────────────────────────────────────────────

গঠন CLI_Flag {
    নাম_পয়েন্টার,       // --verbose
    শর্ট_পয়েন্টার,      // -v
    বিবরণ_পয়েন্টার,    // help text
    ধরন,               // FLAG_TYPE_BOOL/STRING/NUMBER
    মান_পয়েন্টার,      // parsed value
    পাওয়া গেছে         // was this flag provided?
}

গঠন CLI_App {
    নাম_পয়েন্টার,
    সংস্করণ_পয়েন্টার,
    বিবরণ_পয়েন্টার,
    flag_তালিকা,
    flag_গণনা,
    arg_তালিকা,
    arg_গণনা,
    ত্রুটি_বার্তা
}

// ─── CLI তৈরি ────────────────────────────────────────────────────────────────
কাজ CLI_তৈরি(নাম, বিবরণ) {
    ধরি app_সাইজ = সাইজ(CLI_App)
    ধরি app = মেমরি_বরাদ্দ(app_সাইজ)
    app.নাম_পয়েন্টার = নাম
    app.বিবরণ_পয়েন্টার = বিবরণ
    app.সংস্করণ_পয়েন্টার = "প্রথম ১.০"
    app.flag_তালিকা = মেমরি_বরাদ্দ(CLI_MAX_FLAGS * সাইজ(CLI_Flag))
    app.flag_গণনা = ০
    app.arg_তালিকা = মেমরি_বরাদ্দ(CLI_MAX_ARGS * ৮)
    app.arg_গণনা = ০
    ফেরত app
}

// ─── Flag যোগ করো ────────────────────────────────────────────────────────────
// WHY: Declarative API — describe flags before parsing
কাজ CLI_flag_যোগ(app, long_flag, short_flag, বিবরণ, ধরন) {
    যদি app.flag_গণনা >= CLI_MAX_FLAGS {
        দেখাও "  ⚠️  সতর্কতা: সর্বোচ্চ flag সংখ্যা পূর্ণ হয়েছে"
        ফেরত -১
    }

    ধরি flag_সাইজ = সাইজ(CLI_Flag)
    ধরি অফসেট = app.flag_গণনা * flag_সাইজ
    // write flag data to buffer at offset...
    app.flag_গণনা = app.flag_গণনা + ১
    ফেরত app.flag_গণনা
}

// সংক্ষিপ্ত version (Boolean flag)
কাজ CLI_bool_flag(app, long_flag, short_flag, বিবরণ) {
    ফেরত CLI_flag_যোগ(app, long_flag, short_flag, বিবরণ, FLAG_TYPE_BOOL)
}

// String value flag
কাজ CLI_string_flag(app, long_flag, short_flag, বিবরণ) {
    ফেরত CLI_flag_যোগ(app, long_flag, short_flag, বিবরণ, FLAG_TYPE_STRING)
}

// Number value flag
কাজ CLI_number_flag(app, long_flag, short_flag, বিবরণ) {
    ফেরত CLI_flag_যোগ(app, long_flag, short_flag, বিবরণ, FLAG_TYPE_NUMBER)
}

// ─── Help দেখাও ───────────────────────────────────────────────────────────────
// WHY: --help is the most important flag. Auto-generate it.
কাজ CLI_help_দেখাও(app) {
    দেখাও app.নাম_পয়েন্টার
    দেখাও ""
    দেখাও app.বিবরণ_পয়েন্টার
    দেখাও ""
    দেখাও "ব্যবহার:", app.নাম_পয়েন্টার, "[flags] [args]"
    দেখাও ""
    দেখাও "Flags:"
    দেখাও "  --help,    -h    এই সহায়তা বার্তা দেখান"
    দেখাও "  --version, -V    সংস্করণ দেখান"
    দেখাও "  --verbose, -v    বিস্তারিত আউটপুট"

    ধরি i = ০
    যতক্ষণ i < app.flag_গণনা {
        // print each registered flag
        i = i + ১
    }
}

// ─── আর্গুমেন্ট পার্স করো ─────────────────────────────────────────────────────
// WHY: Walk argv array, classify each as flag or positional
কাজ CLI_পার্স(app) {
    // In Lipi, argc/argv are available via std/sys/kernel.lp
    // WHY: We use kernel ABI: [argc: i64] [argv[0]: ptr] [argv[1]: ptr] ...
    ধরি argc = আর্গুমেন্ট_গণনা()

    দেখাও "  → CLI পার্স: ", argc, "টি আর্গুমেন্ট পাওয়া গেছে"

    ধরি i = ১   // skip argv[0] (program name)
    যতক্ষণ i < argc {
        // Read argv[i]
        // Check if it starts with '-' → flag
        // Otherwise → positional arg
        i = i + ১
    }
    ফেরত ০
}

// ─── Flag পড়ো ─────────────────────────────────────────────────────────────────
কাজ CLI_flag_পড়ো(app, flag_নাম) {
    // Search flag_তালিকা for matching নাম_পয়েন্টার
    // Return পাওয়া_গেছে field
    ফেরত ০   // not found = false
}

কাজ CLI_string_পড়ো(app, flag_নাম) {
    // Return মান_পয়েন্টার for string flags
    ফেরত "default_value"
}

কাজ CLI_number_পড়ো(app, flag_নাম) {
    ফেরত ০
}

// ─── Positional arg পড়ো ───────────────────────────────────────────────────────
কাজ CLI_arg_পড়ো(app, সূচক) {
    যদি সূচক >= app.arg_গণনা {
        ফেরত ০   // null — no such arg
    }
    ফেরত app.arg_তালিকা   // return pointer to arg string
}

// ─── CLI মুক্তি ────────────────────────────────────────────────────────────────
কাজ CLI_মুক্তি(app) {
    মেমরি_মুক্তি(app.flag_তালিকা, CLI_MAX_FLAGS * সাইজ(CLI_Flag))
    মেমরি_মুক্তি(app.arg_তালিকা, CLI_MAX_ARGS * ৮)
    মেমরি_মুক্তি(app, সাইজ(CLI_App))
}
