// ==============================================================================
// 👑 LIPI UNIVERSE DB — GRAND UMBRELLA PRELUDE (aati/lipidb/db.lp)
// ⚡ 100% Pure Sovereign Lipi Machine Code Engine | Zero C | Zero External Tools
// ==============================================================================
//
// WHY: Provides a unified gateway for all database engines in Lipi.
// Developers can simply write:
//     import "aati/lipidb/db"
// to access LipiKV storage, B+Tree indexing, Write-Ahead Logging (WAL),
// ACID transactions, columnar analytics, and vector embeddings.
// ==============================================================================
import "aati/lipidb/page"
import "aati/lipidb/buffer"
import "aati/lipidb/btree"
import "aati/lipidb/wal"
import "aati/lipidb/engine"
import "aati/lipidb/kv"

// ── Database Engine Factory ───────────────────────────────────────────────────
// WHY: Opens or creates an ACID-compliant LipiKV database with Write-Ahead Logging.
@fn lipi_db_open(path, capacity)
    if capacity <= 0
        capacity = 64
    end
    return db_open(path, capacity)
@end

@fn লিপি_ডিবি_ওপেন(পাথ, ক্ষমতা)
    return lipi_db_open(পাথ, ক্ষমতা)
@end
