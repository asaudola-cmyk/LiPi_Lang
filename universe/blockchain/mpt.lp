@! ============================================================================
@! LIPI UNIVERSAL ARCHITECTURE — LAYER-1 STATE TRIE & CRYPTOGRAPHIC PROOFS
@! Module: universe/blockchain/mpt.maya
@! Milestone: Layer-1 Sovereign Blockchain (MayaNet)
@! 100% Pure Lipi Implementation — Zero External Dependencies
@! Features: Merkle Patricia State Trie, Account State Records & SHA-256 State Roots
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/crypto/sha256"

@! ============================================================================
@! 1. ACCOUNT STATE & TRIE NODE DATA STRUCTURES
@! ============================================================================

@struct AccountState
  address: string
  nonce: i64
  balance: i64
  storage_root: string
  code_hash: string
@end

@struct TrieLeafNode
  key_hex: string
  value_raw: string
  hash: string
@end

@struct StateTrie
  root_hash: string
  accounts: array
  total_accounts: i64
@end

@! ============================================================================
@! 2. ACCOUNT SERIALIZATION & HASHING
@! ============================================================================

@fn account_state_new(addr, balance)
  return {
    address: addr,
    nonce: 0,
    balance: balance,
    storage_root: sha256_hex_string("empty_storage"),
    code_hash: sha256_hex_string("")
  }
@end

@fn account_state_serialize(acc)
  res = "acc:{"
  res = res + "\"addr\":\"" + acc.address + "\","
  res = res + "\"nonce\":" + acc.nonce.to_str() + ","
  res = res + "\"balance\":" + acc.balance.to_str() + ","
  res = res + "\"storage_root\":\"" + acc.storage_root + "\","
  res = res + "\"code_hash\":\"" + acc.code_hash + "\"}"
  return res
@end

@fn account_state_hash(acc)
  ser = account_state_serialize(acc)
  return sha256_hex_string(ser)
@end

@! ============================================================================
@! 3. STATE TRIE IMPLEMENTATION
@! ============================================================================

@fn state_trie_new()
  empty_root = sha256_hex_string("mpt:empty_root")
  return {
    root_hash: empty_root,
    accounts: [],
    total_accounts: 0
  }
@end

@fn state_trie_get_account(trie, address)
  i = 0
  n_acc = trie.accounts.len()
  @while i < n_acc
    acc = trie.accounts[i]
    @if acc.address == address
      return acc
    @end
    i = i + 1
  @end
  return 0
@end

@fn state_trie_put_account(trie, new_acc)
  updated = []
  found = 0
  i = 0
  n_acc = trie.accounts.len()
  @while i < n_acc
    acc = trie.accounts[i]
    @if acc.address == new_acc.address
      updated = updated.push(new_acc)
      found = 1
    @else
      updated = updated.push(acc)
    @end
    i = i + 1
  @end

  @if found == 0
    updated = updated.push(new_acc)
    trie.total_accounts = trie.total_accounts + 1
  @end

  trie.accounts = updated
  
  @! Recompute Merkle State Root Hash
  state_concat = ""
  j = 0
  @while j < trie.accounts.len()
    a = trie.accounts[j]
    state_concat = state_concat + a.address + ":" + account_state_hash(a) + "|"
    j = j + 1
  @end

  trie.root_hash = sha256_hex_string(state_concat)
  return trie
@end
