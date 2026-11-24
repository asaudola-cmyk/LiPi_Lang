// ==============================================================================
// 👑 LIPI FIRST-CLASS SILICON DICT0 HASHMAP ENGINE (runtime_dict.lp)
// ⚡ 100% Pure x86_64 Machine Code | Robin-Hood Probing | Backward-Shift Delete
// 🏛️ Module: src/compiler/backend/targets/x86_64/runtime_dict.lp
// ==============================================================================
//
// WHY THIS MODULE:
// Provides built-in dynamic HashMap/Dict literals (`{ "k": v }`, `{}`, `dict()`)
// directly in bare-metal silicon with zero libc dependencies:
// - 32B GC-tracked header: [0]=count, [8]=cap, [16]=table_ptr, [24]=0x305443494450494C
// - GC automatically traces every string key and heap value inside `table_ptr`
// - Supports BOTH STR0 string keys (FNV-1a 64-bit + ERMS cmpsb) AND integer keys (SplitMix64)
// - Dynamic 2x growth at 75% load factor & zero-tombstone Robin-Hood backward-shift delete
// - Unified with _lipi_len, _lipi_list_get, and _lipi_list_set for polymorphic d[k] / len(d).
// ==============================================================================

fn x86_synth_emit__lipi_dict_key_hash s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_dict_key_hash", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 83, 72, 131, 236, 8, 72, 137, 251])
    x86_synth_emit_call_helper(s, "_lipi_is_str")
    x86_synth_emit_bytes(s, [133, 192, 116, 47, 139, 75, 248, 72, 184, 37, 35, 34, 132, 228, 156, 242, 203, 73, 184, 179, 1, 0, 0, 0, 1, 0, 0, 49, 210, 72, 57, 202, 115, 78, 68, 15, 182, 12, 19, 76, 49, 200, 73, 15, 175, 192, 72, 255, 194, 235, 234, 72, 137, 216, 72, 137, 193, 72, 193, 233, 30, 72, 49, 200, 73, 184, 185, 229, 228, 28, 109, 71, 88, 191, 73, 15, 175, 192, 72, 137, 193, 72, 193, 233, 27, 72, 49, 200, 73, 184, 235, 17, 49, 19, 187, 73, 208, 148, 73, 15, 175, 192, 72, 137, 193, 72, 193, 233, 31, 72, 49, 200, 72, 131, 196, 8, 91, 93, 195])
    return off

fn x86_synth_emit__lipi_dict_key_eq s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_dict_key_eq", off)
    x86_synth_emit_bytes(s, [72, 57, 247, 117, 6, 184, 1, 0, 0, 0, 195, 85, 72, 137, 229, 65, 84, 65, 85, 73, 137, 252, 73, 137, 245])
    x86_synth_emit_call_helper(s, "_lipi_is_str")
    x86_synth_emit_bytes(s, [133, 192, 116, 49, 76, 137, 239])
    x86_synth_emit_call_helper(s, "_lipi_is_str")
    x86_synth_emit_bytes(s, [133, 192, 116, 37, 65, 139, 76, 36, 248, 65, 59, 77, 248, 117, 26, 133, 201, 116, 11, 76, 137, 231, 76, 137, 238, 252, 243, 166, 117, 11, 184, 1, 0, 0, 0, 65, 93, 65, 92, 93, 195, 49, 192, 65, 93, 65, 92, 93, 195])
    return off

fn x86_synth_emit__lipi_dict_new s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_dict_new", off)
    x86_synth_register_helper_fn(s, "map_new", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 83, 65, 84, 72, 199, 195, 16, 0, 0, 0, 72, 57, 251, 115, 5, 72, 209, 227, 235, 246, 191, 32, 0, 0, 0])
    x86_synth_emit_call_helper(s, "_lipi_user_alloc")
    x86_synth_emit_bytes(s, [73, 137, 196, 72, 137, 223, 72, 193, 231, 5])
    x86_synth_emit_call_helper(s, "_lipi_user_alloc")
    x86_synth_emit_bytes(s, [73, 199, 4, 36, 0, 0, 0, 0, 73, 137, 92, 36, 8, 73, 137, 68, 36, 16, 72, 185, 76, 73, 80, 68, 73, 67, 84, 48, 73, 137, 76, 36, 24, 76, 137, 224, 65, 92, 91, 93, 195])
    return off

fn x86_synth_emit__lipi_dict_insert_raw s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_dict_insert_raw", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 83, 65, 84, 65, 85, 65, 86, 65, 87, 72, 131, 236, 24, 73, 137, 252, 73, 137, 245, 77, 141, 117, 255, 72, 137, 85, 208, 72, 137, 77, 200, 76, 137, 69, 192, 76, 137, 195, 76, 33, 243, 69, 49, 255, 72, 137, 216, 72, 193, 224, 5, 77, 141, 20, 4, 77, 139, 90, 24, 77, 133, 219, 117, 38, 72, 139, 69, 208, 73, 137, 2, 72, 139, 69, 200, 73, 137, 66, 8, 72, 139, 69, 192, 73, 137, 66, 16, 73, 141, 71, 1, 73, 137, 66, 24, 184, 1, 0, 0, 0, 235, 126, 73, 139, 66, 16, 72, 59, 69, 192, 117, 36, 65, 82, 65, 83, 73, 139, 58, 72, 139, 117, 208])
    x86_synth_emit_call_helper(s, "_lipi_dict_key_eq")
    x86_synth_emit_bytes(s, [65, 91, 65, 90, 133, 192, 116, 12, 72, 139, 69, 200, 73, 137, 66, 8, 49, 192, 235, 80, 73, 141, 75, 255, 73, 57, 207, 126, 57, 73, 139, 2, 72, 139, 85, 208, 73, 137, 18, 72, 137, 69, 208, 73, 139, 66, 8, 72, 139, 85, 200, 73, 137, 82, 8, 72, 137, 69, 200, 73, 139, 66, 16, 72, 139, 85, 192, 73, 137, 82, 16, 72, 137, 69, 192, 73, 141, 87, 1, 73, 137, 82, 24, 73, 137, 207, 73, 255, 199, 72, 255, 195, 76, 33, 243, 233, 72, 255, 255, 255, 72, 131, 196, 24, 65, 95, 65, 94, 65, 93, 65, 92, 91, 93, 195])
    return off

fn x86_synth_emit__lipi_dict_set s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_dict_set", off)
    x86_synth_register_helper_fn(s, "map_set", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 83, 65, 84, 65, 85, 65, 86, 65, 87, 72, 131, 236, 8, 72, 133, 255, 15, 132, 228, 0, 0, 0, 73, 137, 252, 73, 137, 245, 73, 137, 214, 73, 139, 4, 36, 72, 255, 192, 72, 193, 224, 2, 73, 139, 76, 36, 8, 72, 141, 20, 73, 72, 57, 208, 15, 130, 145, 0, 0, 0, 73, 137, 207, 73, 139, 92, 36, 16, 72, 209, 225, 72, 131, 249, 16, 115, 5, 185, 16, 0, 0, 0, 81, 72, 131, 236, 8, 72, 137, 207, 72, 193, 231, 5])
    x86_synth_emit_call_helper(s, "_lipi_user_alloc")
    x86_synth_emit_bytes(s, [72, 131, 196, 8, 89, 73, 137, 76, 36, 8, 73, 137, 68, 36, 16, 83, 65, 87, 69, 49, 201, 76, 59, 12, 36, 115, 66, 76, 137, 200, 72, 193, 224, 5, 76, 139, 84, 36, 8, 77, 141, 20, 2, 73, 131, 122, 24, 0, 116, 38, 65, 81, 72, 131, 236, 8, 73, 139, 124, 36, 16, 73, 139, 116, 36, 8, 73, 139, 18, 73, 139, 74, 8, 77, 139, 66, 16])
    x86_synth_emit_call_helper(s, "_lipi_dict_insert_raw")
    x86_synth_emit_bytes(s, [72, 131, 196, 8, 65, 89, 73, 255, 193, 235, 184, 65, 95, 95, 72, 133, 255, 116, 5])
    x86_synth_emit_call_helper(s, "_lipi_user_free")
    x86_synth_emit_bytes(s, [76, 137, 239])
    x86_synth_emit_call_helper(s, "_lipi_dict_key_hash")
    x86_synth_emit_bytes(s, [73, 137, 192, 73, 139, 124, 36, 16, 73, 139, 116, 36, 8, 76, 137, 234, 76, 137, 241])
    x86_synth_emit_call_helper(s, "_lipi_dict_insert_raw")
    x86_synth_emit_bytes(s, [133, 192, 116, 4, 73, 255, 4, 36, 76, 137, 224, 235, 2, 49, 192, 72, 131, 196, 8, 65, 95, 65, 94, 65, 93, 65, 92, 91, 93, 195])
    return off

fn x86_synth_emit__lipi_dict_get s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_dict_get", off)
    x86_synth_register_helper_fn(s, "map_get", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 83, 65, 84, 65, 85, 65, 86, 65, 87, 72, 131, 236, 8, 72, 133, 255, 116, 123, 72, 131, 63, 0, 116, 117, 76, 139, 103, 16, 76, 139, 111, 8, 77, 141, 117, 255, 73, 137, 247, 72, 137, 247])
    x86_synth_emit_call_helper(s, "_lipi_dict_key_hash")
    x86_synth_emit_bytes(s, [72, 137, 195, 72, 137, 217, 76, 33, 241, 49, 210, 72, 137, 200, 72, 193, 224, 5, 77, 141, 20, 4, 77, 139, 90, 24, 77, 133, 219, 116, 63, 77, 141, 67, 255, 76, 57, 194, 127, 54, 73, 57, 90, 16, 117, 37, 81, 82, 65, 82, 72, 131, 236, 8, 73, 139, 58, 76, 137, 254])
    x86_synth_emit_call_helper(s, "_lipi_dict_key_eq")
    x86_synth_emit_bytes(s, [72, 131, 196, 8, 65, 90, 90, 89, 133, 192, 116, 6, 73, 139, 66, 8, 235, 13, 72, 255, 194, 72, 255, 193, 76, 33, 241, 235, 173, 49, 192, 72, 131, 196, 8, 65, 95, 65, 94, 65, 93, 65, 92, 91, 93, 195])
    return off

fn x86_synth_emit__lipi_dict_has s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_dict_has", off)
    x86_synth_register_helper_fn(s, "map_has", off)
    x86_synth_register_helper_fn(s, "has_key", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 83, 65, 84, 65, 85, 65, 86, 65, 87, 72, 131, 236, 8, 72, 133, 255, 116, 112, 72, 131, 63, 0, 116, 106, 76, 139, 103, 16, 76, 139, 111, 8, 77, 141, 117, 255, 73, 137, 247, 72, 137, 247])
    x86_synth_emit_call_helper(s, "_lipi_dict_key_hash")
    x86_synth_emit_bytes(s, [72, 137, 195, 72, 137, 217, 76, 33, 241, 49, 210, 72, 137, 200, 72, 193, 224, 5, 77, 141, 20, 4, 77, 139, 90, 24, 77, 133, 219, 116, 52, 77, 141, 67, 255, 76, 57, 194, 127, 43, 73, 57, 90, 16, 117, 26, 81, 82, 73, 139, 58, 76, 137, 254])
    x86_synth_emit_call_helper(s, "_lipi_dict_key_eq")
    x86_synth_emit_bytes(s, [90, 89, 133, 192, 116, 7, 184, 1, 0, 0, 0, 235, 13, 72, 255, 194, 72, 255, 193, 76, 33, 241, 235, 184, 49, 192, 72, 131, 196, 8, 65, 95, 65, 94, 65, 93, 65, 92, 91, 93, 195])
    return off

fn x86_synth_emit__lipi_dict_del s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_dict_del", off)
    x86_synth_register_helper_fn(s, "map_del", off)
    x86_synth_register_helper_fn(s, "del_key", off)
    x86_synth_register_helper_fn(s, "dict_del", off)
    x86_synth_register_helper_fn(s, "dict_remove", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 83, 65, 84, 65, 85, 65, 86, 65, 87, 72, 131, 236, 24, 72, 133, 255, 15, 132, 244, 0, 0, 0, 72, 131, 63, 0, 15, 132, 234, 0, 0, 0, 72, 137, 125, 208, 72, 137, 117, 200, 76, 139, 103, 16, 76, 139, 111, 8, 77, 141, 117, 255, 72, 137, 247])
    x86_synth_emit_call_helper(s, "_lipi_dict_key_hash")
    x86_synth_emit_bytes(s, [72, 137, 195, 72, 137, 217, 76, 33, 241, 49, 210, 72, 137, 200, 72, 193, 224, 5, 77, 141, 20, 4, 77, 139, 90, 24, 77, 133, 219, 15, 132, 171, 0, 0, 0, 77, 141, 67, 255, 76, 57, 194, 15, 143, 158, 0, 0, 0, 73, 57, 90, 16, 117, 20, 81, 82, 73, 139, 58, 72, 139, 117, 200])
    x86_synth_emit_call_helper(s, "_lipi_dict_key_eq")
    x86_synth_emit_bytes(s, [90, 89, 133, 192, 117, 11, 72, 255, 194, 72, 255, 193, 76, 33, 241, 235, 182, 73, 137, 200, 77, 141, 72, 1, 77, 33, 241, 76, 137, 200, 72, 193, 224, 5, 77, 141, 20, 4, 77, 139, 90, 24, 76, 137, 192, 72, 193, 224, 5, 73, 141, 20, 4, 73, 131, 251, 1, 126, 34, 73, 139, 2, 72, 137, 2, 73, 139, 66, 8, 72, 137, 66, 8, 73, 139, 66, 16, 72, 137, 66, 16, 73, 255, 203, 76, 137, 90, 24, 77, 137, 200, 235, 183, 72, 199, 2, 0, 0, 0, 0, 72, 199, 66, 8, 0, 0, 0, 0, 72, 199, 66, 16, 0, 0, 0, 0, 72, 199, 66, 24, 0, 0, 0, 0, 72, 139, 69, 208, 72, 255, 8, 184, 1, 0, 0, 0, 235, 2, 49, 192, 72, 131, 196, 24, 65, 95, 65, 94, 65, 93, 65, 92, 91, 93, 195])
    return off

fn x86_synth_emit__lipi_dict_keys s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_dict_keys", off)
    x86_synth_register_helper_fn(s, "map_keys", off)
    x86_synth_register_helper_fn(s, "keys", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 83, 65, 84, 65, 85, 65, 86, 73, 137, 252, 49, 255, 49, 246])
    x86_synth_emit_call_helper(s, "_lipi_list_create")
    x86_synth_emit_bytes(s, [73, 137, 197, 77, 133, 228, 116, 50, 77, 139, 116, 36, 16, 73, 139, 92, 36, 8, 69, 49, 228, 73, 57, 220, 115, 32, 76, 137, 224, 72, 193, 224, 5, 73, 131, 124, 6, 24, 0, 116, 12, 76, 137, 239, 73, 139, 52, 6])
    x86_synth_emit_call_helper(s, "_lipi_list_push")
    x86_synth_emit_bytes(s, [73, 255, 196, 235, 219, 76, 137, 232, 65, 94, 65, 93, 65, 92, 91, 93, 195])
    return off

fn x86_synth_emit__lipi_dict_values s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_dict_values", off)
    x86_synth_register_helper_fn(s, "map_values", off)
    x86_synth_register_helper_fn(s, "values", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 83, 65, 84, 65, 85, 65, 86, 73, 137, 252, 49, 255, 49, 246])
    x86_synth_emit_call_helper(s, "_lipi_list_create")
    x86_synth_emit_bytes(s, [73, 137, 197, 77, 133, 228, 116, 51, 77, 139, 116, 36, 16, 73, 139, 92, 36, 8, 69, 49, 228, 73, 57, 220, 115, 33, 76, 137, 224, 72, 193, 224, 5, 73, 131, 124, 6, 24, 0, 116, 13, 76, 137, 239, 73, 139, 116, 6, 8])
    x86_synth_emit_call_helper(s, "_lipi_list_push")
    x86_synth_emit_bytes(s, [73, 255, 196, 235, 218, 76, 137, 232, 65, 94, 65, 93, 65, 92, 91, 93, 195])
    return off

fn x86_synth_emit_all_dict_helpers s
    x86_synth_emit__lipi_dict_key_hash(s)
    x86_synth_emit__lipi_dict_key_eq(s)
    x86_synth_emit__lipi_dict_new(s)
    x86_synth_emit__lipi_dict_insert_raw(s)
    x86_synth_emit__lipi_dict_set(s)
    x86_synth_emit__lipi_dict_get(s)
    x86_synth_emit__lipi_dict_has(s)
    x86_synth_emit__lipi_dict_del(s)
    x86_synth_emit__lipi_dict_keys(s)
    x86_synth_emit__lipi_dict_values(s)
    return 0
