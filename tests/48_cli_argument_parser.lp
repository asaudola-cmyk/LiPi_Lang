// Test 48: CLI Argument Parser — Lipi 2.0 Global Standard
// Command-line argument parsing patterns

struct Flag
    name
    short
    value
    required

fn flag_new name short default_val required
    f = Flag()
    f.name = name
    f.short = short
    f.value = default_val
    f.required = required
    return f

fn parse_flag flags_str name
    // Simulate arg parsing: "--name=value"
    return "parsed_" + name

fn cli_parse args
    say "Parsing: " + args
    return 1

fn cli_help prog flags_count
    say "Usage: " + prog + " [OPTIONS]"
    say "Options:"
    say "  --port     Server port (default: 8080)"
    say "  --host     Server host (default: localhost)"
    say "  --workers  Worker count (default: 4)"
    say "  --debug    Enable debug mode"
    say "  --help     Show this help"

fn run_with_args port host workers debug
    say "Starting server:"
    say "  Host:    " + host
    say "  Port:    " + port
    say "  Workers: " + workers
    if debug
        say "  Debug:   enabled"
    else
        say "  Debug:   disabled"

say "=== CLI Argument Parser ==="
cli_help "lipi-server" 5

say ""
say "Example: lipi-server --port=9090 --workers=8"
run_with_args 9090 "0.0.0.0" 8 1

// Flag defaults
port_flag    = flag_new "port"    "p" 8080 0
host_flag    = flag_new "host"    "h" "localhost" 0
workers_flag = flag_new "workers" "w" 4 0

say ""
say "Default port: " + port_flag.value
say "Default host: " + host_flag.value
say "Default workers: " + workers_flag.value

say "PASS: Test 48 CLI Args"
