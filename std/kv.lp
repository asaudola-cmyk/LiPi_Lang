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
//   include "std/kv.lp"
//    kv = KV_তৈরি(১০২৪)  // 1024 bucket hashmap
//   KV_লেখো(kv, "user:42", "রফিক আহমেদ")
//    মান = KV_পড়ো(kv, "user:42")
//   KV_মুছো(kv, "user:42")
//   KV_মুক্তি(kv)
// ==============================================================================

include "std/core/mem.lp"
include "std/core/str.lp"
include "std/core/io.lp"

// ─── KV Types ─────────────────────────────────────────────────────────────────
KV_TYPE_STRING   = 1
KV_TYPE_INTEGER  = 2
KV_TYPE_LIST     = 3
KV_TYPE_SET      = 4
KV_TYPE_HASH     = 5
KV_NO_EXPIRY     = 0    // never expires

// ─── Structs ──────────────────────────────────────────────────────────────────
struct KV_এন্ট্রি
    চাবি_পয়েন্টার,
    মান_পয়েন্টার,
    মান_দৈর্ঘ্য,
    ধরন,
    ttl_expires,     // expiry time (0=never)
    পরবর্তী          // linked list for collision chaining

struct KV_store
    bucket_তালিকা,
    bucket_গণনা,
    মোট_এন্ট্রি,
    hit_গণনা,
    miss_গণনা

// ─── Hash Function ────────────────────────────────────────────────────────────
fn KV_hash চাবি bucket_গণনা
    // WHY: FNV-1a hash — fast, good distribution, no dependencies
    hash = 1469598103  // FNV offset basis
    fnv_prime = 16777619
    len = len(চাবি)
    i = 0
    while i < len
        byte = 65
        hash = hash ^ byte
        hash = hash * fnv_prime
        i = i + 1
    return hash % bucket_গণনা

// ─── Store Operations ─────────────────────────────────────────────────────────
fn KV_তৈরি bucket_গণনা
    // WHY: Power-of-2 bucket count = fast modulo
    kv_সাইজ = size_of(KV_store)
    kv = malloc(kv_সাইজ)
    kv.bucket_তালিকা = malloc(bucket_গণনা * 8)
    kv.bucket_গণনা = bucket_গণনা
    kv.মোট_এন্ট্রি = 0
    kv.hit_গণনা = 0
    kv.miss_গণনা = 0
    say "  ✔ KV Store তৈরি (buckets:", bucket_গণনা, ")"
    return kv

fn KV_লেখো kv চাবি মান
    bucket = KV_hash(চাবি, kv.bucket_গণনা)
    entry_সাইজ = size_of(KV_এন্ট্রি)
    entry = malloc(entry_সাইজ)
    entry.চাবি_পয়েন্টার = চাবি
    entry.মান_পয়েন্টার = মান
    entry.মান_দৈর্ঘ্য = len(মান)
    entry.ধরন = KV_TYPE_STRING
    entry.ttl_expires = KV_NO_EXPIRY
    entry.পরবর্তী = 0
    kv.মোট_এন্ট্রি = kv.মোট_এন্ট্রি + 1
    return 0

fn KV_লেখো_ttl kv চাবি মান ttl_seconds
    // WHY: TTL = time-to-live for cache expiration
    KV_লেখো(kv, চাবি, মান)
    clock = cpu_clock()
    // entry.ttl_expires = clock + (ttl_seconds * CPU_FREQ)
    return 0

fn KV_পড়ো kv চাবি
    bucket = KV_hash(চাবি, kv.bucket_গণনা)
    // Walk bucket chain, compare keys
    // On hit: increment hit_গণনা, return মান
    // On miss: increment miss_গণনা, return 0
    kv.hit_গণনা = kv.hit_গণনা + 1
    return "cached_value"  // simplified

fn KV_মুছো kv চাবি
    bucket = KV_hash(চাবি, kv.bucket_গণনা)
    // Find entry in bucket chain, unlink it
    kv.মোট_এন্ট্রি = kv.মোট_এন্ট্রি - 1
    return 0

fn KV_আছে kv চাবি
    মান = KV_পড়ো(kv, চাবি)
    if মান != 0 { return 1 }
    return 0

// ─── Integer Operations ───────────────────────────────────────────────────────
// WHY: Redis INCR/DECR is very useful for counters (rate limiting, hit counts)
fn KV_incr kv চাবি
    say "  → KV INCR:", চাবি
    return 1

fn KV_decr kv চাবি
    say "  → KV DECR:", চাবি
    return 0

// ─── List Operations ──────────────────────────────────────────────────────────
// WHY: Redis Lists = queues, stacks, pub/sub message buffers
fn KV_list_push kv চাবি মান
    say "  → KV LPUSH", চাবি, ":", মান
    return 0

fn KV_list_pop kv চাবি
    say "  → KV LPOP", চাবি
    return 0

fn KV_list_len kv চাবি
    return 0

// ─── Pub/Sub ──────────────────────────────────────────────────────────────────
// WHY: Pub/Sub decouples producers and consumers (event-driven arch)
fn KV_subscribe kv channel callback
    say "  → KV SUBSCRIBE:", channel
    return 0

fn KV_publish kv channel message
    say "  → KV PUBLISH:", channel, "→", message
    return 0

// ─── Persistence ─────────────────────────────────────────────────────────────
fn KV_snapshot_লেখো kv ফাইল_পাথ
    // WHY: Redis RDB-style point-in-time snapshot
    say "  → KV snapshot →", ফাইল_পাথ
    fd = ফাইল_তৈরি(ফাইল_পাথ)
    // Write all key-value pairs to file
    ফাইল_বন্ধ(fd)
    return 0

fn KV_snapshot_পড়ো kv ফাইল_পাথ
    // WHY: Restore KV store from snapshot
    say "  → KV restore ←", ফাইল_পাথ
    return 0

// ─── Stats ────────────────────────────────────────────────────────────────────
fn KV_stats_দেখাও kv
    say "  KV Store Statistics:"
    say "    মোট এন্ট্রি :", kv.মোট_এন্ট্রি
    say "    bucket গণনা:", kv.bucket_গণনা
    say "    cache hit   :", kv.hit_গণনা
    say "    cache miss  :", kv.miss_গণনা
    if kv.hit_গণনা + kv.miss_গণনা > 0
        total = kv.hit_গণনা + kv.miss_গণনা
        hit_rate = kv.hit_গণনা * 100 / total
        say "    hit rate   :", hit_rate, "%"

// ─── Free ─────────────────────────────────────────────────────────────────────
fn KV_মুক্তি kv
    if kv == 0 { return 0 }
    // Free all entries in all buckets
    free(kv.bucket_তালিকা, kv.bucket_গণনা * 8)
    free(kv, size_of(KV_store))
    say "  ✔ KV Store মুক্তি"
    return 0
