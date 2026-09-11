@! ============================================================================
@! MAYA UNIVERSE AI — BPE TOKENIZER (ADVANCED)
@! 100% Written in Pure Maya Language — Zero External C Dependencies
@! Features: Byte-level Pair Encoding, Frequency-based Pair Merging,
@! Complete Reversible Token-to-String Decoding & Vocabulary Indexing
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@fn bpe_tokenizer_new(vocab_size)
  return {
    vocab: [],
    merges: [],
    vocab_size: vocab_size,
    special_tokens: ["<|endoftext|>", "<|padding|>", "<|unknown|>"]
  }
@end

@fn bpe_init_bytes(tokenizer)
  i = 0
  @while i < 256
    tokenizer.vocab = tokenizer.vocab.push(from_char(i))
    i = i + 1
  @end
  return tokenizer
@end

@fn get_stats(tokens)
  stats = []
  i = 0
  total = tokens.len() - 1
  @while i < total
    pair_first = tokens[i]
    pair_second = tokens[i+1]
    
    found = 0
    j = 0
    @while j < stats.len()
      st = stats[j]
      @if st.p_first == pair_first && st.p_second == pair_second
        new_cnt = st.count + 1
        stats = list_set(stats, j, { p_first: pair_first, p_second: pair_second, count: new_cnt })
        found = 1
        j = stats.len()
      @end
      j = j + 1
    @end
    
    @if found == 0
      stats = stats.push({ p_first: pair_first, p_second: pair_second, count: 1 })
    @end
    
    i = i + 1
  @end
  return stats
@end

@fn merge_tokens(tokens, p_first, p_second, new_token_id)
  new_tokens = []
  i = 0
  num_items = tokens.len()
  @while i < num_items
    @if i < num_items - 1 && tokens[i] == p_first && tokens[i+1] == p_second
      new_tokens = new_tokens.push(new_token_id)
      i = i + 2
    @else
      new_tokens = new_tokens.push(tokens[i])
      i = i + 1
    @end
  @end
  return new_tokens
@end

@fn bpe_train(tokenizer, text, target_vocab_size)
  tokens = []
  i = 0
  text_len = text.len()
  @while i < text_len
    tokens = tokens.push(char_at(text, i))
    i = i + 1
  @end
  
  num_merges = target_vocab_size - 256
  m = 0
  @while m < num_merges
    stats = get_stats(tokens)
    @if stats.len() == 0
      m = num_merges
    @else
      best_first = stats[0].p_first
      best_second = stats[0].p_second
      max_c = stats[0].count
      k = 1
      @while k < stats.len()
        @if stats[k].count > max_c
          max_c = stats[k].count
          best_first = stats[k].p_first
          best_second = stats[k].p_second
        @end
        k = k + 1
      @end
      
      new_id = 256 + m
      tokenizer.merges = tokenizer.merges.push({ p_first: best_first, p_second: best_second, id: new_id })
      tokens = merge_tokens(tokens, best_first, best_second, new_id)
    @end
    m = m + 1
  @end
  
  return tokenizer
@end

@fn bpe_encode(tokenizer, text)
  tokens = []
  i = 0
  @while i < text.len()
    tokens = tokens.push(char_at(text, i))
    i = i + 1
  @end
  
  i = 0
  @while i < tokenizer.merges.len()
    m = tokenizer.merges[i]
    tokens = merge_tokens(tokens, m.p_first, m.p_second, m.id)
    i = i + 1
  @end
  
  return tokens
@end

@fn expand_token_to_bytes(t, merges)
  @if t < 256
    return [t]
  @end
  
  @! Find merge
  i = 0
  @while i < merges.len()
    m = merges[i]
    @if m.id == t
      left_bytes = expand_token_to_bytes(m.p_first, merges)
      right_bytes = expand_token_to_bytes(m.p_second, merges)
      res = []
      j = 0
      @while j < left_bytes.len()
        res = res.push(left_bytes[j])
        j = j + 1
      @end
      j = 0
      @while j < right_bytes.len()
        res = res.push(right_bytes[j])
        j = j + 1
      @end
      return res
    @end
    i = i + 1
  @end
  return [t]
@end

@fn bpe_decode(tokenizer, tokens)
  res = ""
  i = 0
  num_items = tokens.len()
  @while i < num_items
    byte_list = expand_token_to_bytes(tokens[i], tokenizer.merges)
    j = 0
    @while j < byte_list.len()
      res = res + from_char(byte_list[j])
      j = j + 1
    @end
    i = i + 1
  @end
  return res
@end
