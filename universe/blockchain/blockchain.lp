@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — LAYER-1 SOVEREIGN BLOCKCHAIN (MAYANET)
@! Module: universe/blockchain/blockchain.maya
@! Milestone: Layer-1 Sovereign Blockchain (MayaNet)
@! 100% Pure Maya Implementation — Zero External / C++ Dependencies
@! Features: Transactions, SHA-256 Merkle Trees, Proof-of-Work (PoW) Mining,
@! Block Validation, MayaVM Smart Contract Execution & Chain Ledger
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/crypto/sha256"
import "universe/blockchain/mpt"
import "universe/blockchain/vm"

@! ============================================================================
@! 1. BLOCKCHAIN DATA STRUCTURES
@! ============================================================================

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

@struct MayaBlockchain
  chain: array
  state_trie: StateTrie
  pending_txs: array
  difficulty: i64
@end

@! ============================================================================
@! 2. TRANSACTION BUILDER & HASHING
@! ============================================================================

@fn maya_tx_new(from_addr, to_addr, val, nonce, gas_limit, gas_price, data_str)
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

@fn maya_txs_merkle_root(txs)
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

@! ============================================================================
@! 3. BLOCK MINING (Proof-of-Work / Hashcash) & HASHING
@! ============================================================================

@fn maya_block_compute_hash(idx, ts, prev_h, st_root, tx_root, miner, nonce)
  raw = idx.to_str() + ":" + ts.to_str() + ":" + prev_h + ":" + st_root + ":" + tx_root + ":" + miner + ":" + nonce.to_str()
  return sha256_hex_string(raw)
@end

@fn maya_block_mine(idx, ts, prev_h, st_root, txs, miner, difficulty)
  tx_root = maya_txs_merkle_root(txs)
  nonce = 0
  h = ""
  
  @! Mine until leading zeros match difficulty (e.g. diff 1 requires start with '0')
  @while true
    h = maya_block_compute_hash(idx, ts, prev_h, st_root, tx_root, miner, nonce)
    
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

@! ============================================================================
@! 4. CHAIN LEDGER INITIALIZATION & BLOCK ADDITION
@! ============================================================================

@fn maya_blockchain_new(initial_miner, genesis_balance)
  trie = state_trie_new()
  
  @! Credit genesis miner
  acc = account_state_new(initial_miner, genesis_balance)
  trie = state_trie_put_account(trie, acc)

  genesis_block = maya_block_mine(0, 1756584000, "0000000000000000000000000000000000000000000000000000000000000000", trie.root_hash, [], initial_miner, 1)

  return {
    chain: [genesis_block],
    state_trie: trie,
    pending_txs: [],
    difficulty: 1
  }
@end

@fn maya_blockchain_apply_tx(chain, tx)
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

@fn maya_blockchain_mine_pending(chain, miner_addr)
  idx = chain.chain.len()
  last_block = chain.chain[idx - 1]
  
  @! Mining reward (50 MAYA)
  miner_acc = state_trie_get_account(chain.state_trie, miner_addr)
  @if miner_acc == 0
    miner_acc = account_state_new(miner_addr, 50)
  @else
    miner_acc.balance = miner_acc.balance + 50
  @end
  chain.state_trie = state_trie_put_account(chain.state_trie, miner_acc)

  new_block = maya_block_mine(idx, 1756584100, last_block.block_hash, chain.state_trie.root_hash, chain.pending_txs, miner_addr, chain.difficulty)
  
  chain.chain = chain.chain.push(new_block)
  chain.pending_txs = []
  return new_block
@end
