// Test 05: Dashboard — Lipi 2.0
// Demonstrates: string formatting, function calls, arithmetic display

// Dashboard header
say "=== Lipi System Dashboard ==="
say "CPU Usage: 45%"
say "Memory: 2.1 GB / 8 GB"
say "Disk: 120 GB free"
say "Network: 1.2 Gbps"

// Function to format and display a metric
fn format_metric name value unit
    say name + ": " + value + " " + unit

format_metric "Temperature" 42 "C"
format_metric "Uptime" 99 "days"
format_metric "Requests" 15000 "req/s"

// Compute a simple usage percentage
fn usage_bar used total
    percent = used * 100 / total
    return percent

cpu_percent = usage_bar 45 100
mem_percent = usage_bar 21 80
disk_percent = usage_bar 120 500

say "CPU %: " + cpu_percent
say "Mem %: " + mem_percent
say "Disk %: " + disk_percent

say "PASS: Test 05 Dashboard"
