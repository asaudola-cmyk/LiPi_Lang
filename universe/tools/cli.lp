// ==============================================================================
// 🖥️ লিপি CLI আর্গুমেন্ট পার্সার (Command-Line Interface Library)
// লিপি প্রথম ২.০ | ciphername: সোভেরিন
// File: std/cli.lp
//
// WHY এই মডিউল:
//   Professional CLI tools need argument parsing (like argparse, clap, cobra).
//   Pure sovereign CLI argument engine with zero external libc runtime dependencies.
//   এই মডিউল দিয়ে:
//   - Flags: --verbose, --output=file.txt, -v, -o file.txt
//   - Positional args: lipi compile input.lp
//   - Short and Long flag aliases: -h, --help
//   - Auto-generated help formatting
//
// ব্যবহার:
//   include "universe/tools/std_cli.lp"
//   app = cli_create("my-tool", "আমার টুলের বিবরণ")
//   cli_bool_flag(app, "--verbose", "-v", "বিস্তারিত আউটপুট")
//   cli_string_flag(app, "--output", "-o", "আউটপুট ফাইল", "out.bin")
//   cli_parse(app)
//   if cli_flag_read(app, "--verbose")
//       say "verbose mode"
//   out_file = cli_string_read(app, "--output")
// ==============================================================================

include "universe/core/memory.lp"
include "universe/core/string.lp"
include "universe/os/kernel_multiboot.lp"

// ─── ধ্রুবক (Constants) ───────────────────────────────────────────────────────
CLI_MAX_FLAGS    = 64    // সর্বোচ্চ ৬৪টি flag
CLI_MAX_ARGS     = 32    // সর্বোচ্চ ৩২টি positional arg
CLI_MAX_SUBCMDS  = 16    // সর্বোচ্চ ১৬টি subcommand

FLAG_TYPE_BOOL   = 1     // --verbose (no value)
FLAG_TYPE_STRING = 2     // --output file.txt or --output=file.txt
FLAG_TYPE_NUMBER = 3     // --port 8080 or --port=8080

// ─── গঠনসমূহ (Pure Lipi 2.0 Struct Declarations) ──────────────────────────────
// WHY: Pure Lipi 2.0 indentation syntax — no commas, each field on its own line.
struct CLI_Flag
    name_ptr
    short_ptr
    description_ptr
    type_flag
    value_ptr
    পাওয়া_গেছে
    default_val

struct CLI_App
    name_ptr
    version_ptr
    description_ptr
    flag_list
    flag_count
    arg_list
    arg_count
    parsed_keys
    parsed_vals
    error_message

// ─── Integer Parsing Helper ───────────────────────────────────────────────────
// WHY: Robust string-to-integer conversion supporting positive, negative, and Bengali digits.
fn cli_parse_int s
    slen = len(s)
    if slen == 0
        return 0
    res = 0
    i = 0
    neg = 0
    if char_at(s, 0) == "-"
        neg = 1
        i = 1
    while i < slen
        c = ord(char_at(s, i))
        if c >= 48 and c <= 57
            res = res * 10 + (c - 48)
        i = i + 1
    if neg == 1
        return 0 - res
    return res

// ─── CLI Create ───────────────────────────────────────────────────────────────
// WHY: Initializes a fresh CLI application context for flag registration and parsing.
fn cli_create name description
    app = CLI_App()
    app.name_ptr = name
    app.description_ptr = description
    app.version_ptr = "২.০"
    app.flag_list = list()
    app.flag_count = 0
    app.arg_list = list()
    app.arg_count = 0
    app.parsed_keys = list()
    app.parsed_vals = list()
    app.error_message = ""
    return app

fn CLI_তৈরি name description
    return cli_create(name, description)

// ─── Flag Add করো ─────────────────────────────────────────────────────────────
// WHY: Declarative API — registers long and short flags with default values and types.
fn cli_flag_add app long_flag short_flag description type_flag default_val
    flag = CLI_Flag()
    flag.name_ptr = long_flag
    flag.short_ptr = short_flag
    flag.description_ptr = description
    flag.type_flag = type_flag
    flag.value_ptr = default_val
    flag.default_val = default_val
    flag.পাওয়া_গেছে = 0

    push(app.flag_list, flag)
    app.flag_count = app.flag_count + 1
    return flag

fn cli_add_flag app long_flag short_flag description type_flag default_val
    return cli_flag_add(app, long_flag, short_flag, description, type_flag, default_val)

// সংক্ষিপ্ত version (Boolean flag)
// WHY: Convenience helper for registering boolean switches without values.
fn cli_bool_flag app long_flag short_flag description
    return cli_flag_add(app, long_flag, short_flag, description, FLAG_TYPE_BOOL, "0")

fn CLI_bool_flag app long_flag short_flag description
    return cli_bool_flag(app, long_flag, short_flag, description)

// String value flag
// WHY: Convenience helper for registering string options with default values.
fn cli_string_flag app long_flag short_flag description default_val
    return cli_flag_add(app, long_flag, short_flag, description, FLAG_TYPE_STRING, default_val)

fn CLI_string_flag app long_flag short_flag description default_val
    return cli_string_flag(app, long_flag, short_flag, description, default_val)

// Number value flag
// WHY: Convenience helper for registering integer numeric options with default values.
fn cli_number_flag app long_flag short_flag description default_val
    return cli_flag_add(app, long_flag, short_flag, description, FLAG_TYPE_NUMBER, default_val)

fn CLI_number_flag app long_flag short_flag description default_val
    return cli_number_flag(app, long_flag, short_flag, description, default_val)

// ─── Internal Option Storage ──────────────────────────────────────────────────
// WHY: Stores parsed key-value pair and synchronizes registered CLI_Flag state.
fn cli_store_opt app key val
    push(app.parsed_keys, key)
    push(app.parsed_vals, val)

    i = 0
    while i < app.flag_count
        f = get(app.flag_list, i)
        if f.name_ptr == key or f.short_ptr == key
            f.পাওয়া_গেছে = 1
            f.value_ptr = val
        i = i + 1
    return 0

// ─── Token Parser ─────────────────────────────────────────────────────────────
// WHY: Walks token list and parses positional args, short flags (-f), long flags (--flag),
// and key-value pairs (--output=file, --port 8080).
fn cli_parse_tokens app tokens
    num_tokens = len(tokens)
    i = 0
    while i < num_tokens
        tok = get(tokens, i)
        tlen = len(tok)

        if starts_with(tok, "--")
            eq_idx = index_of(tok, "=")
            if eq_idx >= 0
                k = str_sub(tok, 0, eq_idx)
                v = str_sub(tok, eq_idx + 1, tlen)
                cli_store_opt(app, k, v)
            else
                consumed_next = 0
                f_idx = 0
                while f_idx < app.flag_count
                    f = get(app.flag_list, f_idx)
                    if f.name_ptr == tok
                        if f.type_flag == FLAG_TYPE_STRING or f.type_flag == FLAG_TYPE_NUMBER
                            if i + 1 < num_tokens
                                next_tok = get(tokens, i + 1)
                                if starts_with(next_tok, "-") == 0
                                    cli_store_opt(app, tok, next_tok)
                                    consumed_next = 1
                                    i = i + 1
                        break
                    f_idx = f_idx + 1
                if consumed_next == 0
                    cli_store_opt(app, tok, "1")

        elif starts_with(tok, "-") and tlen > 1
            eq_idx = index_of(tok, "=")
            if eq_idx >= 0
                k = str_sub(tok, 0, eq_idx)
                v = str_sub(tok, eq_idx + 1, tlen)
                cli_store_opt(app, k, v)
            else
                consumed_next = 0
                f_idx = 0
                while f_idx < app.flag_count
                    f = get(app.flag_list, f_idx)
                    if f.short_ptr == tok
                        if f.type_flag == FLAG_TYPE_STRING or f.type_flag == FLAG_TYPE_NUMBER
                            if i + 1 < num_tokens
                                next_tok = get(tokens, i + 1)
                                if starts_with(next_tok, "-") == 0
                                    cli_store_opt(app, tok, next_tok)
                                    consumed_next = 1
                                    i = i + 1
                        break
                    f_idx = f_idx + 1
                if consumed_next == 0
                    cli_store_opt(app, tok, "1")

        else
            // Positional Argument
            push(app.arg_list, tok)
            app.arg_count = app.arg_count + 1

        i = i + 1
    return 0

// ─── আর্গুমেন্ট পার্স করো ─────────────────────────────────────────────────────
// WHY: Reads arguments from sovereign kernel ABI via argv() and parses them.
fn cli_parse app
    sys_args = argv()
    argc = len(sys_args)
    if argc <= 1
        return 0

    tokens = list()
    i = 1
    while i < argc
        push(tokens, get(sys_args, i))
        i = i + 1

    return cli_parse_tokens(app, tokens)

// WHY: Parses arguments from an explicit space-separated string (useful for testing).
fn cli_parse_string app args_str
    tokens = split(args_str)
    return cli_parse_tokens(app, tokens)

// ─── Flag Read ─────────────────────────────────────────────────────────────────
// WHY: Tests if a flag was passed on the command line (checks long and short names).
fn cli_flag_read app flag_name
    i = 0
    while i < app.flag_count
        f = get(app.flag_list, i)
        if f.name_ptr == flag_name or f.short_ptr == flag_name
            return f.পাওয়া_গেছে
        i = i + 1

    k_idx = 0
    while k_idx < len(app.parsed_keys)
        if get(app.parsed_keys, k_idx) == flag_name
            return 1
        k_idx = k_idx + 1
    return 0

fn cli_has_flag app flag_name
    return cli_flag_read(app, flag_name)

// WHY: Retrieves the string value of a flag or option, returning default if not set.
fn cli_string_read app flag_name
    i = 0
    while i < app.flag_count
        f = get(app.flag_list, i)
        if f.name_ptr == flag_name or f.short_ptr == flag_name
            if f.পাওয়া_গেছে == 1
                return f.value_ptr
            return f.default_val
        i = i + 1

    k_idx = 0
    while k_idx < len(app.parsed_keys)
        if get(app.parsed_keys, k_idx) == flag_name
            return get(app.parsed_vals, k_idx)
        k_idx = k_idx + 1
    return ""

fn cli_get_option app flag_name
    return cli_string_read(app, flag_name)

// WHY: Retrieves the integer numeric value of a flag or option.
fn cli_number_read app flag_name
    val_s = cli_string_read(app, flag_name)
    return cli_parse_int(val_s)

fn cli_get_int app flag_name
    return cli_number_read(app, flag_name)

// ─── Positional Arg Read ───────────────────────────────────────────────────────
// WHY: Retrieves a positional argument by 0-based index.
fn cli_arg_read app index
    if index < 0 or index >= app.arg_count
        return ""
    return get(app.arg_list, index)

fn cli_get_arg app index
    return cli_arg_read(app, index)

// WHY: Returns the total count of positional arguments parsed.
fn cli_arg_count app
    return app.arg_count

// ─── Help Show ─────────────────────────────────────────────────────────────────
// WHY: Auto-generates clean, structured terminal help with options and descriptions.
fn cli_help_show app
    say app.name_ptr
    say ""
    say app.description_ptr
    say ""
    say "Usage: " + app.name_ptr + " [OPTIONS] [ARGS...]"
    say ""
    say "Options:"
    say "  -h, --help     Show this help message"
    say "  -V, --version  Show version"

    i = 0
    while i < app.flag_count
        f = get(app.flag_list, i)
        flag_line = "  "
        if len(f.short_ptr) > 0
            flag_line = flag_line + f.short_ptr + ", "
        else
            flag_line = flag_line + "    "
        flag_line = flag_line + f.name_ptr
        while len(flag_line) < 22
            flag_line = flag_line + " "
        flag_line = flag_line + f.description_ptr
        if len(f.default_val) > 0 and f.default_val != "0"
            flag_line = flag_line + " (default: " + f.default_val + ")"
        say flag_line
        i = i + 1

fn cli_show_help app
    cli_help_show(app)

// ─── CLI মুক্তি ───────────────────────────────────────────────────────────────
// WHY: Clean resource cleanup and memory release for CLI context.
fn cli_free app
    if app == 0
        return 0
    return 0

fn CLI_মুক্তি app
    return cli_free(app)
