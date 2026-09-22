// ==============================================================================
// 📦 LIPI UNIFIED TOOLKIT: PACKAGE MANIFEST PARSER & SERIALIZER (src/toolkit/pkg/manifest_parser.lp)
// ⚡ 100% Pure Sovereign Lipi First 1.0.0 | lipi.pkg Configuration Format Engine
// ==============================================================================
//
// WHY THIS MODULE:
// Package management and reproducible builds depend on declarative project metadata.
// In the LiPi ecosystem, `lipi.pkg` serves as the authoritative manifest specifying:
// 1. Package identity (name, semantic version, description, authors, license).
// 2. Build entry point and output target binaries.
// 3. Exact dependency version constraints.
// This module provides zero-dependency parsing and serialization of `lipi.pkg` files
// without external TOML or INI parser libraries.

include "universe/core/memory.lp"
include "universe/core/string.lp"
include "universe/core/io.lp"

// ── 1. Data Structures ────────────────────────────────────────────────────────

// WHY: Encapsulates single package dependency version constraint.
struct PkgDep
    dep_name            // Dependency package name
    dep_version         // Required version or semver pattern

// WHY: Canonical model representing entire project configuration with collision-free fields.
struct PkgManifest
    pkg_name            // Project name
    pkg_version         // Package semantic version (e.g. "1.0.0")
    pkg_description     // Project summary description
    pkg_author          // Maintainer or author information
    pkg_license         // Open source / sovereign license identifier
    pkg_entry           // Main compilation entry file (e.g. "src/main.lp")
    pkg_target          // Compiled output binary path (e.g. "bin/my_project")
    pkg_opt             // Optimization level ("debug" or "release")
    pkg_dependencies    // List of PkgDep structs

// ── 2. String Cleaning & Tokenization Helpers ─────────────────────────────────

// WHY: Strips leading spaces and tabs.
fn pkg_trim_left s
    slen = len(s)
    i = 0
    while i < slen
        c = char_at(s, i)
        if c != " " and c != "\t" and c != "\r"
            break
        i = i + 1
    if i >= slen return ""
    return str_sub(s, i, slen)

// WHY: Strips trailing spaces, tabs, and carriage returns.
fn pkg_trim_right s
    slen = len(s)
    if slen == 0 return ""
    j = slen - 1
    while j >= 0
        c = char_at(s, j)
        if c != " " and c != "\t" and c != "\r" and c != "\n"
            break
        j = j - 1
    if j < 0 return ""
    return str_sub(s, 0, j + 1)

// WHY: Strips leading and trailing whitespace.
fn pkg_trim s
    return pkg_trim_right(pkg_trim_left(s))

// WHY: Strips surrounding double or single quotation marks.
fn pkg_strip_quotes s
    trimmed = pkg_trim(s)
    tlen = len(trimmed)
    if tlen >= 2
        first_c = char_at(trimmed, 0)
        last_c = char_at(trimmed, tlen - 1)
        if (first_c == "\"" and last_c == "\"") or (first_c == "'" and last_c == "'")
            return str_sub(trimmed, 1, tlen - 1)
    return trimmed

// ── 3. Constructor Primitives ─────────────────────────────────────────────────

// WHY: Allocates clean PkgManifest instance with default configuration values.
fn pkg_manifest_new
    m = PkgManifest()
    m.pkg_name = ""
    m.pkg_version = "1.0.0"
    m.pkg_description = ""
    m.pkg_author = ""
    m.pkg_license = "MIT"
    m.pkg_entry = "src/main.lp"
    m.pkg_target = "bin/main"
    m.pkg_opt = "release"
    m.pkg_dependencies = list()
    return m

// ── 4. Manifest Parser Engine ─────────────────────────────────────────────────

// WHY: Parses raw `lipi.pkg` text content into a structured PkgManifest model.
fn pkg_manifest_parse content
    manifest = pkg_manifest_new()
    clen = len(content)
    if clen == 0 return manifest

    current_section = ""
    line_start = 0
    i = 0

    while i <= clen
        is_eol = 0
        if i == clen
            is_eol = 1
        elif char_at(content, i) == "\n"
            is_eol = 1

        if is_eol == 1
            line = str_sub(content, line_start, i)
            trimmed = pkg_trim(line)
            tlen = len(trimmed)

            // Skip empty lines and comments (# or //)
            if tlen > 0 and char_at(trimmed, 0) != "#"
                if tlen < 2 or str_sub(trimmed, 0, 2) != "//"
                    // Check for section header: [section]
                    if char_at(trimmed, 0) == "[" and char_at(trimmed, tlen - 1) == "]"
                        current_section = str_sub(trimmed, 1, tlen - 1)
                    else
                        // Key-value pair: find '=' or ':'
                        eq_idx = -1
                        k_idx = 0
                        while k_idx < tlen
                            c = char_at(trimmed, k_idx)
                            if c == "=" or c == ":"
                                eq_idx = k_idx
                                break
                            k_idx = k_idx + 1

                        if eq_idx > 0
                            raw_k = str_sub(trimmed, 0, eq_idx)
                            raw_v = str_sub(trimmed, eq_idx + 1, tlen)
                            key = pkg_trim(raw_k)
                            val = pkg_strip_quotes(raw_v)

                            if current_section == "package" or current_section == ""
                                if key == "name" manifest.pkg_name = val
                                elif key == "version" manifest.pkg_version = val
                                elif key == "description" manifest.pkg_description = val
                                elif key == "author" manifest.pkg_author = val
                                elif key == "license" manifest.pkg_license = val
                            elif current_section == "build"
                                if key == "entry" manifest.pkg_entry = val
                                elif key == "target" manifest.pkg_target = val
                                elif key == "opt" manifest.pkg_opt = val
                            elif current_section == "dependencies"
                                dep = PkgDep()
                                dep.dep_name = key
                                dep.dep_version = val
                                push(manifest.pkg_dependencies, dep)

            line_start = i + 1
        i = i + 1

    return manifest

// ── 5. Manifest Serializer Engine ─────────────────────────────────────────────

// WHY: Serializes PkgManifest struct into canonical, formatted `lipi.pkg` text.
fn pkg_manifest_serialize manifest
    out = "# ==============================================================================\n"
    out = out + "# 📦 LIPI PACKAGE CONFIGURATION (lipi.pkg)\n"
    out = out + "# ==============================================================================\n\n"

    out = out + "[package]\n"
    out = out + "name = \"" + manifest.pkg_name + "\"\n"
    out = out + "version = \"" + manifest.pkg_version + "\"\n"
    if len(manifest.pkg_description) > 0
        out = out + "description = \"" + manifest.pkg_description + "\"\n"
    if len(manifest.pkg_author) > 0
        out = out + "author = \"" + manifest.pkg_author + "\"\n"
    if len(manifest.pkg_license) > 0
        out = out + "license = \"" + manifest.pkg_license + "\"\n"
    out = out + "\n"

    out = out + "[build]\n"
    out = out + "entry = \"" + manifest.pkg_entry + "\"\n"
    out = out + "target = \"" + manifest.pkg_target + "\"\n"
    out = out + "opt = \"" + manifest.pkg_opt + "\"\n"
    out = out + "\n"

    out = out + "[dependencies]\n"
    deps = manifest.pkg_dependencies
    c = len(deps)
    i = 0
    while i < c
        dep = get(deps, i)
        out = out + dep.dep_name + " = \"" + dep.dep_version + "\"\n"
        i = i + 1

    return out

// ── 6. File I/O & Dependency Helpers ──────────────────────────────────────────

// WHY: Loads manifest file from disk via pure kernel read operations.
fn pkg_manifest_load file_path
    if file_exists(file_path) == 0
        return pkg_manifest_new()
    content = file_read(file_path)
    return pkg_manifest_parse(content)

// WHY: Saves serialized manifest to specified file path.
fn pkg_manifest_save manifest file_path
    content = pkg_manifest_serialize(manifest)
    return file_write(file_path, content)

// WHY: Adds or updates dependency constraint in manifest.
fn pkg_manifest_add_dep manifest dep_name dep_version
    deps = manifest.pkg_dependencies
    c = len(deps)
    i = 0
    while i < c
        d = get(deps, i)
        if d.dep_name == dep_name
            d.dep_version = dep_version
            return d
        i = i + 1
    new_dep = PkgDep()
    new_dep.dep_name = dep_name
    new_dep.dep_version = dep_version
    push(manifest.pkg_dependencies, new_dep)
    return new_dep

// WHY: Retrieves dependency version constraint by name.
fn pkg_manifest_get_dep manifest dep_name
    deps = manifest.pkg_dependencies
    c = len(deps)
    i = 0
    while i < c
        d = get(deps, i)
        if d.dep_name == dep_name
            return d.dep_version
        i = i + 1
    return ""
