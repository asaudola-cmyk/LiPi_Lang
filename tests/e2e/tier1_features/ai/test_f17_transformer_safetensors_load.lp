@! ============================================================================
@! MAYA E2E TIER 1 — F17: Transformer SafeTensors Load
@! File: tests/e2e/tier1_features/ai/test_f17_transformer_safetensors_load.maya
@! ============================================================================

import "universe/ai/transformer/gpt"

@fn main()
  header_json = "{\"weight\": {\"dtype\": \"F32\", \"shape\": [100, 100], \"data_offsets\": [0, 40000]}}"
  hdr = safetensors_parse_header(header_json)
  @if hdr.tensor_name != "weight" || hdr.data_type != "F32" return 1 @end
  @if hdr.data_size_bytes != 40000 return 1 @end
  println("✓ PASS: test_f17_transformer_safetensors_load")
  return 0
@end
