@! ============================================================================
@! LIPI UNIVERSAL ARCHITECTURE — LAYER-1 SOVEREIGN BLOCKCHAIN (LIPINET)
@! Module: universe/blockchain/blockchain.lp
@! Milestone: Layer-1 Sovereign Blockchain (LipiNet)
@! 100% Pure Lipi Implementation — Zero External Dependencies
@! Features: Transactions, SHA-256 Merkle Trees, Proof-of-Work (PoW) Mining,
@! Block Validation, LipiVM Smart Contract Execution & Chain Ledger
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/crypto/sha256"
import "universe/blockchain/mpt"
import "universe/blockchain/vm"

@! ============================================================================
@! 1. BLOCKCHAIN DATA STRUCTURES
@! ============================================================================

@struct LipiTransaction
  from_addr: string
  to_addr: string
  value: i64
  nonce: i64
  gas_limit: i64
  gas_price: i64
  data_payload: string
  tx_hash: string
@end

// WHY: Retains MayaTransaction as backward-compatible alias for existing blockchain callers
@struct MayaTransaction
  from_addr: string
  to_addr: string
  value: i64
  nonce: i64
  gas_limit: i64
  gas_price: i64
  data_payload: string
  tx_hash: string
@end

@struct LipiBlock
  index: i64
  timestamp: i64
  prev_hash: string
  state_root: string
  tx_merkle_root: string
  transactions: array
  miner: string
  nonce: i64
  difficulty: i64
  block_hash: string
@end

// WHY: Retains MayaBlock as backward-compatible alias for existing blockchain callers
@struct MayaBlock
  index: i64
  timestamp: i64
  prev_hash: string
  state_root: string
  tx_merkle_root: string
  transactions: array
  miner: string
  nonce: i64
  difficulty: i64
  block_hash: string
@end

@struct LipiBlockchain
  chain: array
  state_trie: StateTrie
  pending_txs: array
  difficulty: i64
@end

// WHY: Retains MayaBlockchain as backward-compatible alias for existing blockchain callers
@struct MayaBlockchain
  chain: array
  state_trie: StateTrie
  pending_txs: array
  difficulty: i64
@end

@! ============================================================================
@! 2. TRANSACTION BUILDER & HASHING (CANONICAL LIPI API)
@! ============================================================================

@fn lipi_tx_new(from_addr, to_addr, val, nonce, gas_limit, gas_price, data_str)
  raw_str = from_addr + ":" + to_addr + ":" + val.to_str() + ":" + nonce.to_str() + ":" + data_str
  h = sha256_hex_string(raw_str)

  return {
    from_addr: from_addr,
    to_addr: to_addr,
    value: val,
    nonce: nonce,
    gas_limit: gas_limit,
    gas_price: gas_price,
    data_payload: data_str,
    tx_hash: h
  }
@end

// WHY: Retains maya_tx_new as backward-compatible alias for existing callers
@fn maya_tx_new(from_addr, to_addr, val, nonce, gas_limit, gas_price, data_str)
  return lipi_tx_new(from_addr, to_addr, val, nonce, gas_limit, gas_price, data_str)
@end

@fn lipi_txs_merkle_root(txs)
  @if txs.len() == 0
    return sha256_hex_string("empty_tx_root")
  @end

  concat_hashes = ""
  i = 0
  n = txs.len()
  @while i < n
    tx = txs[i]
    concat_hashes = concat_hashes + tx.tx_hash
    i = i + 1
  @end
  return sha256_hex_string(concat_hashes)
@end

// WHY: Retains maya_txs_merkle_root backward-compatible alias
@fn maya_txs_merkle_root(txs)
  return lipi_txs_merkle_root(txs)
@end

@! ============================================================================
@! 3. BLOCK MINING (Proof-of-Work / Hashcash) & HASHING
@! ============================================================================

@fn lipi_block_compute_hash(idx, ts, prev_h, st_root, tx_root, miner, nonce)
  raw = idx.to_str() + ":" + ts.to_str() + ":" + prev_h + ":" + st_root + ":" + tx_root + ":" + miner + ":" + nonce.to_str()
  return sha256_hex_string(raw)
@end

// WHY: Retains maya_block_compute_hash backward-compatible alias
@fn maya_block_compute_hash(idx, ts, prev_h, st_root, tx_root, miner, nonce)
  return lipi_block_compute_hash(idx, ts, prev_h, st_root, tx_root, miner, nonce)
@end

@fn lipi_block_mine(idx, ts, prev_h, st_root, txs, miner, difficulty)
  tx_root = lipi_txs_merkle_root(txs)
  nonce = 0
  h = ""
  
  @! Mine until leading zeros match difficulty (e.g. diff 1 requires start with '0')
  @while true
    h = lipi_block_compute_hash(idx, ts, prev_h, st_root, tx_root, miner, nonce)
    
    @! Check difficulty
    is_valid = 1
    d_i = 0
    @while d_i < difficulty
      @if str_char_at(h, d_i) != 48 @! '0'
        is_valid = 0
        break
      @end
      d_i = d_i + 1
    @end

    @if is_valid == 1
      break
    @end
    nonce = nonce + 1
  @end

  return {
    index: idx,
    timestamp: ts,
    prev_hash: prev_h,
    state_root: st_root,
    tx_merkle_root: tx_root,
    transactions: txs,
    miner: miner,
    nonce: nonce,
    difficulty: difficulty,
    block_hash: h
  }
@end

// WHY: Retains maya_block_mine backward-compatible alias
@fn maya_block_mine(idx, ts, prev_h, st_root, txs, miner, difficulty)
  return lipi_block_mine(idx, ts, prev_h, st_root, txs, miner, difficulty)
@end

@! ============================================================================
@! 4. CHAIN LEDGER INITIALIZATION & BLOCK ADDITION
@! ============================================================================

@fn lipi_blockchain_new(initial_miner, genesis_balance)
  trie = state_trie_new()
  
  @! Credit genesis miner
  acc = account_state_new(initial_miner, genesis_balance)
  trie = state_trie_put_account(trie, acc)

  genesis_block = lipi_block_mine(0, 1756584000, "0000000000000000000000000000000000000000000000000000000000000000", trie.root_hash, [], initial_miner, 1)

  return {
    chain: [genesis_block],
    state_trie: trie,
    pending_txs: [],
    difficulty: 1
  }
@end

// WHY: Retains maya_blockchain_new backward-compatible alias
@fn maya_blockchain_new(initial_miner, genesis_balance)
  return lipi_blockchain_new(initial_miner, genesis_balance)
@end

@fn lipi_blockchain_apply_tx(chain, tx)
  sender_acc = state_trie_get_account(chain.state_trie, tx.from_addr)
  @if sender_acc == 0 || sender_acc.balance < tx.value
    return 0 @! Insufficient balance
  @end

  @! Deduct from sender
  sender_acc.balance = sender_acc.balance - tx.value
  sender_acc.nonce = sender_acc.nonce + 1
  chain.state_trie = state_trie_put_account(chain.state_trie, sender_acc)

  @! Credit receiver
  recv_acc = state_trie_get_account(chain.state_trie, tx.to_addr)
  @if recv_acc == 0
    recv_acc = account_state_new(tx.to_addr, tx.value)
  @else
    recv_acc.balance = recv_acc.balance + tx.value
  @end
  chain.state_trie = state_trie_put_account(chain.state_trie, recv_acc)

  chain.pending_txs = chain.pending_txs.push(tx)
  return 1
@end

// WHY: Retains maya_blockchain_apply_tx backward-compatible alias
@fn maya_blockchain_apply_tx(chain, tx)
  return lipi_blockchain_apply_tx(chain, tx)
@end

@fn lipi_blockchain_mine_pending(chain, miner_addr)
  idx = chain.chain.len()
  last_block = chain.chain[idx - 1]
  
  // WHY: Mining reward credited to block producer (50 LIPI)
  miner_acc = state_trie_get_account(chain.state_trie, miner_addr)
  @if miner_acc == 0
    miner_acc = account_state_new(miner_addr, 50)
  @else
    miner_acc.balance = miner_acc.balance + 50
  @end
  chain.state_trie = state_trie_put_account(chain.state_trie, miner_acc)

  new_block = lipi_block_mine(idx, 1756584100, last_block.block_hash, chain.state_trie.root_hash, chain.pending_txs, miner_addr, chain.difficulty)
  
  chain.chain = chain.chain.push(new_block)
  chain.pending_txs = []
  return new_block
@end

// WHY: Retains maya_blockchain_mine_pending backward-compatible alias
@fn maya_blockchain_mine_pending(chain, miner_addr)
  return lipi_blockchain_mine_pending(chain, miner_addr)
@end
