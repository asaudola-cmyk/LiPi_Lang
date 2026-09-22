@! ============================================================================
@! MAYA UNIVERSE CRYPTO — MERKLE TREE & BLOCKCHAIN LEDGER (universe/crypto/merkle.maya)
@! 100% Written in Pure Maya Language — Zero OpenSSL / Rust Dependencies
@! Features: Cryptographic Merkle Trees, Inclusion Proofs, UTXO Ledger
@! ============================================================================

import "universe/core/crypto"
import "universe/core/collections"
import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. Merkle Tree Construction
@! ----------------------------------------------------------------------------
@fn merkle_hash_pair(left_hex, right_hex)
  combined = []
  i = 0
  @while i < left_hex.len()
    combined = combined.push(left_hex[i])
    i = i + 1
  @end
  i = 0
  @while i < right_hex.len()
    combined = combined.push(right_hex[i])
    i = i + 1
  @end
  
  return sha256_hex(combined)
@end

@fn merkle_compute_root(leaf_hashes)
  @if leaf_hashes.len() == 0
    return "0000000000000000000000000000000000000000000000000000000000000000"
  @end
  @if leaf_hashes.len() == 1
    return leaf_hashes[0]
  @end
  
  current_level = leaf_hashes
  @while current_level.len() > 1
    next_level = []
    i = 0
    @while i < current_level.len()
      left = current_level[i]
      right = left
      @if i + 1 < current_level.len()
        right = current_level[i + 1]
      @end
      parent = merkle_hash_pair(left, right)
      next_level = next_level.push(parent)
      i = i + 2
    @end
    current_level = next_level
  @end
  
  return current_level[0]
@end

@! ----------------------------------------------------------------------------
@! 2. Merkle Proof Verification
@! ----------------------------------------------------------------------------
@fn merkle_verify_proof(leaf_hash, proof_elements, root_hash)
  current = leaf_hash
  @for el in proof_elements
    @if el.position == "left"
      current = merkle_hash_pair(el.hash, current)
    @else
      current = merkle_hash_pair(current, el.hash)
    @end
  @end
  
  return current == root_hash
@end

@! ----------------------------------------------------------------------------
@! 3. Layer 1 UTXO Block Structure
@! ----------------------------------------------------------------------------
@fn block_new(index, prev_hash, transactions, nonce)
  tx_hashes = []
  @for tx in transactions
    tx_hashes = tx_hashes.push(sha256_hex(tx))
  @end
  
  merkle_root = merkle_compute_root(tx_hashes)
  
  header_str = index.to_str() + prev_hash + merkle_root + nonce.to_str()
  header_bytes = []
  i = 0
  @while i < header_str.len()
    header_bytes = header_bytes.push(header_str[i])
    i = i + 1
  @end
  
  block_hash = sha256_hex(header_bytes)
  
  return {
    index: index,
    prev_hash: prev_hash,
    merkle_root: merkle_root,
    transactions: transactions,
    nonce: nonce,
    hash: block_hash
  }
@end
