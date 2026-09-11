import "universe/b_core/io"
import "universe/b_core/string"

@fn hash_string(str)
  len = string_len(str)
  hash = 2166136261
  prime = 16777619
  i = 0
  @while i < len
    byte = sys_peek8(str + i)
    hash = hash ^ byte
    hash = hash * prime
    i = i + 1
  @end
  @! Ensure positive 32-bit
  return hash & 2147483647
@end

@fn int_to_string(val)
  @if val == 0 return "0" @end
  
  buf = sys_mmap(0, 32, 3, 34, 0 - 1, 0)
  temp = val
  len = 0
  @while temp > 0
    temp = temp / 10
    len = len + 1
  @end
  
  sys_poke8(buf + len, 0)
  temp = val
  i = len - 1
  @while temp > 0
    digit = temp - ((temp / 10) * 10)
    sys_poke8(buf + i, 48 + digit)
    temp = temp / 10
    i = i - 1
  @end
  
  return buf
@end

@fn mine_block(index, prev_hash, data, difficulty)
  nonce = 0
  mining = 1
  
  s_idx = int_to_string(index)
  s_prev = int_to_string(prev_hash)
  
  string_print("Mining Block ") string_print(s_idx) string_println("...")
  
  @while mining == 1
    s_nonce = int_to_string(nonce)
    
    c1 = string_concat(s_idx, s_prev)
    c2 = string_concat(c1, data)
    block_str = string_concat(c2, s_nonce)
    
    hash = hash_string(block_str)
    
    @! Check difficulty (Target e.g. < 50000)
    @if hash < difficulty
      string_print("SUCCESS! Nonce found: ") string_println(s_nonce)
      string_print("Block Hash: ") string_println(int_to_string(hash))
      string_println("-----------------------------------")
      return hash
    @end
    
    nonce = nonce + 1
  @end
  return 0
@end

@fn main()
  string_println("=== Native Maya Proof-of-Work Blockchain ===")
  
  difficulty = 100000 @! Lower is harder. Random hash is out of 2.1 billion.
  
  @! Genesis Block
  hash0 = mine_block(0, 0, "Genesis Block - Gyani Supreme", difficulty)
  
  @! Block 1
  hash1 = mine_block(1, hash0, "Alice pays Bob 5 MAYA", difficulty)
  
  @! Block 2
  hash2 = mine_block(2, hash1, "Bob pays Charlie 2 MAYA", difficulty)
  
  @! Block 3
  hash3 = mine_block(3, hash2, "Smart Contract Deployed", difficulty)
  
  string_println("Blockchain Sync Complete!")
  sys_exit(0)
@end

@fn sys_exit(code)
  sys_syscall(60, code, 0, 0, 0, 0, 0)
@end
