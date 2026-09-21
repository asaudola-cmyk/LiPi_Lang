// ==============================================================================
// 👑 LIPI SOVEREIGN BLOCKCHAIN SUITE: tests/test_blockchain_evm.lp
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Merkle Patricia Trie & EVM Engine Test
// ==============================================================================

import "universe/blockchain/mpt"
import "universe/blockchain/vm"

@fn main()
    println("==================================================================")
    println("👑 Testing Lipi Sovereign Blockchain Engine (MPT & LipiVM)")
    println("==================================================================")

    // ── Test 1: Merkle Patricia State Trie Account Insertion ──────────────────
    println("[1/5] Testing Merkle State Trie Insertion & Root Hashing...")
    trie = state_trie_new()
    empty_root = trie.root_hash

    acc1 = account_state_new("0x1111222233334444555566667777888899990000", 5000000)
    trie = state_trie_put_account(trie, acc1)

    if trie.total_accounts != 1
        println("❌ Expected 1 account in trie, got " + trie.total_accounts)
        return 1
    end
    if trie.root_hash == empty_root
        println("❌ State root did not update after account insertion!")
        return 1
    end
    println("  ✔ Account inserted; State Root dynamically computed: " + trie.root_hash)

    // ── Test 2: Account Retrieval & Balance Query ─────────────────────────────
    println("[2/5] Testing Account State Retrieval...")
    fetched = state_trie_get_account(trie, "0x1111222233334444555566667777888899990000")
    if fetched == 0
        println("❌ Failed to retrieve account from State Trie!")
        return 1
    end
    if fetched.balance != 5000000
        println("❌ Account balance mismatch: expected 5000000, got " + fetched.balance)
        return 1
    end
    println("  ✔ Account state retrieved: Balance = " + fetched.balance + " wei")

    // ── Test 3: LipiVM Arithmetic Bytecode Execution ─────────────────────────
    println("[3/5] Testing LipiVM Stack Arithmetic (PUSH, DUP, ADD, MUL, SUB)...")
    ctx = vm_context_new("0xCaller", "0xContract", 0, 100000, 1)
    state = vm_state_new()

    // Program: PUSH 10, DUP (10, 10), PUSH 5 (10, 10, 5), ADD (10, 15), MUL (150), PUSH 20, SUB (130), RETURN
    ops = ["PUSH", "10", "DUP", "PUSH", "5", "ADD", "MUL", "PUSH", "20", "SUB", "RETURN"]
    res = vm_execute_bytecode(ctx, state, ops)

    if res.success != 1
        println("❌ VM execution failed!")
        return 1
    end
    if res.return_value != "130"
        println("❌ Arithmetic calculation mismatch: expected 130, got " + res.return_value)
        return 1
    end
    println("  ✔ Arithmetic verified: ((10 * (10 + 5)) - 20) = " + res.return_value)

    // ── Test 4: Persistent Contract Storage (SSTORE & SLOAD) ──────────────────
    println("[4/5] Testing Persistent Contract Storage (SSTORE and SLOAD)...")
    ctx2 = vm_context_new("0xCaller", "0xContract", 0, 100000, 1)
    state2 = vm_state_new()

    // Program: PUSH "owner", PUSH "0xSovereignAdmin", SSTORE, PUSH "owner", SLOAD, RETURN
    ops2 = ["PUSH", "owner", "PUSH", "0xSovereignAdmin", "SSTORE", "PUSH", "owner", "SLOAD", "RETURN"]
    res2 = vm_execute_bytecode(ctx2, state2, ops2)

    if res2.success != 1
        println("❌ Storage contract execution failed!")
        return 1
    end
    if res2.return_value != "0xSovereignAdmin"
        println("❌ Storage value mismatch: expected 0xSovereignAdmin, got " + res2.return_value)
        return 1
    end
    println("  ✔ Storage verified: owner -> " + res2.return_value + " (Storage Root: " + res2.storage_root + ")")

    // ── Test 5: Out of Gas Safety Guard ───────────────────────────────────────
    println("[5/5] Testing VM Gas Metering & Out-of-Gas Guard...")
    // SSTORE costs 5000 gas, but we only supply 22000 (base is 21000, remaining is 1000 < 5000)
    ctx3 = vm_context_new("0xCaller", "0xContract", 0, 22000, 1)
    state3 = vm_state_new()
    ops3 = ["PUSH", "key", "PUSH", "val", "SSTORE"]
    res3 = vm_execute_bytecode(ctx3, state3, ops3)

    if res3.success != 0
        println("❌ VM should have reverted due to insufficient gas!")
        return 1
    end
    println("  ✔ Out of Gas revert triggered cleanly: gas_used=" + res3.gas_used + " (Limit was 22000)")

    println("==================================================================")
    println("PASS: Lipi Sovereign Blockchain Engine 100% Verified!")
    println("==================================================================")
    return 0
@end
