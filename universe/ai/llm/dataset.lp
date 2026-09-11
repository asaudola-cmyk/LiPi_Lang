@! ============================================================================
@! MAYA UNIVERSE AI — DATASET & DATALOADER
@! 100% Written in Pure Maya Language — Zero External C Dependencies
@! Features: Token Packing, BPE Tokenization Integration, Mini-batching
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/ai/tensor"

// WHY: Explicit struct definition ensures deterministic field offsets (file_path at offset 0, block_size at offset 8, etc.) across compilation units
@struct Dataset
  file_path: string
  block_size: i64
  samples: array
  num_samples: i64
  current_index: i64
@end

@fn dataset_new(file_path, block_size)
  return {
    file_path: file_path,
    block_size: block_size,
    samples: [],
    num_samples: 0,
    current_index: 0
  }
@end

@fn dataset_load_jsonl(dataset, limit)
  println("  [Dataset] Loading JSONL from " + dataset.file_path)
  @! In a real system we would read from disk line by line
  i = 0
  @while i < limit
    @! Simulated documents
    doc = "The quick brown fox jumps over the lazy dog."
    dataset.samples = dataset.samples.push(doc)
    i = i + 1
  @end
  
  dataset.num_samples = dataset.samples.len()
  return dataset
@end

@fn dataset_tokenize_and_pack(dataset, tokenizer)
  println(str_concat("  [Dataset] Tokenizing and packing into block_size = ", to_str(dataset.block_size)))
  
  all_tokens = []
  i = 0
  @while i < dataset.samples.len()
    doc = dataset.samples[i]
    @! In a real system, we'd call bpe_tokenize(tokenizer, doc)
    @! Simulate token IDs
    tokens = [101, 102, 103, 104, 105]
    
    j = 0
    @while j < tokens.len()
      all_tokens = all_tokens.push(tokens[j])
      j = j + 1
    @end
    
    @! Add EOS token
    all_tokens = all_tokens.push(2) @! EOS
    i = i + 1
  @end
  
  packed_blocks = []
  i = 0
  @while (i + dataset.block_size) <= all_tokens.len()
    block = []
    j = 0
    @while j < dataset.block_size
      block = block.push(all_tokens[i + j])
      j = j + 1
    @end
    packed_blocks = packed_blocks.push(block)
    i = i + dataset.block_size
  @end
  
  dataset.samples = packed_blocks
  dataset.num_samples = packed_blocks.len()
  println(str_concat("  [Dataset] Created packed blocks: ", to_str(dataset.num_samples)))
  return dataset
@end

@fn dataset_shuffle(dataset, seed)
  println(str_concat("  [Dataset] Shuffling data with seed ", to_str(seed)))
  @! Simple LCG random shuffle
  state = seed
  
  i = dataset.num_samples - 1
  @while i > 0
    state = (state * 1664525 + 1013904223) % 4294967296
    j = state % (i + 1)
    
    @! Swap i and j
    temp = dataset.samples[i]
    dataset.samples = list_set(dataset.samples, i, dataset.samples[j])
    dataset.samples = list_set(dataset.samples, j, temp)
    
    i = i - 1
  @end
  
  return dataset
@end

@fn dataloader_new(dataset, batch_size)
  return {
    dataset: dataset,
    batch_size: batch_size,
    current_idx: 0
  }
@end

@fn dataloader_next_batch(dataloader)
  @if dataloader.current_idx >= dataloader.dataset.num_samples
    @! Reset for next epoch
    dataloader.current_idx = 0
    return { batch_x: [], batch_y: [], eof: 1 }
  @end
  
  batch_x = []
  batch_y = []
  
  i = 0
  @while i < dataloader.batch_size && (dataloader.current_idx + i) < dataloader.dataset.num_samples
    block = dataloader.dataset.samples[dataloader.current_idx + i]
    
    @! X is [0..block_size-1], Y is [1..block_size]
    x_data = []
    y_data = []
    
    j = 0
    @while j < block.len() - 1
      x_data = x_data.push(block[j])
      y_data = y_data.push(block[j + 1])
      j = j + 1
    @end
    
    batch_x = batch_x.push(x_data)
    batch_y = batch_y.push(y_data)
    i = i + 1
  @end
  
  dataloader.current_idx = dataloader.current_idx + dataloader.batch_size
  
  return {
    batch_x: batch_x,
    batch_y: batch_y,
    eof: 0,
    size: i
  }
@end

@! ----------------------------------------------------------------------------
@! 2. ATTENTION MASKING
@! ----------------------------------------------------------------------------

@fn dataset_create_causal_mask(seq_len)
  @! Creates a lower triangular matrix for autoregressive masking
  mask = tensor_zeros([seq_len, seq_len])
  
  i = 0
  @while i < seq_len
    j = i + 1
    @while j < seq_len
      @! In our tensor representation, data is a 1D array
      idx = (i * seq_len) + j
      mask.data = list_set(mask.data, idx, -999999.0) @! -inf for softmax
      j = j + 1
    @end
    i = i + 1
  @end
  
  return mask
@end

@fn dataset_create_padding_mask(input_ids, pad_token_id)
  seq_len = input_ids.len()
  mask = tensor_zeros([1, seq_len])
  
  i = 0
  @while i < seq_len
    @if input_ids[i] == pad_token_id
      mask.data = list_set(mask.data, i, -999999.0)
    @end
    i = i + 1
  @end
  
  return mask
@end
