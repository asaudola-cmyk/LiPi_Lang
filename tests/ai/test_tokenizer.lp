@! Maya BPE Tokenizer Unit Tests
import "universe/core/collections"
import "universe/core/string"
import "universe/ai/llm/tokenizer"

@fn assert_eq(actual, expected, msg)
  @if actual == expected
    println("  [PASS] " + msg)
    return 1
  @else
    println("  [FAIL] " + msg + " (Got " + actual.to_str() + ", Expected " + expected.to_str() + ")")
    return 0
  @end
@end

@fn assert_str_eq(actual: string, expected: string, msg: string) -> i64
  @if actual == expected
    println("  [PASS] " + msg)
    return 1
  @else
    println("  [FAIL] " + msg + " (Got '" + actual + "', Expected '" + expected + "')")
    return 0
  @end
@end

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println("  [FAIL] " + msg)
    return 0
  @end
  println("  [PASS] " + msg)
  return 1
@end

@fn main()
  println("==================================================")
  println("   MAYA TOKENIZER UNIT TEST SUITE                 ")
  println("==================================================")
  
  @! 1. Initialize BPE Tokenizer
  tok = bpe_tokenizer_new(260)
  tok = bpe_init_bytes(tok)
  assert_eq(tok.vocab.len(), 256, "Initialized 256 byte tokens")
  assert_eq(tok.vocab_size, 260, "Target vocab size is 260")

  @! 2. Train BPE on repeated corpus
  corpus = "hello hello world world"
  tok = bpe_train(tok, corpus, 260)
  assert_true(tok.merges.len() > 0, "BPE learned merges from corpus")

  @! 3. Encode text
  encoded = bpe_encode(tok, corpus)
  assert_true(encoded.len() < corpus.len(), "BPE encoding compressed token sequence")

  @! 4. Decode tokens back to string
  decoded = bpe_decode(tok, encoded)
  assert_str_eq(decoded, corpus, "BPE decode roundtrip matches original corpus")
  
  println("🎉 ALL TOKENIZER TESTS PASSED!")
  return 0
@end
