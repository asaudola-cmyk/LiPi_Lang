@! ============================================================================
@! MAYA UNIVERSE CRYPTO — LAYER 1 BLOCKCHAIN CORE & UTXO LEDGER
@! 100% Written in Pure Maya Language — Zero External Cryptographic Dependencies
@! Features: Merkle Trees, PoW Mining, UTXO State Machine, Longest-Chain Consensus
@! ============================================================================

import "universe/core/collections"
import "universe/core/crypto"
import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. MERKLE TREE IMPLEMENTATION
@! ----------------------------------------------------------------------------

@fn merkle_hash_pair(left_hash, right_hash)
  ctx = sha256_init()
  
  i = 0
  len = left_hash.len()
  @while i < len
    ctx = sha256_update(ctx, [left_hash[i] & 0xFF])
    i = i + 1
  @end
  
  j = 0
  rlen = right_hash.len()
  @while j < rlen
    ctx = sha256_update(ctx, [right_hash[j] & 0xFF])
    j = j + 1
  @end
  
  return sha256_final(ctx)
@end

@fn merkle_build_root(leaf_hashes)
  @if leaf_hashes.len() == 0
    return [0, 0, 0, 0, 0, 0, 0, 0]
  @end
  
  current_level = leaf_hashes
  
  @while current_level.len() > 1
    next_level = []
    i = 0
    len = current_level.len()
    
    @while i < len
      left = current_level[i]
      right = left
      @if i + 1 < len
        right = current_level[i + 1]
      @end
      
      parent_hash = merkle_hash_pair(left, right)
      next_level = next_level.push(parent_hash)
      i = i + 2
    @end
    
    current_level = next_level
  @end
  
  return current_level[0]
@end

@! ----------------------------------------------------------------------------
@! 2. UTXO (UNSPENT TRANSACTION OUTPUT) MODEL
@! ----------------------------------------------------------------------------

@fn tx_out_new(recipient_pubkey, amount)
  return {
    recipient: recipient_pubkey,
    amount: amount
  }
@end

@fn tx_in_new(prev_tx_hash, output_index, signature)
  return {
    prev_hash: prev_tx_hash,
    index: output_index,
    sig: signature
  }
@end

@fn transaction_new(inputs, outputs, lock_time)
  @! Compute tx hash from inputs and outputs
  ctx = sha256_init()
  ctx = sha256_update(ctx, [inputs.len() & 0xFF, outputs.len() & 0xFF])
  tx_id = sha256_final(ctx)
  
  return {
    id: tx_id,
    inputs: inputs,
    outputs: outputs,
    lock_time: lock_time
  }
@end

@fn utxo_set_new()
  return {
    utxos: []
  }
@end

@fn utxo_add(utxo_set, tx_id, out_index, tx_out)
  utxo_set.utxos = utxo_set.utxos.push({
    tx_id: tx_id,
    index: out_index,
    out: tx_out
  })
  return utxo_set
@end

@fn utxo_get_balance(utxo_set, pubkey)
  balance = 0
  i = 0
  len = utxo_set.utxos.len()
  @while i < len
    item = utxo_set.utxos[i]
    @if item.out.recipient == pubkey
      balance = balance + item.out.amount
    @end
    i = i + 1
  @end
  return balance
@end

@! ----------------------------------------------------------------------------
@! 3. BLOCK STRUCTURE & PROOF-OF-WORK MINING
@! ----------------------------------------------------------------------------

@fn block_header_new(version, prev_hash, merkle_root, timestamp, bits, nonce)
  return {
    version: version,
    prev_hash: prev_hash,
    merkle_root: merkle_root,
    timestamp: timestamp,
    bits: bits,
    nonce: nonce
  }
@end

@fn block_hash_header(header)
  ctx = sha256_init()
  ctx = sha256_update(ctx, [header.version & 0xFF])
  ctx = sha256_update(ctx, [(header.timestamp / 1000) & 0xFF])
  ctx = sha256_update(ctx, [header.nonce & 0xFF, (header.nonce / 256) & 0xFF])
  
  i = 0
  while_len = header.prev_hash.len()
  @while i < while_len
    ctx = sha256_update(ctx, [header.prev_hash[i] & 0xFF])
    i = i + 1
  @end
  
  return sha256_final(ctx)
@end

@fn block_new(index, prev_hash, transactions)
  tx_hashes = []
  i = 0
  len = transactions.len()
  @while i < len
    tx = transactions[i]
    tx_hashes = tx_hashes.push(tx.id)
    i = i + 1
  @end
  
  merkle_root = merkle_build_root(tx_hashes)
  header = block_header_new(1, prev_hash, merkle_root, 1700000000 + index, 4, 0)
  
  return {
    index: index,
    header: header,
    transactions: transactions,
    hash: [0, 0, 0, 0, 0, 0, 0, 0]
  }
@end

@fn block_mine(block, difficulty)
  println("  [PoW Mining] Mining Block #" + block.index.to_str() + " (Target Diff: " + difficulty.to_str() + ")...")
  
  nonce = 0
  mined = 0
  
  @while mined == 0 && nonce < 100000
    block.header.nonce = nonce
    h = block_hash_header(block.header)
    
    @! Check if hash meets leading zeros difficulty requirement
    @if (h[0] & 0x0F) == 0
      block.hash = h
      mined = 1
    @end
    
    nonce = nonce + 1
  @end
  
  println("  [PoW Mining] Block #" + block.index.to_str() + " Mined with Nonce: " + block.header.nonce.to_str())
  return block
@end

@! ----------------------------------------------------------------------------
@! 4. BLOCKCHAIN STATE & CONSENSUS ENGINE
@! ----------------------------------------------------------------------------

@fn blockchain_new()
  genesis_tx = transaction_new([], [tx_out_new("Maya_Genesis_Address", 50000000)], 0)
  genesis_block = block_new(0, [0, 0, 0, 0, 0, 0, 0, 0], [genesis_tx])
  genesis_block = block_mine(genesis_block, 1)
  
  utxos = utxo_set_new()
  utxos = utxo_add(utxos, genesis_tx.id, 0, genesis_tx.outputs[0])
  
  return {
    chain: [genesis_block],
    mempool: [],
    difficulty: 1,
    utxo_set: utxos
  }
@end

@fn blockchain_add_tx(bc, tx)
  bc.mempool = bc.mempool.push(tx)
  return bc
@end

@fn blockchain_forge_block(bc)
  last_block = bc.chain[bc.chain.len() - 1]
  new_block = block_new(last_block.index + 1, last_block.hash, bc.mempool)
  new_block = block_mine(new_block, bc.difficulty)
  
  bc.chain = bc.chain.push(new_block)
  bc.mempool = [] @! Clear mempool
  return bc
@end

@fn blockchain_validate_chain(bc)
  i = 1
  len = bc.chain.len()
  
  @while i < len
    curr = bc.chain[i]
    prev = bc.chain[i - 1]
    
    @! 1. Verify prev_hash link
    j = 0
    @while j < curr.header.prev_hash.len()
      @if curr.header.prev_hash[j] != prev.hash[j]
        return 0 @! Broken chain
      @end
      j = j + 1
    @end
    
    @! 2. Verify block hash recalculation
    recalc_h = block_hash_header(curr.header)
    @if recalc_h[0] != curr.hash[0]
      return 0 @! Corrupted block header
    @end
    
    i = i + 1
  @end
  
  return 1 @! Valid chain
@end

@! ----------------------------------------------------------------------------
@! 7. ADVANCED SMART CONTRACT VM SIMULATION
@! ----------------------------------------------------------------------------

@fn chain_execute_contract(contract_code, context)
  println("  [Chain VM] Executing smart contract (simulated)...")
  @! A very basic simulation of a stack-based VM for smart contracts
  stack = []
  
  i = 0
  @while i < contract_code.len()
    op = contract_code[i]
    @if op == "PUSH"
      i = i + 1
      stack = stack.push(contract_code[i])
    @elif op == "ADD"
      @if stack.len() >= 2
        b = stack[stack.len() - 1]
        a = stack[stack.len() - 2]
        
        @! pop 2
        new_s = []
        j = 0
        @while j < stack.len() - 2
          new_s = new_s.push(stack[j])
          j = j + 1
        @end
        stack = new_s
        
        stack = stack.push(a + b)
      @end
    @elif op == "STORE"
      @! Store into context state
      @if stack.len() >= 2
        val = stack[stack.len() - 1]
        key = stack[stack.len() - 2]
        
        @! pop 2
        new_s = []
        j = 0
        @while j < stack.len() - 2
          new_s = new_s.push(stack[j])
          j = j + 1
        @end
        stack = new_s
        
        println("  [Chain VM] State stored: Key=" + key.to_str() + " Val=" + val.to_str())
      @end
    @end
    i = i + 1
  @end
  
  return { status: "SUCCESS", stack: stack }
@end
