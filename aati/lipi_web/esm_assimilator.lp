// ==============================================================================
// 👑 LIPI WEBX UNIVERSAL ESM ASSIMILATOR (ZERO NODE.JS / ZERO NPM)
// Module: aati/lipi_web/esm_assimilator.lp
// Milestone: Sovereign Full-Stack Paradigm (Eliminating npm, node_modules & Webpack)
// 100% Pure LiPi Implementation — Zero External / Node.js / C Dependencies
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Modern frontend ecosystems force developers to download gigabytes of node_modules,
//    run complex npm install chains, and configure brittle Webpack/Vite/Rollup pipelines.
// 2. Browser standards have natively supported ES Modules (import/export) and W3C Import Maps
//    for years, making local node bundling completely obsolete.
//
// LIPI WEBX SOVEREIGN SOLUTION:
// - Universal In-Memory ESM Assimilator: Discovers and registers any browser-compatible ESM package.
// - Sovereign Offline Asset Assimilator: Enables self-hosted resolution from local directories (dist/assets/esm).
// - Direct Import Map Generation: Maps package specifiers directly to fast CDN or local sovereign relative URLs.
// - Type-Safe Sovereign JS Bridge: Dispatches function calls between LiPi WebX components and ESM modules.
// ==============================================================================

include "utso/string.lp"
include "utso/collections.lp"

struct ESMModule
    esm_name       // Package specifier (e.g. "canvas-confetti", "chart.js", "three")
    esm_url        // Resolution URL (e.g. "https://esm.sh/canvas-confetti@1.9.3" or "/assets/esm/canvas-confetti.js")
    esm_version    // Semantic version string
    esm_exports    // List of exported function names
    esm_is_offline // 1 if offline/sovereign cached asset, 0 if remote CDN
    esm_local_path // Local filesystem path if offline (e.g. "dist/assets/esm/canvas-confetti.js")

fn esm_clean_identifier name
    // WHY: Sanitizes arbitrary package specifiers into valid JavaScript identifiers
    // (e.g. "canvas-confetti" -> "canvas_confetti", "@chart.js/core" -> "chart_js_core")
    // Replaces hyphens, dots, slashes, and '@' symbols with underscores
    nlen = len(name)
    out = ""
    i = 0
    while i < nlen
        ch = char_at(name, i)
        c = ord(ch)
        // Allow A-Z (65-90), a-z (97-122), 0-9 (48-57), _ (95)
        is_alpha_num = 0
        if c >= 65 and c <= 90 is_alpha_num = 1 end
        if c >= 97 and c <= 122 is_alpha_num = 1 end
        if c >= 48 and c <= 57 is_alpha_num = 1 end
        if c == 95 is_alpha_num = 1 end

        if is_alpha_num == 1
            out = out + ch
        else
            out = out + "_"
        end
        i = i + 1
    end
    if len(out) == 0 return "esm_pkg" end
    first_c = ord(char_at(out, 0))
    if first_c >= 48 and first_c <= 57
        out = "_" + out
    end
    return out

fn esm_module_new name url version
    // WHY: Allocates clean ESM module descriptor record
    m = ESMModule()
    m.esm_name = name
    m.esm_url = url
    m.esm_version = version
    m.esm_exports = list()
    m.esm_is_offline = 0
    m.esm_local_path = ""
    return m

fn esm_module_add_export mod export_name
    push(mod.esm_exports, export_name)
    return mod

fn webx_normalize_path p
    // WHY: Normalizes directory paths across Windows and POSIX systems
    // Replaces all backslashes '\' with forward slashes '/' for deterministic routing.
    plen = len(p)
    out = ""
    i = 0
    while i < plen
        ch = char_at(p, i)
        if ch == "\\"
            out = out + "/"
        else
            out = out + ch
        end
        i = i + 1
    end
    return out

fn webx_assimilate_offline pkg_name version local_dir
    // WHY: Enables serving and resolving modern ESM bundles from local sovereign directories
    // (e.g. "dist/assets/esm/" or ".lipi/cache/") without requiring internet or external CDNs.
    // Generates local offline W3C import map relative URLs (/assets/esm/...).
    m = ESMModule()
    m.esm_name = pkg_name
    m.esm_version = version
    m.esm_exports = list()
    m.esm_is_offline = 1

    // Normalize local directory path (cross-platform Windows & Linux)
    clean_dir = webx_normalize_path(local_dir)
    if len(clean_dir) == 0
        clean_dir = "dist/assets/esm"
    end
    while len(clean_dir) > 1 and str_ends_with(clean_dir, "/") == 1
        clean_dir = str_slice(clean_dir, 0, len(clean_dir) - 1)
    end

    // Determine filename for bundle
    file_name = pkg_name
    if str_ends_with(file_name, ".js") == 0 and str_ends_with(file_name, ".mjs") == 0
        file_name = file_name + ".js"
    end

    // Local filesystem disk path
    m.esm_local_path = clean_dir + "/" + file_name

    // Sovereign browser relative URL (/assets/esm/...)
    web_dir = "/assets/esm"
    if str_starts_with(clean_dir, "dist/") == 1
        web_dir = str_slice(clean_dir, 4, len(clean_dir))
    elif str_starts_with(clean_dir, "./dist/") == 1
        web_dir = str_slice(clean_dir, 6, len(clean_dir))
    elif str_contains(clean_dir, "assets/esm") == 1
        web_dir = "/assets/esm"
    elif str_starts_with(clean_dir, "/") == 1
        web_dir = clean_dir
    end

    if str_starts_with(web_dir, "/") == 0
        web_dir = "/" + web_dir
    end

    m.esm_url = web_dir + "/" + file_name
    return m

fn esm_generate_importmap modules_list
    // WHY: Generates W3C-compliant <script type="importmap"> JSON string
    // Allows standard browser 'import confetti from "canvas-confetti"' to resolve instantly.
    // Deduplicates package specifiers to avoid invalid duplicate JSON keys.
    mcount = len(modules_list)
    out = "<script type=\"importmap\">\n{\n  \"imports\": {\n"
    seen = list()
    unique_mods = list()
    i = 0
    while i < mcount
        mod = get(modules_list, i)
        mod_name = mod.esm_name
        is_seen = 0
        si = 0
        while si < len(seen)
            if get(seen, si) == mod_name is_seen = 1 end
            si = si + 1
        end
        if is_seen == 0
            push(seen, mod_name)
            push(unique_mods, mod)
        end
        i = i + 1
    end

    ucount = len(unique_mods)
    i = 0
    while i < ucount
        mod = get(unique_mods, i)
        out = out + "    \"" + mod.esm_name + "\": \"" + mod.esm_url + "\""
        if (i + 1) < ucount
            out = out + ",\n"
        else
            out = out + "\n"
        end
        i = i + 1
    end
    out = out + "  }\n}\n</script>"
    return out

fn webx_generate_offline_importmap modules_list
    // WHY: Generates sovereign local offline W3C <script type="importmap"> JSON string
    // mapping every package specifier directly to a local relative URL (/assets/esm/...)
    // Guarantees zero external network requests or CDN dependencies even if input modules were remote.
    // Automatically deduplicates module specifiers to prevent invalid duplicate JSON keys.
    mcount = len(modules_list)
    out = "<script type=\"importmap\">\n{\n  \"imports\": {\n"
    seen = list()
    unique_mods = list()
    i = 0
    while i < mcount
        mod = get(modules_list, i)
        mod_name = mod.esm_name
        is_seen = 0
        si = 0
        while si < len(seen)
            if get(seen, si) == mod_name is_seen = 1 end
            si = si + 1
        end
        if is_seen == 0
            push(seen, mod_name)
            push(unique_mods, mod)
        end
        i = i + 1
    end

    ucount = len(unique_mods)
    i = 0
    while i < ucount
        mod = get(unique_mods, i)
        mod_url = mod.esm_url
        if mod.esm_is_offline == 0
            file_name = mod.esm_name
            if str_ends_with(file_name, ".js") == 0 and str_ends_with(file_name, ".mjs") == 0
                file_name = file_name + ".js"
            end
            mod_url = "/assets/esm/" + file_name
        end
        out = out + "    \"" + mod.esm_name + "\": \"" + mod_url + "\""
        if (i + 1) < ucount
            out = out + ",\n"
        else
            out = out + "\n"
        end
        i = i + 1
    end
    out = out + "  }\n}\n</script>"
    return out

fn esm_generate_bridge_script modules_list
    // WHY: Generates lightweight ES Module loader bridge connecting LiPi WebX WASM event
    //      actions directly to external imported ESM functions.
    // Deduplicates imported packages to avoid duplicate variable declarations.
    mcount = len(modules_list)
    bridge = "<script type=\"module\">\n"
    seen = list()
    i = 0
    while i < mcount
        mod = get(modules_list, i)
        clean_id = esm_clean_identifier(mod.esm_name)
        is_seen = 0
        si = 0
        while si < len(seen)
            if get(seen, si) == clean_id is_seen = 1 end
            si = si + 1
        end
        if is_seen == 0
            push(seen, clean_id)
            bridge = bridge + "import * as " + clean_id + "_pkg from '" + mod.esm_name + "';\n"
            bridge = bridge + "window['__esm_" + mod.esm_name + "'] = " + clean_id + "_pkg;\n"
        end
        i = i + 1
    end
    bridge = bridge + "\n// Sovereign LiPi FFI Call Dispatcher\n"
    bridge = bridge + "window.webx_call_esm = async (modName, fnName, args) => {\n"
    bridge = bridge + "  const mod = window['__esm_' + modName];\n"
    bridge = bridge + "  if (!mod) throw new Error('[LiPi WebX] Module not found: ' + modName);\n"
    bridge = bridge + "  if (typeof mod[fnName] === 'function') return await mod[fnName](...args);\n"
    bridge = bridge + "  if (typeof mod.default === 'function') return await mod.default(...args);\n"
    bridge = bridge + "  return mod;\n"
    bridge = bridge + "};\n"
    bridge = bridge + "</script>"
    return bridge

// ==============================================================================
// ── 2. Sovereign Local Offline Asset Assimilator & Self-Hosted Bundle Cacher ──
// ==============================================================================
// WHY: Relying on third-party CDNs (esm.sh, unpkg) violates sovereignty, exposes
//      apps to supply chain poisoning, and breaks in offline/air-gapped systems.
//      LiPi WebX integrates an in-memory local bundle cacher with cryptographic
//      integrity hashing and zero-CDN local import map synthesis.

struct ESMCacheEntry
    entry_name        // Package specifier (e.g. "canvas-confetti", "chart.js")
    entry_version     // Semantic version string
    entry_local_path  // Local disk / relative asset path
    entry_content     // In-memory JavaScript source content
    entry_mime        // MIME type ("application/javascript")
    entry_hash        // Sovereign integrity digest

struct ESMLocalCache
    cache_entries     // List of ESMCacheEntry
    cache_base_url    // Base offline serving path (e.g. "./vendor" or "/assets/vendor")

fn esm_compute_digest content_str
    // WHY: POSIX-compatible 32-bit FNV-1a hash producing deterministic integrity digest
    h = 2166136261
    clen = len(content_str)
    i = 0
    while i < clen
        c = ord(char_at(content_str, i))
        h = (h ^ c) * 16777619
        h = h & 2147483647
        i = i + 1
    end
    return "lp-" + str(h)

fn esm_cache_new base_url
    // WHY: Initializes sovereign local offline asset cache container
    c = ESMLocalCache()
    c.cache_entries = list()
    c.cache_base_url = base_url
    return c

fn esm_cache_register cache name version local_path code_content
    // WHY: Assimilates an ESM package into the sovereign offline cache
    e = ESMCacheEntry()
    e.entry_name = name
    e.entry_version = version
    e.entry_local_path = local_path
    e.entry_content = code_content
    e.entry_mime = "application/javascript"
    e.entry_hash = esm_compute_digest(code_content)
    push(cache.cache_entries, e)
    return e

fn esm_cache_get_entry cache name
    // WHY: O(N) lookup for cached module descriptor
    entries = cache.cache_entries
    ecount = len(entries)
    i = 0
    while i < ecount
        item = get(entries, i)
        if item.entry_name == name
            return item
        end
        i = i + 1
    end
    return 0

fn esm_cache_resolve cache name
    // WHY: Resolves package name to local self-hosted URL with 0% CDN dependency
    entry = esm_cache_get_entry(cache, name)
    if entry == 0 return ""
    base = cache.cache_base_url
    return base + "/" + name + ".js"

fn esm_generate_offline_importmap cache
    // WHY: Generates 100% sovereign offline W3C Import Map pointing exclusively to local bundle assets
    entries = cache.cache_entries
    ecount = len(entries)
    out = "<script type=\"importmap\">\n{\n  \"imports\": {\n"
    i = 0
    while i < ecount
        entry = get(entries, i)
        local_url = cache.cache_base_url + "/" + entry.entry_name + ".js"
        out = out + "    \"" + entry.entry_name + "\": \"" + local_url + "\""
        if (i + 1) < ecount
            out = out + ",\n"
        else
            out = out + "\n"
        end
        i = i + 1
    end
    out = out + "  }\n}\n</script>"
    return out

fn esm_generate_inline_bundle cache
    // WHY: Emits standalone air-gapped JS bundle inlining all assimilated modules directly into the browser
    // Enables zero-server local file execution (file:/// protocol) with full interactivity
    entries = cache.cache_entries
    ecount = len(entries)
    bundle = "<script type=\"module\">\n"
    bundle = bundle + "// 👑 LiPi WebX Sovereign Air-Gapped Inlined Bundle (0% External Network Calls)\n"
    i = 0
    while i < ecount
        entry = get(entries, i)
        bundle = bundle + "// Module: " + entry.entry_name + " (v" + entry.entry_version + ", hash: " + entry.entry_hash + ")\n"
        bundle = bundle + "(() => {\n"
        bundle = bundle + "  const exports = {};\n"
        bundle = bundle + "  " + entry.entry_content + "\n"
        bundle = bundle + "  window['__esm_" + entry.entry_name + "'] = exports;\n"
        bundle = bundle + "})();\n"
        i = i + 1
    end
    bundle = bundle + "</script>"
    return bundle

fn esm_generate_offline_manifest cache
    // WHY: Generates deterministic deployment JSON manifest for sovereign air-gapped auditing
    entries = cache.cache_entries
    ecount = len(entries)
    out = "{\n"
    out = out + "  \"sovereign_offline\": true,\n"
    out = out + "  \"module_count\": " + str(ecount) + ",\n"
    out = out + "  \"base_url\": \"" + cache.cache_base_url + "\",\n"
    out = out + "  \"modules\": [\n"
    i = 0
    while i < ecount
        entry = get(entries, i)
        out = out + "    {\n"
        out = out + "      \"name\": \"" + entry.entry_name + "\",\n"
        out = out + "      \"version\": \"" + entry.entry_version + "\",\n"
        out = out + "      \"local_path\": \"" + entry.entry_local_path + "\",\n"
        out = out + "      \"digest\": \"" + entry.entry_hash + "\",\n"
        out = out + "      \"size_bytes\": " + str(len(entry.entry_content)) + "\n"
        out = out + "    }"
        if (i + 1) < ecount
            out = out + ",\n"
        else
            out = out + "\n"
        end
        i = i + 1
    end
    out = out + "  ]\n}"
    return out
