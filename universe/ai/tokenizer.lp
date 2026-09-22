@! ============================================================================
@! LIPI UNIVERSE AI: BYTE PAIR ENCODING (BPE) TOKENIZER
@! Module: universe/ai/tokenizer
@! 100% Pure Lipi Implementation
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@struct TokenEntry
  token: string
  id: i64
@end

@struct BPEVocab
  tokens: array
  merges: array
  vocab_size: i64
@end

@fn bpe_vocab_new() -> BPEVocab
  return {
    tokens: [],
    merges: [],
    vocab_size: 0
  }
@end

@fn bpe_add_token(vocab: BPEVocab, token: string) -> BPEVocab
  id = vocab.tokens.len()
  vocab.tokens = vocab.tokens.push({ token: token, id: id })
  vocab.vocab_size = vocab.tokens.len()
  return vocab
@end

@fn bpe_find_token_id(vocab: BPEVocab, token: string) -> i64
  i = 0
  num_items = vocab.tokens.len()
  @while i < num_items
    entry = vocab.tokens[i]
    @if entry.token == token
      return entry.id
    @end
    i = i + 1
  @end
  return -1
@end

@fn bpe_find_token_str(vocab: BPEVocab, id: i64) -> string
  @if id >= 0 && id < vocab.tokens.len()
    entry = vocab.tokens[id]
    return entry.token
  @end
  return ""
@end

@fn bpe_encode(text: string, vocab: BPEVocab) -> array
  ids = []
  num_items = str_len(text)
  i = 0
  @while i < num_items
    ch = str_substr(text, i, i + 1)
    tok_id = bpe_find_token_id(vocab, ch)
    @if tok_id >= 0
      ids = ids.push(tok_id)
    @else
      ids = ids.push(str_char_at(ch, 0))
    @end
    i = i + 1
  @end
  return ids
@end

@fn bpe_decode(ids: array, vocab: BPEVocab) -> string
  res = ""
  i = 0
  num_items = ids.len()
  @while i < num_items
    tok_id = ids[i]
    tok_str = bpe_find_token_str(vocab, tok_id)
    @if str_len(tok_str) > 0
      res = res + tok_str
    @else
      res = res + str_from_char_code(tok_id) & 255
    @end
    i = i + 1
  @end
  return res
@end

@fn main()
  return 0
@end
