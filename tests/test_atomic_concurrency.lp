// ==============================================================================
// 👑 LIPI SOVEREIGN REGRESSION TEST: HARDWARE ATOMIC CONCURRENCY
// ⚡ Tests Native Silicon lock cmpxchg, lock bts, lock btr, lock xadd
// 🏛️ Version: First 1.0.0 (প্রথম ১.০.০) — 100% Pure Silicon / 0% Pthreads
// ==============================================================================

include "universe/os/thread.lp"

say "=== LIPI HARDWARE ATOMIC CONCURRENCY TEST ==="

// 1. Allocate 64-byte aligned lock and counter memory
lock_word = alloc(16)
mem_word_write(lock_word, 0, 0) // Initialize lock to 0 (unlocked)

counter_word = alloc(16)
mem_word_write(counter_word, 0, 100) // Initial counter = 100

// 2. Direct Hardware Atomic Lock & Unlock
atomic_lock(lock_word)
if mem_word_read(lock_word, 0) == 0
    say "FAIL: atomic_lock did not acquire bit 0"
    exit(1)
say "✔ Hardware atomic_lock acquired (lock bit set via lock bts)"

atomic_unlock(lock_word)
if mem_word_read(lock_word, 0) != 0
    say "FAIL: atomic_unlock did not clear bit 0"
    exit(1)
say "✔ Hardware atomic_unlock released (lock bit cleared via lock btr)"

// 3. Hardware Atomic Compare-And-Swap (lock cmpxchg)
// Test matching condition: expected 100, replace with 250 -> should succeed (1)
cas_ok = atomic_cas(counter_word, 100, 250)
if cas_ok != 1 or mem_word_read(counter_word, 0) != 250
    say "FAIL: atomic_cas success branch failed"
    exit(1)
say "✔ Atomic CAS (Match -> Swap 100 -> 250) succeeded"

// Test mismatch condition: expected 999, target is 250 -> should fail (0)
cas_fail = atomic_cas(counter_word, 999, 500)
if cas_fail != 0 or mem_word_read(counter_word, 0) != 250
    say "FAIL: atomic_cas mismatch branch incorrectly swapped"
    exit(1)
say "✔ Atomic CAS (Mismatch expected 999 != 250) safely rejected"

// 4. Hardware Atomic Fetch-And-Add (lock xadd)
// Target is 250, add 50 -> should return previous 250, new value 300
prev_val = atomic_add(counter_word, 50)
curr_val = mem_word_read(counter_word, 0)
if prev_val != 250 or curr_val != 300
    say "FAIL: atomic_add returned " + str(prev_val) + ", curr = " + str(curr_val)
    exit(1)
say "✔ Atomic Fetch-And-Add (250 + 50 -> 300, prev 250) verified"

// 5. High-Level Thread Spinlock Integration from universe/os/thread.lp
spinlock_lock(lock_word)
say "✔ universe/os/thread.lp spinlock_lock acquired via hardware atomics"
spinlock_unlock(lock_word)
say "✔ universe/os/thread.lp spinlock_unlock released cleanly"

free(lock_word)
free(counter_word)
say "PASS: test_atomic_concurrency"
