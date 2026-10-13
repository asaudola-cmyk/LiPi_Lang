// ==============================================================================
// 👑 LIPI UNIVERSE CORE — GRAND UMBRELLA PRELUDE (utso/core.lp)
// ⚡ 100% Pure Sovereign Lipi Machine Code Engine | 0% C | 0% Libc
// ==============================================================================
//
// WHY: Provides a unified gateway for fundamental core runtime primitives:
// memory management, arena allocators, dynamic collections, string operations,
// file I/O, mathematical functions, and time utilities.
// Developers can simply write:
//     import "utso/core"
// to access all core standard library capabilities in a single import.
// ==============================================================================
import "utso/core/memory"
import "utso/core/arena"
import "utso/core/collections"
import "utso/core/hashmap"
import "utso/core/string"
import "utso/core/io"
import "utso/core/math"
import "utso/core/time"

// ── Core Version Gateway ──────────────────────────────────────────────────────
// WHY: Returns the canonical fixed version string for runtime checks.
fn lipi_core_version
    return "First 1.0.0 (প্রথম ১.০.০)"

fn লিপি_মূল_সংস্করণ
    return lipi_core_version()
