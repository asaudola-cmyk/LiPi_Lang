// ==============================================================================
// 🧠 LIPI UNIFIED TOOLKIT: LSP VIRTUAL DOCUMENT REGISTRY (src/toolkit/lsp/document_store.lp)
// ⚡ 100% Pure Sovereign Lipi First 1.0.0 | In-Memory AST & Buffer State Machine
// ==============================================================================
//
// WHY THIS MODULE:
// An IDE language server cannot read files directly from disk during active editing,
// as in-memory editor buffers contain unsaved modifications, incomplete syntax, and
// rapid keystrokes.
// This module provides:
// 1. In-memory virtual document registry synchronizing open file buffers.
// 2. Pre-computed line offset index enabling O(1) line/character to byte mapping.
// 3. Robust token extraction at cursor coordinates for hover, definition, and autocompletion.
// 4. Memory-safe buffer updates with automatic line boundary re-indexing.

include "universe/core/memory.lp"
include "universe/core/string.lp"
include "universe/core/io.lp"

// ── 1. Data Structures ────────────────────────────────────────────────────────

// WHY: Encapsulates single live virtual buffer tracked by the language server.
struct LspDocument
    uri             // Full document URI (e.g. "file:///project/src/main.lp")
    version         // Monotonically increasing client buffer revision counter
    text            // Complete source text buffer content
    line_offsets    // List of starting byte offsets for each line
    line_count      // Total number of lines in document

// WHY: Central repository indexing all active open documents across workspace.
struct DocumentStore
    documents       // List of tracked LspDocument structs
    count           // Active document count

// ── 2. Line Index Builder ─────────────────────────────────────────────────────

// WHY: Pre-computes starting offset of every line to allow instant O(1) coordinate mapping.
fn doc_build_line_index doc
    tlen = len(doc.text)
    offsets = list()
    push(offsets, 0) // Line 0 starts at offset 0

    i = 0
    while i < tlen
        if char_at(doc.text, i) == "\n"
            push(offsets, i + 1)
        i = i + 1

    doc.line_offsets = offsets
    doc.line_count = len(offsets)
    return doc.line_count

// ── 3. Store Constructor & Lifecycle ──────────────────────────────────────────

// WHY: Allocates clean document store registry.
fn doc_store_new
    store = DocumentStore()
    store.documents = list()
    store.count = 0
    return store

// WHY: Locates document record by URI within registry. Returns 0 if not tracked.
fn doc_store_get store uri
    docs = store.documents
    c = len(docs)
    i = 0
    while i < c
        doc = get(docs, i)
        if doc.uri == uri
            return doc
        i = i + 1
    return 0

// WHY: Registers newly opened file buffer received via textDocument/didOpen.
fn doc_store_open store uri version text
    existing = doc_store_get(store, uri)
    if existing != 0
        existing.version = version
        existing.text = text
        doc_build_line_index(existing)
        return existing

    doc = LspDocument()
    doc.uri = uri
    doc.version = version
    doc.text = text
    doc.line_offsets = list()
    doc.line_count = 0
    doc_build_line_index(doc)

    push(store.documents, doc)
    store.count = store.count + 1
    return doc

// WHY: Synchronizes buffer mutations received via textDocument/didChange.
fn doc_store_change store uri version new_text
    doc = doc_store_get(store, uri)
    if doc == 0
        return doc_store_open(store, uri, version, new_text)

    doc.version = version
    doc.text = new_text
    doc_build_line_index(doc)
    return doc

// WHY: Purges tracked document buffer received via textDocument/didClose.
fn doc_store_close store uri
    docs = store.documents
    c = len(docs)
    i = 0
    new_list = list()
    while i < c
        doc = get(docs, i)
        if doc.uri != uri
            push(new_list, doc)
        i = i + 1
    store.documents = new_list
    store.count = len(new_list)
    return 0

// ── 4. Coordinate Translation & Inspection ────────────────────────────────────

// WHY: Returns pre-indexed line count of document.
fn doc_get_line_count doc
    if doc == 0 return 0
    return doc.line_count

// WHY: Converts 0-indexed LSP (line, character) coordinate to absolute byte offset.
fn doc_pos_to_offset doc line character
    if line < 0 return 0
    if line >= doc.line_count
        return len(doc.text)

    line_start = get(doc.line_offsets, line)
    target_offset = line_start + character
    tlen = len(doc.text)

    if target_offset > tlen
        return tlen
    return target_offset

// WHY: Retrieves full text of single line by 0-indexed line number.
fn doc_get_line doc line_idx
    if line_idx < 0 or line_idx >= doc.line_count
        return ""

    line_start = get(doc.line_offsets, line_idx)
    tlen = len(doc.text)

    line_end = line_start
    while line_end < tlen and char_at(doc.text, line_end) != "\n"
        line_end = line_end + 1

    return str_sub(doc.text, line_start, line_end)

// WHY: Identifies whether character belongs to an identifier or language token.
fn doc_is_token_char ch
    code = ord(ch)
    // Support UTF-8 multi-byte Bengali characters
    if code > 127 return 1
    // ASCII alphanumeric & identifier characters (a-z, A-Z, 0-9, _)
    if code >= 97 and code <= 122 return 1
    if code >= 65 and code <= 90 return 1
    if code >= 48 and code <= 57 return 1
    if code == 95 return 1
    return 0

// WHY: Extracts the word/symbol token underneath the editor cursor.
// Essential for textDocument/hover, completion, and definition lookups.
fn doc_get_token_at doc line character
    if line < 0 or line >= doc.line_count
        return ""

    line_start = get(doc.line_offsets, line)
    tlen = len(doc.text)

    line_end = line_start
    while line_end < tlen and char_at(doc.text, line_end) != "\n"
        line_end = line_end + 1

    cursor = line_start + character
    if cursor >= line_end and cursor > line_start
        cursor = line_end - 1
    if cursor >= tlen or cursor < line_start
        return ""

    // Walk backward to token start boundary
    w_start = cursor
    while w_start > line_start and doc_is_token_char(char_at(doc.text, w_start - 1)) == 1
        w_start = w_start - 1

    // Walk forward to token end boundary
    w_end = cursor
    while w_end < line_end and doc_is_token_char(char_at(doc.text, w_end)) == 1
        w_end = w_end + 1

    if w_start >= w_end return ""
    return str_sub(doc.text, w_start, w_end)
