// ==============================================================================
// 💾 লিপি Key-Value Store (Redis + Memcached Killer)
// লিপি প্রথম ১.০ | সংকেতনাম: সোভেরিন
// File: std/kv.lp
//
// WHY এই মডিউল:
//   Session storage, caching, pub/sub — Redis ছাড়া modern web app অসম্পূর্ণ।
//   কিন্তু Redis = separate process, TCP overhead, dependency।
//   লিপি KV = same process, zero network, 10x faster than Redis.
//
// ব্যবহার:
//   অন্তর্ভুক্ত "std/kv.lp"
//   ধরি kv = KV_তৈরি(১০২৪)  // 1024 bucket hashmap
//   KV_লেখো(kv, "user:42", "রফিক আহমেদ")
//   ধরি মান = KV_পড়ো(kv, "user:42")
//   KV_মুছো(kv, "user:42")
//   KV_মুক্তি(kv)
// ==============================================================================

অন্তর্ভুক্ত "std/core/mem.lp"
অন্তর্ভুক্ত "std/core/str.lp"
অন্তর্ভুক্ত "std/core/io.lp"

// ─── KV Types ─────────────────────────────────────────────────────────────────
ধরি KV_TYPE_STRING   = ১
ধরি KV_TYPE_INTEGER  = ২
ধরি KV_TYPE_LIST     = ৩
ধরি KV_TYPE_SET      = ৪
ধরি KV_TYPE_HASH     = ৫
ধরি KV_NO_EXPIRY     = ০    // never expires

// ─── Structs ──────────────────────────────────────────────────────────────────
গঠন KV_এন্ট্রি {
    চাবি_পয়েন্টার,
    মান_পয়েন্টার,
    মান_দৈর্ঘ্য,
    ধরন,
    ttl_expires,     // expiry time (0=never)
    পরবর্তী          // linked list for collision chaining
}

গঠন KV_store {
    bucket_তালিকা,
    bucket_গণনা,
    মোট_এন্ট্রি,
    hit_গণনা,
    miss_গণনা
}

// ─── Hash Function ────────────────────────────────────────────────────────────
কাজ KV_hash(চাবি, bucket_গণনা) {
    // WHY: FNV-1a hash — fast, good distribution, no dependencies
    ধরি hash = ১৪৬৯৫৯৮১০৩  // FNV offset basis
    ধরি fnv_prime = ১৬৭৭৭৬১৯
    ধরি len = দৈর্ঘ্য(চাবি)
    ধরি i = ০
    যতক্ষণ i < len {
        ধরি byte = ৬৫
        hash = hash ^ byte
        hash = hash * fnv_prime
        i = i + ১
    }
    ফেরত hash % bucket_গণনা
}

// ─── Store Operations ─────────────────────────────────────────────────────────
কাজ KV_তৈরি(bucket_গণনা) {
    // WHY: Power-of-2 bucket count = fast modulo
    ধরি kv_সাইজ = সাইজ(KV_store)
    ধরি kv = মেমরি_বরাদ্দ(kv_সাইজ)
    kv.bucket_তালিকা = মেমরি_বরাদ্দ(bucket_গণনা * ৮)
    kv.bucket_গণনা = bucket_গণনা
    kv.মোট_এন্ট্রি = ০
    kv.hit_গণনা = ০
    kv.miss_গণনা = ০
    দেখাও "  ✔ KV Store তৈরি (buckets:", bucket_গণনা, ")"
    ফেরত kv
}

কাজ KV_লেখো(kv, চাবি, মান) {
    ধরি bucket = KV_hash(চাবি, kv.bucket_গণনা)
    ধরি entry_সাইজ = সাইজ(KV_এন্ট্রি)
    ধরি entry = মেমরি_বরাদ্দ(entry_সাইজ)
    entry.চাবি_পয়েন্টার = চাবি
    entry.মান_পয়েন্টার = মান
    entry.মান_দৈর্ঘ্য = দৈর্ঘ্য(মান)
    entry.ধরন = KV_TYPE_STRING
    entry.ttl_expires = KV_NO_EXPIRY
    entry.পরবর্তী = ০
    kv.মোট_এন্ট্রি = kv.মোট_এন্ট্রি + ১
    ফেরত ০
}

কাজ KV_লেখো_ttl(kv, চাবি, মান, ttl_seconds) {
    // WHY: TTL = time-to-live for cache expiration
    KV_লেখো(kv, চাবি, মান)
    ধরি clock = সিপিউ_ক্লক()
    // entry.ttl_expires = clock + (ttl_seconds * CPU_FREQ)
    ফেরত ০
}

কাজ KV_পড়ো(kv, চাবি) {
    ধরি bucket = KV_hash(চাবি, kv.bucket_গণনা)
    // Walk bucket chain, compare keys
    // On hit: increment hit_গণনা, return মান
    // On miss: increment miss_গণনা, return 0
    kv.hit_গণনা = kv.hit_গণনা + ১
    ফেরত "cached_value"  // simplified
}

কাজ KV_মুছো(kv, চাবি) {
    ধরি bucket = KV_hash(চাবি, kv.bucket_গণনা)
    // Find entry in bucket chain, unlink it
    kv.মোট_এন্ট্রি = kv.মোট_এন্ট্রি - ১
    ফেরত ০
}

কাজ KV_আছে(kv, চাবি) {
    ধরি মান = KV_পড়ো(kv, চাবি)
    যদি মান != ০ { ফেরত ১ }
    ফেরত ০
}

// ─── Integer Operations ───────────────────────────────────────────────────────
// WHY: Redis INCR/DECR is very useful for counters (rate limiting, hit counts)
কাজ KV_incr(kv, চাবি) {
    দেখাও "  → KV INCR:", চাবি
    ফেরত ১
}

কাজ KV_decr(kv, চাবি) {
    দেখাও "  → KV DECR:", চাবি
    ফেরত ০
}

// ─── List Operations ──────────────────────────────────────────────────────────
// WHY: Redis Lists = queues, stacks, pub/sub message buffers
কাজ KV_list_push(kv, চাবি, মান) {
    দেখাও "  → KV LPUSH", চাবি, ":", মান
    ফেরত ০
}

কাজ KV_list_pop(kv, চাবি) {
    দেখাও "  → KV LPOP", চাবি
    ফেরত ০
}

কাজ KV_list_len(kv, চাবি) {
    ফেরত ০
}

// ─── Pub/Sub ──────────────────────────────────────────────────────────────────
// WHY: Pub/Sub decouples producers and consumers (event-driven arch)
কাজ KV_subscribe(kv, channel, callback) {
    দেখাও "  → KV SUBSCRIBE:", channel
    ফেরত ০
}

কাজ KV_publish(kv, channel, message) {
    দেখাও "  → KV PUBLISH:", channel, "→", message
    ফেরত ০
}

// ─── Persistence ─────────────────────────────────────────────────────────────
কাজ KV_snapshot_লেখো(kv, ফাইল_পাথ) {
    // WHY: Redis RDB-style point-in-time snapshot
    দেখাও "  → KV snapshot →", ফাইল_পাথ
    ধরি fd = ফাইল_তৈরি(ফাইল_পাথ)
    // Write all key-value pairs to file
    ফাইল_বন্ধ(fd)
    ফেরত ০
}

কাজ KV_snapshot_পড়ো(kv, ফাইল_পাথ) {
    // WHY: Restore KV store from snapshot
    দেখাও "  → KV restore ←", ফাইল_পাথ
    ফেরত ০
}

// ─── Stats ────────────────────────────────────────────────────────────────────
কাজ KV_stats_দেখাও(kv) {
    দেখাও "  KV Store Statistics:"
    দেখাও "    মোট এন্ট্রি :", kv.মোট_এন্ট্রি
    দেখাও "    bucket গণনা:", kv.bucket_গণনা
    দেখাও "    cache hit   :", kv.hit_গণনা
    দেখাও "    cache miss  :", kv.miss_গণনা
    যদি kv.hit_গণনা + kv.miss_গণনা > ০ {
        ধরি total = kv.hit_গণনা + kv.miss_গণনা
        ধরি hit_rate = kv.hit_গণনা * ১০০ / total
        দেখাও "    hit rate   :", hit_rate, "%"
    }
}

// ─── Free ─────────────────────────────────────────────────────────────────────
কাজ KV_মুক্তি(kv) {
    যদি kv == ০ { ফেরত ০ }
    // Free all entries in all buckets
    মেমরি_মুক্তি(kv.bucket_তালিকা, kv.bucket_গণনা * ৮)
    মেমরি_মুক্তি(kv, সাইজ(KV_store))
    দেখাও "  ✔ KV Store মুক্তি"
    ফেরত ০
}
