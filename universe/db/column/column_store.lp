@! ============================================================================
@! MAYA UNIVERSE DB - COLUMN STORE (universe/db/column/column_store.maya)
@! 100% Pure Maya Implementation — Zero External / C Dependencies
@! ============================================================================

import "universe/core/collections"

@struct ColumnChunk
  name: "",
  col_type: "INT",
  row_count: 0,
  rle_data: [],
  min_val: 0,
  max_val: 0
@end

@fn rle_encode(values)
  @if values.len() == 0
    return []
  @end

  encoded = []
  curr_val = values[0]
  curr_count = 1
  i = 1
  n = values.len()

  @while i < n
    v = values[i]
    @if v == curr_val
      curr_count = curr_count + 1
    @else
      encoded = encoded.push({ val: curr_val, count: curr_count })
      curr_val = v
      curr_count = 1
    @end
    i = i + 1
  @end

  encoded = encoded.push({ val: curr_val, count: curr_count })
  return encoded
@end

@fn rle_decode(encoded)
  decoded = []
  i = 0
  n = encoded.len()
  @while i < n
    chunk = encoded[i]
    c = 0
    @while c < chunk.count
      decoded = decoded.push(chunk.val)
      c = c + 1
    @end
    i = i + 1
  @end
  return decoded
@end

@fn bitpack(values, bit_width)
  @if values.len() == 0
    return []
  @end

  mask = (1 << bit_width) - 1
  packed = []
  curr_word = 0
  bits_filled = 0
  i = 0
  n = values.len()

  @while i < n
    val = values[i] & mask
    curr_word = curr_word | (val << bits_filled)
    bits_filled = bits_filled + bit_width

    @if bits_filled >= 64
      packed = packed.push(curr_word)
      curr_word = 0
      bits_filled = 0
    @end
    i = i + 1
  @end

  @if bits_filled > 0
    packed = packed.push(curr_word)
  @end

  return packed
@end