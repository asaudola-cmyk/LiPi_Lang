// ==============================================================================
// FLAGSHIP 01: SOVEREIGN KAVACH VAULT (সর্বভৌম কবচ)
// Compile & verify under hardware crown + strict ownership proof:
//   ./bin/lipc examples/flagship/01_sovereign_kavach_vault.lp /tmp/vault --kavach
// ==============================================================================
// Demonstrates:
//   1. Sovereign Hardware Crown (`silicon_*` / `সিলিকন_*`): ONLY crowned functions
//      may invoke raw `syscall` and `mem_write` under `--kavach`.
//   2. Inter-Procedural Move Proof: `allocate_sealed_vault` moves ownership of a
//      heap allocation to `main` via `return`, verified and freed cleanly with 0 leak.

include "utso/io"
include "utso/string"

// Crowned low-level silicon primitive: permitted to touch raw kernel syscalls and memory slots.
fn silicon_hardware_stamp ptr tag_val
    pid = syscall(39, 0, 0, 0, 0, 0, 0)
    seal = (tag_val * 2654435761) ^ (pid & 65535)
    mem_write(ptr, 0, seal)
    mem_write(ptr, 8, tag_val)
    return seal

// Bilingual crowned helper: reads kernel monotonic counter & returns folded hardware entropy word.
কাজ সিলিকন_এন্ট্রপি মান
    টিকিট = syscall(39, 0, 0, 0, 0, 0, 0)
    ফেরত (মান ^ (টিকিট * 31)) & 1048575

// Allocates a 64-byte hardware vault slot, invokes crowned sealing, and transfers ownership via `return`.
fn create_sealed_vault tag_val
    vault = alloc(64)
    if vault == 0
        return 0
    silicon_hardware_stamp(vault, tag_val)
    return vault

fn main
    mark = arena_mark()
    // Prime one block first so arena free-list caches cleanly.
    primer = alloc(64)
    free(primer)
    base_bytes = arena_allocated()

    entropy = সিলিকন_এন্ট্রপি(777)
    slot = create_sealed_vault(entropy)
    if slot == 0
        say "[ERR] Vault allocation failed"
        return 1

    sealed_sig = mem_read(slot, 0)
    stored_tag = mem_read(slot, 8)
    free(slot)

    delta_bytes = arena_allocated() - base_bytes
    arena_reset(mark)

    say "👑 Sovereign Kavach Vault Active (সর্বভৌম কবচ)"
    say "Entropy Seed : " + str(stored_tag)
    say "Hardware Seal: " + str(sealed_sig)
    say "Heap Delta   : " + str(delta_bytes) + " bytes (Ownership moved & freed cleanly)"
    if stored_tag != entropy or delta_bytes != 0
        return 1
    say "✅ KAVACH_VAULT_VERIFIED"
    return 0

main()
