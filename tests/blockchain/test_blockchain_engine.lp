@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — LAYER-1 BLOCKCHAIN ENGINE TEST SUITE
@! File: tests/blockchain/test_blockchain_engine.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/crypto/sha256"
import "universe/blockchain/mpt"
import "universe/blockchain/vm"
import "universe/blockchain/blockchain"

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println("  [FAIL] Assertion failed: " + msg)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@fn assert_eq_str(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected '" + expected + "', got '" + actual + "'")
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("🧬 MAYA LAYER-1 SOVEREIGN BLOCKCHAIN (MAYANET) TEST SUITE 🧬")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: Merkle Patricia State Trie & Root Hashes
  println("▶ Section 1: Merkle Patricia State Trie & Cryptographic Roots...")
  total_tests = total_tests + 1
  trie = state_trie_new()
  acc_satoshi = account_state_new("0x1111", 1000)
  trie = state_trie_put_account(trie, acc_satoshi)
  ok1 = assert_eq_int(trie.total_accounts, 1, "Account inserted into state trie")
  ok2 = assert_true(str_len(trie.root_hash) == 64, "State root is valid 64-char SHA-256 hash")
  fetched = state_trie_get_account(trie, "0x1111")
  ok3 = assert_eq_int(fetched.balance, 1000, "Fetched account balance matches 1000 MAYA")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] State Trie account management & Merkle root calculation verified")
  @end

  @! SECTION 2: Genesis Block & Proof-of-Work (PoW) Mining
  println("▶ Section 2: Genesis Block & Proof-of-Work (PoW) Mining Engine...")
  total_tests = total_tests + 1
  chain = maya_blockchain_new("0xGENESIS_MINER", 500)
  ok1 = assert_eq_int(chain.chain.len(), 1, "Genesis block created in ledger")
  gen_b = chain.chain[0]
  ok2 = assert_true(str_starts_with(gen_b.block_hash, "0"), "Block satisfies difficulty target leading zero")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Genesis block creation & Hashcash PoW engine verified")
  @end

  @! SECTION 3: Transaction Signing & Block Addition
  println("▶ Section 3: Transaction Execution & State Transition...")
  total_tests = total_tests + 1
  tx1 = maya_tx_new("0xGENESIS_MINER", "0xALICE", 150, 0, 21000, 1, "")
  applied = maya_blockchain_apply_tx(chain, tx1)
  ok1 = assert_eq_int(applied, 1, "Transaction successfully applied to state")
  
  sender = state_trie_get_account(chain.state_trie, "0xGENESIS_MINER")
  recv = state_trie_get_account(chain.state_trie, "0xALICE")
  ok2 = assert_eq_int(sender.balance, 350, "Sender balance correctly decremented (500 - 150 = 350)")
  ok3 = assert_eq_int(recv.balance, 150, "Receiver balance correctly credited (+150)")

  b1 = maya_blockchain_mine_pending(chain, "0xBOB_MINER")
  ok4 = assert_eq_int(chain.chain.len(), 2, "Chain length updated to 2 blocks")
  ok5 = assert_eq_str(b1.prev_hash, gen_b.block_hash, "Block 1 links cryptographically to Genesis block hash")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Transaction state transitions & block chaining verified")
  @end

  @! SECTION 4: MayaVM Smart Contract Execution & Gas Metering
  println("▶ Section 4: MayaVM Smart Contract Opcode Execution & Gas Metering...")
  total_tests = total_tests + 1
  vm_ctx = vm_context_new("0xALICE", "0xCONTRACT", 0, 100000, 1)
  vm_st = vm_state_new()

  @! Smart Contract Bytecode: PUSH "counter", PUSH 10, PUSH 20, ADD, SSTORE, PUSH "counter", SLOAD, RETURN
  contract_ops = [
    "PUSH", "counter",
    "PUSH", "10",
    "PUSH", "20",
    "ADD",
    "SSTORE",
    "PUSH", "counter",
    "SLOAD",
    "RETURN"
  ]
  vm_res = vm_execute_bytecode(vm_ctx, vm_st, contract_ops)
  ok1 = assert_eq_int(vm_res.success, 1, "MayaVM execution succeeded")
  ok2 = assert_eq_str(vm_res.return_value, "30", "Smart contract computed and returned (10 + 20 = 30)")
  ok3 = assert_true(vm_res.gas_used > 21000, "Deterministic gas metering tracked execution cost")
  ok4 = assert_true(str_len(vm_res.storage_root) == 64, "Contract storage trie root hash generated")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] MayaVM stack execution, storage slots & gas metering verified")
  @end

  println("=================================================================")
  println("📊 MAYANET BLOCKCHAIN TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 4 MAYANET BLOCKCHAIN TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME MAYANET BLOCKCHAIN TESTS FAILED")
    return 1
  @end
@end
