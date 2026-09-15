// ==============================================================================
// 👑 LIPI UNIFIED TOOLKIT: UNIVERSAL CLI PARSER (src/toolkit/common/cli_parser.lp)
// ⚡ 100% Pure Sovereign Lipi First 1.0.0 | Zero Libc | Zero External Dependencies
// ==============================================================================
//
// WHY THIS MODULE:
// Modern developer tools require robust, declarative command-line argument parsing
// without external runtime dependencies (replacing Python argparse or Rust clap).
// This module provides:
// 1. First-class Subcommands (e.g., `lipi build`, `lipi run`, `lipi test`).
// 2. Long flags (`--release`, `--target=wasm`, `--output out.bin`).
// 3. Short flags (`-r`, `-t wasm`, `-o out.bin`).
// 4. Integrated POSIX double-dash (`--`) positional escape terminator.
// 5. Automatic column-aligned terminal help manual generator.

include "universe/core/memory.lp"
include "universe/core/string.lp"
include "universe/core/io.lp"

// ── 1. Data Structures ────────────────────────────────────────────────────────

// WHY: Encapsulates single CLI flag or parameter descriptor with collision-free field names.
struct CliOption
    opt_name            // Full long flag identifier (e.g. "--output")
    opt_short           // Single-character short alias (e.g. "-o")
    opt_desc            // Human-readable documentation for help screen
    opt_has_value       // 1 if option consumes argument value, 0 if boolean switch
    opt_default_value   // Fallback value when option is omitted
    opt_value           // Actual parsed string value
    opt_is_present      // 1 if specified on command line, 0 if absent

// WHY: Registers distinct toolchain operational subcommands.
struct CliSubcommand
    sub_name            // Subcommand identifier (e.g. "build")
    sub_desc            // Short description for summary table

// WHY: Master context managing parser rules, parsed results, and diagnostics.
struct CliParser
    app_name            // Binary/application name (e.g. "lipi")
    app_description     // Top-level suite overview
    app_version         // Semantic version string
    parser_options      // List of registered CliOption structs
    parser_subcommands  // List of registered CliSubcommand structs
    active_subcommand   // Parsed active subcommand name (empty if none)
    positional_args     // List of collected non-flag positional arguments
    error_message       // Captured syntax or missing-argument error string

// ── 2. Constructor & Registration Primitives ──────────────────────────────────

// WHY: Allocates clean CLI parser context initialized with default metadata.
fn cli_parser_new app_name description version
    parser = CliParser()
    parser.app_name = app_name
    parser.app_description = description
    parser.app_version = version
    parser.parser_options = list()
    parser.parser_subcommands = list()
    parser.active_subcommand = ""
    parser.positional_args = list()
    parser.error_message = ""
    return parser

// WHY: Registers a boolean switch flag (e.g. --verbose, -v).
fn cli_add_flag parser name short_name description
    opt = CliOption()
    opt.opt_name = name
    opt.opt_short = short_name
    opt.opt_desc = description
    opt.opt_has_value = 0
    opt.opt_default_value = "false"
    opt.opt_value = "false"
    opt.opt_is_present = 0
    push(parser.parser_options, opt)
    return opt

// WHY: Registers a valued option (e.g. --output <file>, -o <file>).
fn cli_add_option parser name short_name description default_val
    opt = CliOption()
    opt.opt_name = name
    opt.opt_short = short_name
    opt.opt_desc = description
    opt.opt_has_value = 1
    opt.opt_default_value = default_val
    opt.opt_value = default_val
    opt.opt_is_present = 0
    push(parser.parser_options, opt)
    return opt

// WHY: Registers a primary subcommand (e.g. "build", "run", "test").
fn cli_add_subcommand parser name description
    sub = CliSubcommand()
    sub.sub_name = name
    sub.sub_desc = description
    push(parser.parser_subcommands, sub)
    return sub

// ── 3. Internal Parsing Helpers ───────────────────────────────────────────────

// WHY: Searches registered option catalog by exact long or short flag name.
fn cli_find_option parser flag_str
    opts = parser.parser_options
    count = len(opts)
    i = 0
    while i < count
        opt = get(opts, i)
        if opt.opt_name == flag_str or opt.opt_short == flag_str
            return opt
        i = i + 1
    return 0

// WHY: Verifies whether an argument token matches any registered subcommand.
fn cli_is_subcommand parser token
    subs = parser.parser_subcommands
    count = len(subs)
    i = 0
    while i < count
        sub = get(subs, i)
        if sub.sub_name == token
            return 1
        i = i + 1
    return 0

// WHY: Splits key=val pairs across the '=' delimiter without external regex.
fn cli_find_char s target_char
    slen = len(s)
    i = 0
    while i < slen
        if char_at(s, i) == target_char
            return i
        i = i + 1
    return -1

// ── 4. Main Parsing Engine ────────────────────────────────────────────────────

// WHY: Pure deterministic argument scanner handling subcommands, flags, values,
// and double-dash escape boundaries in a single high-efficiency pass.
fn cli_parse parser args_list
    total_args = len(args_list)
    if total_args == 0
        return 1

    idx = 0
    passthrough_mode = 0

    while idx < total_args
        arg = get(args_list, idx)
        arg_len = len(arg)

        // Case 1: POSIX Double-Dash terminator ("--")
        if arg == "--" and passthrough_mode == 0
            passthrough_mode = 1
            idx = idx + 1
            continue

        if passthrough_mode == 1
            push(parser.positional_args, arg)
            idx = idx + 1
            continue

        // Case 2: Long flag or option (--flag or --key=value)
        if arg_len >= 2 and char_at(arg, 0) == "-" and char_at(arg, 1) == "-"
            eq_idx = cli_find_char(arg, "=")
            flag_key = arg
            flag_val = ""
            has_inline_val = 0

            if eq_idx > 0
                flag_key = str_sub(arg, 0, eq_idx)
                flag_val = str_sub(arg, eq_idx + 1, arg_len)
                has_inline_val = 1

            opt = cli_find_option(parser, flag_key)
            if opt != 0
                opt.opt_is_present = 1
                if opt.opt_has_value == 1
                    if has_inline_val == 1
                        opt.opt_value = flag_val
                    else
                        if idx + 1 < total_args
                            idx = idx + 1
                            opt.opt_value = get(args_list, idx)
                        else
                            parser.error_message = "Option " + flag_key + " requires a value."
                            return 0
                else
                    opt.opt_value = "true"
            else
                parser.error_message = "Unknown command line flag: " + flag_key
                return 0

            idx = idx + 1
            continue

        // Case 3: Short flag or option (-f or -f=value)
        if arg_len >= 2 and char_at(arg, 0) == "-" and char_at(arg, 1) != "-"
            eq_idx = cli_find_char(arg, "=")
            flag_key = arg
            flag_val = ""
            has_inline_val = 0

            if eq_idx > 0
                flag_key = str_sub(arg, 0, eq_idx)
                flag_val = str_sub(arg, eq_idx + 1, arg_len)
                has_inline_val = 1

            opt = cli_find_option(parser, flag_key)
            if opt != 0
                opt.opt_is_present = 1
                if opt.opt_has_value == 1
                    if has_inline_val == 1
                        opt.opt_value = flag_val
                    else
                        if idx + 1 < total_args
                            idx = idx + 1
                            opt.opt_value = get(args_list, idx)
                        else
                            parser.error_message = "Option " + flag_key + " requires a value."
                            return 0
                else
                    opt.opt_value = "true"
            else
                parser.error_message = "Unknown short flag: " + flag_key
                return 0

            idx = idx + 1
            continue

        // Case 4: Subcommand or positional argument
        if len(parser.active_subcommand) == 0 and cli_is_subcommand(parser, arg) == 1
            parser.active_subcommand = arg
        else
            push(parser.positional_args, arg)

        idx = idx + 1

    return 1

// ── 5. Query & Introspection APIs ─────────────────────────────────────────────

// WHY: Returns 1 if flag is present and evaluated to "true", 0 otherwise.
fn cli_get_flag parser flag_name
    opt = cli_find_option(parser, flag_name)
    if opt == 0
        return 0
    if opt.opt_is_present == 1 and opt.opt_value == "true"
        return 1
    return 0

// WHY: Returns configured or parsed string value for designated option.
fn cli_get_option parser flag_name
    opt = cli_find_option(parser, flag_name)
    if opt == 0
        return ""
    return opt.opt_value

// WHY: Returns currently matched subcommand string, or empty string if root command.
fn cli_get_subcommand parser
    return parser.active_subcommand

// WHY: Retrieves positional argument by 0-based offset with bounds safety.
fn cli_get_arg parser index
    args = parser.positional_args
    if index >= 0 and index < len(args)
        return get(args, index)
    return ""

// WHY: Total count of non-flag positional arguments.
fn cli_arg_count parser
    return len(parser.positional_args)

// ── 6. Automated Help Formatter ───────────────────────────────────────────────

// WHY: Formats and outputs standardized, column-aligned terminal help manual.
fn cli_print_help parser
    say "Usage: " + parser.app_name + " [command] [options] [arguments...]"
    if len(parser.app_description) > 0
        say "\n" + parser.app_description
    say "Version: " + parser.app_version + "\n"

    subs = parser.parser_subcommands
    sub_count = len(subs)
    if sub_count > 0
        say "Commands:"
        i = 0
        while i < sub_count
            sub = get(subs, i)
            padding = "  " + sub.sub_name
            while len(padding) < 18
                padding = padding + " "
            say padding + sub.sub_desc
            i = i + 1
        say ""

    opts = parser.parser_options
    opt_count = len(opts)
    if opt_count > 0
        say "Options:"
        i = 0
        while i < opt_count
            opt = get(opts, i)
            flag_display = "  "
            if len(opt.opt_short) > 0
                flag_display = flag_display + opt.opt_short + ", "
            else
                flag_display = flag_display + "    "
            flag_display = flag_display + opt.opt_name
            if opt.opt_has_value == 1
                flag_display = flag_display + " <val>"
            while len(flag_display) < 28
                flag_display = flag_display + " "
            def_str = ""
            if opt.opt_has_value == 1 and len(opt.opt_default_value) > 0
                def_str = " (default: " + opt.opt_default_value + ")"
            say flag_display + opt.opt_desc + def_str
            i = i + 1
        say ""

    return 0
