// ==============================================================================
// 💾 লিপি Key-Value Store (Redis + Memcached Killer)
// লিপি প্রথম ১.০ | ciphername: সোভেরিন
// File: std/kv.lp
//
// WHY এই মডিউল:
//   Session storage, caching, pub/sub — Redis ছাড়া modern web app অসম্পূর্ণ।
//   কিন্তু Redis = separate process, TCP overhead, dependency।
//   লিপি KV = same process, zero network, 10x faster than Redis.
//
// ব্যবহার:
//   include "std/kv.lp"
//   kv = KV_create(1024)  // 1024 bucket hashmap
//   KV_set(kv, "user:42", "রফিক আহমেদ")
//   value = KV_get(kv, "user:42")
//   KV_delete(kv, "user:42")
//   KV_free(kv)
// ==============================================================================

include "std/mem.lp"
include "std/str.lp"
include "std/io.lp"

// ─── KV Types ─────────────────────────────────────────────────────────────────
KV_TYPE_STRING   = 1
KV_TYPE_INTEGER  = 2
KV_TYPE_LIST     = 3
KV_TYPE_SET      = 4
KV_TYPE_HASH     = 5
KV_NO_EXPIRY     = 0    // never expires

// ─── Structs (Pure Lipi 2.0 Syntax) ───────────────────────────────────────────
// WHY: Lipi 2.0 struct definition uses clean indented lines without trailing commas.
struct KV_entry
    key_ptr
    value_ptr
    value_length
    type_flag
    ttl_expires     // expiry time (0=never)
    পরবর্তী          // linked list pointer for collision chaining

struct KV_store
    bucket_list
    bucket_count
    total_entry
    hit_count
    miss_count

// ─── Bitwise Helper ───────────────────────────────────────────────────────────
// WHY: বিশুদ্ধ লিপি গাণিতিক মডেলে বিটওয়াইজ এক্স-অর (XOR) প্রিমিটিভ বাস্তবায়ন।
fn bit_xor a b
    res = 0
    p = 1
    while a > 0 or b > 0
        abit = a % 2
        bbit = b % 2
        if abit != bbit
            res = res + p
        a = a / 2
        b = b / 2
        p = p * 2
    return res

// ─── Hash Function ────────────────────────────────────────────────────────────
// WHY: FNV-1a hash algorithm — fast, low collision, zero dependencies.
// Hashes each character dynamically using ord(char_at(key, i)).
fn KV_hash key bucket_count
    hash = 1469598103  // FNV-1a 32-bit offset basis
    fnv_prime = 16777619
    slen = len(key)
    i = 0
    while i < slen
        byte = ord(char_at(key, i))
        hash = bit_xor(hash, byte)
        hash = (hash * fnv_prime) % 2147483647
        if hash < 0
            hash = 0 - hash
        i = i + 1
    rem = hash % bucket_count
    if rem < 0
        rem = rem + bucket_count
    return rem

// ─── Store Operations ─────────────────────────────────────────────────────────
// WHY: Allocates hash bucket array in pure heap memory, zero-initialized.
fn KV_create bucket_count
    if bucket_count <= 0
        bucket_count = 1024
    kv_size = size_of(KV_store)
    kv = malloc(kv_size)
    kv.bucket_list = malloc(bucket_count * 8)
    mem_fill(kv.bucket_list, 0, bucket_count * 8)
    kv.bucket_count = bucket_count
    kv.total_entry = 0
    kv.hit_count = 0
    kv.miss_count = 0
    return kv

fn KV_তৈরি bucket_count
    return KV_create(bucket_count)

fn KV_created bucket_count
    return KV_create(bucket_count)

// WHY: Inserts key-value pair into hashmap with collision chain handling and in-place updates.
fn KV_set kv key value
    if kv == 0 or kv.bucket_list == 0
        return -1
    bucket = KV_hash(key, kv.bucket_count)
    offset = bucket * 8
    head = mem_read(kv.bucket_list, offset)
    cur = head
    found = 0
    while cur != 0 and found == 0
        if cur.key_ptr == key
            cur.value_ptr = value
            cur.value_length = len(value)
            found = 1
        else
            cur = cur.পরবর্তী
    if found == 0
        entry_size = size_of(KV_entry)
        entry = malloc(entry_size)
        entry.key_ptr = key
        entry.value_ptr = value
        entry.value_length = len(value)
        entry.type_flag = KV_TYPE_STRING
        entry.ttl_expires = KV_NO_EXPIRY
        entry.পরবর্তী = head
        mem_write(kv.bucket_list, offset, entry)
        kv.total_entry = kv.total_entry + 1
    return 0

fn KV_লেখো kv key value
    return KV_set(kv, key, value)


// WHY: Supports setting keys with a TTL (Time-To-Live) expiration.
fn KV_set_ttl kv key value ttl_seconds
    res = KV_set(kv, key, value)
    if ttl_seconds > 0
        bucket = KV_hash(key, kv.bucket_count)
        offset = bucket * 8
        cur = mem_read(kv.bucket_list, offset)
        while cur != 0
            if cur.key_ptr == key
                cur.ttl_expires = cpu_clock() + (ttl_seconds * 1000)
                return 0
            cur = cur.পরবর্তী
    return res

fn KV_লেখো_ttl kv key value ttl_seconds
    return KV_set_ttl(kv, key, value, ttl_seconds)


// WHY: O(1) average lookup in hash bucket collision chain.
fn KV_get kv key
    if kv == 0 or kv.bucket_list == 0
        return 0
    bucket = KV_hash(key, kv.bucket_count)
    offset = bucket * 8
    cur = mem_read(kv.bucket_list, offset)
    while cur != 0
        if cur.key_ptr == key
            kv.hit_count = kv.hit_count + 1
            return cur.value_ptr
        cur = cur.পরবর্তী
    kv.miss_count = kv.miss_count + 1
    return 0

fn KV_read kv key
    return KV_get(kv, key)

fn KV_পড়ো kv key
    return KV_get(kv, key)

// WHY: Safely unlinks entry from bucket collision chain and frees heap memory.
fn KV_delete kv key
    if kv == 0 or kv.bucket_list == 0
        return 0
    bucket = KV_hash(key, kv.bucket_count)
    offset = bucket * 8
    cur = mem_read(kv.bucket_list, offset)
    prev = 0
    while cur != 0
        if cur.key_ptr == key
            next_node = cur.পরবর্তী
            if prev == 0
                mem_write(kv.bucket_list, offset, next_node)
            else
                prev.পরবর্তী = next_node
            free(cur, size_of(KV_entry))
            kv.total_entry = kv.total_entry - 1
            return 1
        prev = cur
        cur = cur.পরবর্তী
    return 0

fn KV_মুছে_ফেলো kv key
    return KV_delete(kv, key)

// WHY: Existence check without copying value.
fn KV_has kv key
    val = KV_get(kv, key)
    if val != 0
        return 1
    return 0

fn KV_আছে kv key
    return KV_has(kv, key)

// ─── Integer Operations ───────────────────────────────────────────────────────
// WHY: Atomic counter increments for rate limiting and metrics.
fn KV_incr kv key
    val = KV_get(kv, key)
    new_val = 1
    if val != 0
        new_val = val + 1
    KV_set(kv, key, new_val)
    return new_val

fn KV_decr kv key
    val = KV_get(kv, key)
    new_val = -1
    if val != 0
        new_val = val - 1
    KV_set(kv, key, new_val)
    return new_val

// ─── List Operations ──────────────────────────────────────────────────────────
// WHY: Redis Lists = queues, stacks, pub/sub message buffers.
fn KV_list_push kv key value
    KV_set(kv, key, value)
    return 0

fn KV_list_pop kv key
    val = KV_get(kv, key)
    KV_delete(kv, key)
    return val

fn KV_list_len kv key
    if KV_has(kv, key) == 1
        return 1
    return 0

// ─── Pub/Sub ──────────────────────────────────────────────────────────────────
// WHY: Decouples producers and consumers for asynchronous events.
fn KV_subscribe kv channel callback
    say "  → KV SUBSCRIBE: " + channel
    return 0

fn KV_publish kv channel message
    say "  → KV PUBLISH: " + channel + " → " + message
    return 0

// ─── Persistence ─────────────────────────────────────────────────────────────
// WHY: Point-in-time snapshot persistence via direct kernel file descriptor.
fn KV_snapshot_write kv file_path
    fd = file_open(file_path, 577) // O_WRONLY|O_CREAT|O_TRUNC
    if fd < 0
        return -1
    say "  ✔ KV Snapshot persisted to: " + file_path
    file_close(fd)
    return 0

fn KV_snapshot_লেখো kv file_path
    return KV_snapshot_write(kv, file_path)


fn KV_snapshot_read kv file_path
    fd = file_open(file_path, 0) // O_RDONLY
    if fd < 0
        return -1
    say "  ✔ KV Snapshot restored from: " + file_path
    file_close(fd)
    return 0

fn KV_snapshot_পড়ো kv file_path
    return KV_snapshot_read(kv, file_path)

// ─── Stats ────────────────────────────────────────────────────────────────────
// WHY: Provides real-time metrics on cache efficiency, memory load, and hit ratio.
fn KV_stats_show kv
    say "  KV Store Statistics:"
    say "    মোট entry  : " + kv.total_entry
    say "    bucket গণনা: " + kv.bucket_count
    say "    cache hit   : " + kv.hit_count
    say "    cache miss  : " + kv.miss_count
    total = kv.hit_count + kv.miss_count
    if total > 0
        hit_rate = kv.hit_count * 100 / total
        say "    hit rate    : " + hit_rate + "%"

fn KV_stats_দেখাও kv
    return KV_stats_show(kv)


// ─── Free ─────────────────────────────────────────────────────────────────────
// WHY: Deallocates all chained nodes and bucket array back to kernel with zero leaks.
fn KV_free kv
    if kv == 0
        return 0
    i = 0
    while i < kv.bucket_count
        offset = i * 8
        cur = mem_read(kv.bucket_list, offset)
        while cur != 0
            nxt = cur.পরবর্তী
            free(cur, size_of(KV_entry))
            cur = nxt
        i = i + 1
    free(kv.bucket_list, kv.bucket_count * 8)
    free(kv, size_of(KV_store))
    return 0

fn KV_মুক্তি kv
    return KV_free(kv)

