// Test 42: Bilingual Syntax — Lipi 2.0 Global Standard
// Demonstrates English global syntax + Unicode identifier support
// WHY: One language for the world — English keywords, any script identifiers

// Global syntax: English keywords
fn add a b = a + b
fn multiply a b = a * b
fn max2 a b
    if a > b
        return a
    return b

// Unicode identifiers work perfectly
নাম = "Lipi"          // Bengali variable
версия = 2             // Russian variable
اسم = "World"         // Arabic variable

say নাম
say версия
say add 10 20
say multiply 5 6
say max2 99 42

// Minimal syntax vs old verbose syntax comparison
say "=== Syntax Comparison ==="
say "Minimal: fn double n = n * 2"
say "Old style: fn double(n) { return n * 2 }"
say "Lipi 2.0 uses Minimal style globally"

say "PASS: Test 42 Bilingual Syntax"
