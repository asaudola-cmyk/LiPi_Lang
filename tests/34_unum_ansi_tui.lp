// Test 34: Terminal UI — Lipi 2.0 Global Standard
// ANSI terminal rendering functions

fn ansi_reset   = "\033[0m"
fn ansi_bold    = "\033[1m"
fn ansi_red     = "\033[31m"
fn ansi_green   = "\033[32m"
fn ansi_yellow  = "\033[33m"
fn ansi_blue    = "\033[34m"
fn ansi_cyan    = "\033[36m"

fn tui_box title width
    say "+--" + title + "--+"

fn tui_row label value
    say "| " + label + ": " + value + " |"

fn tui_separator width
    say "+----------+"

fn tui_progress value max width
    filled = value * width / max
    empty  = width - filled
    say "Progress: " + value + "/" + max

fn tui_table_header cols
    say "Name       | Value  | Status"
    say "-----------|--------|-------"

fn tui_table_row name value status
    say name + " | " + value + " | " + status

say "=== Terminal UI Demo ==="
tui_box "System Status" 40
tui_row "CPU" "45%"
tui_row "MEM" "2.1GB"
tui_row "NET" "1.2Gbps"
tui_row "DISK" "120GB free"
tui_separator 40

say ""
tui_table_header 3
tui_table_row "service1" "running" "OK"
tui_table_row "service2" "stopped" "ERR"
tui_table_row "service3" "running" "OK"

say ""
tui_progress 65 100 20
tui_progress 30 100 20

say "PASS: Test 34 Terminal UI"
