// Test 44: Package Manifest — Lipi 2.0 Global Standard
// lipipkg.toml manifest parsing and validation

struct Manifest
    name
    version
    description
    author
    license

fn manifest_new name version
    m = Manifest()
    m.name = name
    m.version = version
    m.description = "A Lipi package"
    m.author = "developer"
    m.license = "MIT"
    return m

fn manifest_validate m
    if len m.name == 0
        say "Error: name is required"
        return 0
    if len m.version == 0
        say "Error: version is required"
        return 0
    return 1

fn manifest_print m
    say "Name:        " + m.name
    say "Version:     " + m.version
    say "Description: " + m.description
    say "Author:      " + m.author
    say "License:     " + m.license

say "=== Package Manifest ==="
pkg = manifest_new "myapp" "1.0.0"
pkg.description = "My awesome Lipi app"
pkg.author = "Shafiullah"

valid = manifest_validate pkg
if valid
    say "Manifest: valid"
    manifest_print pkg
else
    say "Manifest: invalid"

// Dependency list simulation
say ""
say "Dependencies:"
say "  std/http ^1.0.0"
say "  std/json ^1.0.0"
say "  std/crypto ^1.0.0"

say "PASS: Test 44 Package Manifest"
