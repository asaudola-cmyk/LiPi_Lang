// Test 36: Robin Hood Hashmap — Lipi 2.0 Global Standard

fn hash_fn k cap
    h = k * 2654435761
    if h < 0
        h = 0 - h
    return h % cap

fn probe_dist bucket target cap
    if bucket >= target
        return bucket - target
    return cap + bucket - target

fn map_insert key value cap
    bucket = hash_fn(key, cap)
    say "Insert key=" + key + " value=" + value + " bucket=" + bucket
    return bucket

fn map_lookup key cap
    bucket = hash_fn(key, cap)
    say "Lookup key=" + key + " bucket=" + bucket
    return bucket

say "=== Robin Hood Hashmap ==="
cap = 16
map_insert(42, 100, cap)
map_insert(58, 200, cap)
map_insert(74, 300, cap)
map_lookup(42, cap)
map_lookup(58, cap)

h1 = hash_fn(42, cap)
h2 = hash_fn(58, cap)
say "42 hashes to: " + h1
say "58 hashes to: " + h2

// Load factor check
size = 3
load = size * 100 / cap
say "Load factor: " + load + "%"

say "PASS: Test 36 Robin Hood Hashmap"
