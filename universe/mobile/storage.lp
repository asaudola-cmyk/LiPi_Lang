@! ============================================================================
@! PURE LIPI MOBILE PERSISTENT KEY-VALUE STORAGE ENGINE
@! Module: universe/mobile/storage
@! 100% Pure Lipi Implementation — File-Backed Durable Persistence
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"

@! Default storage file path
@fn default_storage_path() -> string
  return "lipi_mobile_storage.kv"
@end

@! ----------------------------------------------------------------------------
@! 1. Hex Encoding / Decoding Utilities for Arbitrary String Keys & Values
@! ----------------------------------------------------------------------------
@fn hex_char_to_nibble(code: i64) -> i64
  @if code >= 48 && code <= 57
    return code - 48
  @elif code >= 97 && code <= 102
    return code - 97 + 10
  @elif code >= 65 && code <= 70
    return code - 65 + 10
  @end
  return 0
@end

@fn hex_encode_str(s: string) -> string
  hex_chars = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"]
  res = ""
  num_items = str_len(s)
  i = 0
  @while i < num_items
    b = str_char_at(s, i) & 255
    hi = ((b / 16)) & 15
    lo = b & 15
    res = res + hex_chars[hi] + hex_chars[lo]
    i = i + 1
  @end
  return res
@end

@fn hex_decode_str(hex_s: string) -> string
  res = ""
  num_items = str_len(hex_s)
  i = 0
  @while i + 1 < num_items
    c0 = str_char_at(hex_s, i)
    c1 = str_char_at(hex_s, i + 1)
    n0 = hex_char_to_nibble(c0)
    n1 = hex_char_to_nibble(c1)
    t0 = n0 * 16
    t1 = t0 | n1
    byte_val = t1 & 255
    res = string_concat(res, str_from_char_code(byte_val))
    i = i + 2
  @end
  return res
@end

@! ----------------------------------------------------------------------------
@! 2. Low-Level Durable Store Load & Save
@! ----------------------------------------------------------------------------
@struct StorageEntry
  key: string
  val: string
@end

@fn storage_load_entries(path: string)
  entries = []
  @if file_exists(path) == 0
    return entries
  @end

  content = file_read(path)
  @if str_len(content) == 0
    return entries
  @end

  lines = string_split(content, "\n")
  i = 0
  num_lines = lines.len()
  @while i < num_lines
    line = str_trim(lines[i])
    @if str_len(line) > 0
      eq_pos = str_index_of(line, "=")
      @if eq_pos > 0
        hex_k = str_substr(line, 0, eq_pos)
        hex_v = str_substr(line, eq_pos + 1, str_len(line))
        k = hex_decode_str(hex_k)
        v = hex_decode_str(hex_v)
        entries = entries.push({ key: k, val: v })
      @end
    @end
    i = i + 1
  @end
  return entries
@end

@fn storage_save_entries(path: string, entries: array) -> i64
  content = ""
  i = 0
  num_items = entries.len()
  @while i < num_items
    entry = entries[i]
    hex_k = hex_encode_str(entry.key)
    hex_v = hex_encode_str(entry.val)
    content = content + hex_k + "=" + hex_v + "\n"
    i = i + 1
  @end
  file_write(path, content)
  return 1
@end

@! ----------------------------------------------------------------------------
@! 3. Public Mobile Storage CRUD API
@! ----------------------------------------------------------------------------

@fn storage_set_at(path: string, key: string, value: string) -> i64
  entries = storage_load_entries(path)
  updated = []
  found = 0
  i = 0
  num_items = entries.len()
  @while i < num_items
    entry = entries[i]
    @if entry.key == key
      updated = updated.push({ key: key, val: value })
      found = 1
    @else
      updated = updated.push(entry)
    @end
    i = i + 1
  @end

  @if found == 0
    updated = updated.push({ key: key, val: value })
  @end

  return storage_save_entries(path, updated)
@end

@fn storage_get_at(path: string, key: string) -> string
  entries = storage_load_entries(path)
  i = 0
  num_items = entries.len()
  @while i < num_items
    entry = entries[i]
    @if entry.key == key
      return entry.val
    @end
    i = i + 1
  @end
  return "none"
@end

@fn storage_has_at(path: string, key: string) -> i64
  entries = storage_load_entries(path)
  i = 0
  num_items = entries.len()
  @while i < num_items
    entry = entries[i]
    @if entry.key == key
      return 1
    @end
    i = i + 1
  @end
  return 0
@end

@fn storage_delete_at(path: string, key: string) -> i64
  entries = storage_load_entries(path)
  updated = []
  i = 0
  num_items = entries.len()
  @while i < num_items
    entry = entries[i]
    @if entry.key != key
      updated = updated.push(entry)
    @end
    i = i + 1
  @end
  return storage_save_entries(path, updated)
@end

@fn storage_clear_at(path: string) -> i64
  file_write(path, "")
  return 1
@end

@! Standard Interface Contracts (default file path)
@fn storage_set(key: string, value: string) -> i64
  return storage_set_at(default_storage_path(), key, value)
@end

@fn storage_get(key: string) -> string
  return storage_get_at(default_storage_path(), key)
@end

@fn storage_has(key: string) -> i64
  return storage_has_at(default_storage_path(), key)
@end

@fn storage_delete(key: string) -> i64
  return storage_delete_at(default_storage_path(), key)
@end

@fn storage_clear() -> i64
  return storage_clear_at(default_storage_path())
@end
