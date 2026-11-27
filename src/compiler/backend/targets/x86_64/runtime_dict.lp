// ==============================================================================
// 👑 LIPI FIRST-CLASS SILICON DICT0 HASHMAP ENGINE (runtime_dict.lp)
// ⚡ 100% Pure x86_64 Machine Code | Robin-Hood Probing | Zero-Overhead Value Tags
// 🏛️ Module: src/compiler/backend/targets/x86_64/runtime_dict.lp
// ==============================================================================
//
// WHY THIS MODULE:
// Provides built-in dynamic HashMap/Dict literals (`{ "k": v }`, `{}`, `dict()`)
// directly in bare-metal silicon with zero libc dependencies:
// - 32B GC-tracked header: [0]=count, [8]=cap, [16]=table_ptr, [24]=0x305443494450494C
// - 32B table slots with ZERO extra memory for runtime float/string/int type tags:
//   [+0]=key, [+8]=val, [+16]=hash, [+24..+27]=psl+1 (0=empty), [+31]=val_tag (0=int/ptr, 1=float, 2=str)
// - _lipi_dict_get returns %rax = raw 64-bit val, %rdx = val_tag (100% thread-safe, full 64-bit i64/f64!)
// - Dynamic 2x growth at 75% load factor & zero-tombstone Robin-Hood backward-shift delete
// - Unified with _lipi_len, _lipi_list_get, _lipi_list_set_typed, _lipi_ensure_str_tagged,
//   _lipi_print_tagged, and _lipi_binop_tagged for seamless heterogeneous float/int/str dicts.
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
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 83, 65, 84, 65, 85, 65, 86, 65, 87, 72, 131, 236, 40, 73, 137, 252, 73, 137, 245, 77, 141, 117, 255, 72, 137, 85, 208, 72, 137, 77, 200, 76, 137, 69, 192, 73, 129, 225, 255, 0, 0, 0, 73, 193, 225, 56, 76, 137, 77, 184, 76, 137, 195, 76, 33, 243, 69, 49, 255, 72, 137, 216, 72, 193, 224, 5, 77, 141, 20, 4, 77, 139, 90, 24, 69, 133, 219, 117, 45, 72, 139, 69, 208, 73, 137, 2, 72, 139, 69, 200, 73, 137, 66, 8, 72, 139, 69, 192, 73, 137, 66, 16, 73, 141, 71, 1, 72, 11, 69, 184, 73, 137, 66, 24, 184, 1, 0, 0, 0, 233, 155, 0, 0, 0, 73, 139, 66, 16, 72, 59, 69, 192, 117, 47, 65, 82, 65, 83, 73, 139, 58, 72, 139, 117, 208])
    x86_synth_emit_call_helper(s, "_lipi_dict_key_eq")
    x86_synth_emit_bytes(s, [65, 91, 65, 90, 133, 192, 116, 23, 72, 139, 69, 200, 73, 137, 66, 8, 68, 137, 216, 72, 11, 69, 184, 73, 137, 66, 24, 49, 192, 235, 98, 68, 137, 217, 72, 255, 201, 73, 57, 207, 126, 73, 73, 139, 2, 72, 139, 85, 208, 73, 137, 18, 72, 137, 69, 208, 73, 139, 66, 8, 72, 139, 85, 200, 73, 137, 82, 8, 72, 137, 69, 200, 73, 139, 66, 16, 72, 139, 85, 192, 73, 137, 82, 16, 72, 137, 69, 192, 73, 141, 87, 1, 72, 11, 85, 184, 73, 137, 82, 24, 73, 193, 235, 56, 73, 193, 227, 56, 76, 137, 93, 184, 73, 137, 207, 73, 255, 199, 72, 255, 195, 76, 33, 243, 233, 36, 255, 255, 255, 72, 131, 196, 40, 65, 95, 65, 94, 65, 93, 65, 92, 91, 93, 195])
    return off

fn x86_synth_emit__lipi_dict_set s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_dict_set", off)
    x86_synth_register_helper_fn(s, "map_set", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 49, 201])
    x86_synth_emit_call_helper(s, "_lipi_dict_set_typed")
    x86_synth_emit_bytes(s, [93, 195])
    return off

fn x86_synth_emit__lipi_dict_set_typed s
    // WHY: Thread-safe dict insert/update protected by per-dict bit-63 spinlock on cap slot [r12+8].
    // Holds lock across 2x rehash, migration, AND _lipi_user_free(old_table) before releasing bit 63
    // so concurrent readers/writers never dereference a freed table or observe half-migrated slots.
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_dict_set_typed", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 83, 65, 84, 65, 85, 65, 86, 65, 87, 72, 131, 236, 24, 72, 133, 255, 15, 132, 30, 1, 0, 0, 73, 137, 252, 73, 137, 245, 73, 137, 214, 72, 137, 77, 200, 240, 73, 15, 186, 108, 36, 8, 63, 115, 4, 243, 144, 235, 242, 73, 139, 4, 36, 72, 255, 192, 72, 193, 224, 2, 73, 139, 76, 36, 8, 72, 15, 186, 241, 63, 72, 141, 20, 73, 72, 57, 208, 15, 130, 163, 0, 0, 0, 73, 137, 207, 73, 139, 92, 36, 16, 72, 209, 225, 72, 131, 249, 16, 115, 5, 185, 16, 0, 0, 0, 81, 72, 131, 236, 8, 72, 137, 207, 72, 193, 231, 5])
    x86_synth_emit_call_helper(s, "_lipi_user_alloc")
    x86_synth_emit_bytes(s, [72, 131, 196, 8, 89, 72, 137, 202, 72, 15, 186, 234, 63, 73, 137, 84, 36, 8, 73, 137, 68, 36, 16, 83, 65, 87, 69, 49, 201, 76, 59, 12, 36, 115, 76, 76, 137, 200, 72, 193, 224, 5, 76, 139, 84, 36, 8, 77, 141, 20, 2, 65, 131, 122, 24, 0, 116, 48, 65, 81, 72, 131, 236, 8, 73, 139, 124, 36, 16, 73, 139, 116, 36, 8, 72, 15, 186, 246, 63, 73, 139, 18, 73, 139, 74, 8, 77, 139, 66, 16, 69, 15, 182, 74, 31])
    x86_synth_emit_call_helper(s, "_lipi_dict_insert_raw")
    x86_synth_emit_bytes(s, [72, 131, 196, 8, 65, 89, 73, 255, 193, 235, 174, 65, 95, 95, 72, 133, 255, 116, 5])
    x86_synth_emit_call_helper(s, "_lipi_user_free")
    x86_synth_emit_bytes(s, [76, 137, 239])
    x86_synth_emit_call_helper(s, "_lipi_dict_key_hash")
    x86_synth_emit_bytes(s, [73, 137, 192, 73, 139, 124, 36, 16, 73, 139, 116, 36, 8, 72, 15, 186, 246, 63, 76, 137, 234, 76, 137, 241, 76, 139, 77, 200])
    x86_synth_emit_call_helper(s, "_lipi_dict_insert_raw")
    x86_synth_emit_bytes(s, [133, 192, 116, 4, 73, 255, 4, 36, 240, 73, 15, 186, 116, 36, 8, 63, 76, 137, 224, 235, 2, 49, 192, 72, 131, 196, 24, 65, 95, 65, 94, 65, 93, 65, 92, 91, 93, 195])
    return off

fn x86_synth_emit__lipi_dict_get s
    // WHY: Thread-safe dict lookup under per-dict bit-63 spinlock on [dict+8] with bit-63 cap masking.
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_dict_get", off)
    x86_synth_register_helper_fn(s, "map_get", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 83, 65, 84, 65, 85, 65, 86, 65, 87, 72, 131, 236, 24, 72, 133, 255, 15, 132, 176, 0, 0, 0, 72, 137, 125, 208, 240, 72, 15, 186, 111, 8, 63, 115, 4, 243, 144, 235, 243, 72, 131, 63, 0, 15, 132, 138, 0, 0, 0, 76, 139, 103, 16, 76, 139, 111, 8, 73, 15, 186, 245, 63, 77, 141, 117, 255, 73, 137, 247, 72, 137, 247])
    x86_synth_emit_call_helper(s, "_lipi_dict_key_hash")
    x86_synth_emit_bytes(s, [72, 137, 195, 72, 137, 217, 76, 33, 241, 49, 210, 72, 137, 200, 72, 193, 224, 5, 77, 141, 20, 4, 69, 139, 90, 24, 69, 133, 219, 116, 79, 77, 141, 67, 255, 76, 57, 194, 127, 70, 73, 57, 90, 16, 117, 53, 81, 82, 65, 82, 72, 131, 236, 8, 73, 139, 58, 76, 137, 254])
    x86_synth_emit_call_helper(s, "_lipi_dict_key_eq")
    x86_synth_emit_bytes(s, [72, 131, 196, 8, 65, 90, 90, 89, 133, 192, 116, 22, 73, 139, 66, 8, 65, 15, 182, 82, 31, 76, 139, 93, 208, 240, 73, 15, 186, 115, 8, 63, 235, 26, 72, 255, 194, 72, 255, 193, 76, 33, 241, 235, 157, 76, 139, 93, 208, 240, 73, 15, 186, 115, 8, 63, 49, 192, 49, 210, 72, 131, 196, 24, 65, 95, 65, 94, 65, 93, 65, 92, 91, 93, 195])
    return off

fn x86_synth_emit__lipi_dict_has s
    // WHY: Thread-safe dict membership test under per-dict bit-63 spinlock on [dict+8].
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_dict_has", off)
    x86_synth_register_helper_fn(s, "map_has", off)
    x86_synth_register_helper_fn(s, "has_key", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 83, 65, 84, 65, 85, 65, 86, 65, 87, 72, 131, 236, 24, 72, 133, 255, 15, 132, 160, 0, 0, 0, 72, 137, 125, 208, 240, 72, 15, 186, 111, 8, 63, 115, 4, 243, 144, 235, 243, 72, 131, 63, 0, 15, 132, 122, 0, 0, 0, 76, 139, 103, 16, 76, 139, 111, 8, 73, 15, 186, 245, 63, 77, 141, 117, 255, 73, 137, 247, 72, 137, 247])
    x86_synth_emit_call_helper(s, "_lipi_dict_key_hash")
    x86_synth_emit_bytes(s, [72, 137, 195, 72, 137, 217, 76, 33, 241, 49, 210, 72, 137, 200, 72, 193, 224, 5, 77, 141, 20, 4, 69, 139, 90, 24, 69, 133, 219, 116, 63, 77, 141, 67, 255, 76, 57, 194, 127, 54, 73, 57, 90, 16, 117, 37, 81, 82, 73, 139, 58, 76, 137, 254])
    x86_synth_emit_call_helper(s, "_lipi_dict_key_eq")
    x86_synth_emit_bytes(s, [90, 89, 133, 192, 116, 18, 76, 139, 93, 208, 240, 73, 15, 186, 115, 8, 63, 184, 1, 0, 0, 0, 235, 24, 72, 255, 194, 72, 255, 193, 76, 33, 241, 235, 173, 76, 139, 93, 208, 240, 73, 15, 186, 115, 8, 63, 49, 192, 72, 131, 196, 24, 65, 95, 65, 94, 65, 93, 65, 92, 91, 93, 195])
    return off

fn x86_synth_emit__lipi_dict_del s
    // WHY: Thread-safe Robin-Hood backward-shift delete under per-dict bit-63 spinlock on [dict+8].
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_dict_del", off)
    x86_synth_register_helper_fn(s, "map_del", off)
    x86_synth_register_helper_fn(s, "del_key", off)
    x86_synth_register_helper_fn(s, "dict_del", off)
    x86_synth_register_helper_fn(s, "dict_remove", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 83, 65, 84, 65, 85, 65, 86, 65, 87, 72, 131, 236, 24, 72, 133, 255, 15, 132, 26, 1, 0, 0, 240, 72, 15, 186, 111, 8, 63, 115, 4, 243, 144, 235, 243, 72, 137, 125, 208, 72, 131, 63, 0, 15, 132, 244, 0, 0, 0, 72, 137, 117, 200, 76, 139, 103, 16, 76, 139, 111, 8, 73, 15, 186, 245, 63, 77, 141, 117, 255, 72, 137, 247])
    x86_synth_emit_call_helper(s, "_lipi_dict_key_hash")
    x86_synth_emit_bytes(s, [72, 137, 195, 72, 137, 217, 76, 33, 241, 49, 210, 72, 137, 200, 72, 193, 224, 5, 77, 141, 20, 4, 69, 139, 90, 24, 69, 133, 219, 15, 132, 180, 0, 0, 0, 77, 141, 67, 255, 76, 57, 194, 15, 143, 167, 0, 0, 0, 73, 57, 90, 16, 117, 20, 81, 82, 73, 139, 58, 72, 139, 117, 200])
    x86_synth_emit_call_helper(s, "_lipi_dict_key_eq")
    x86_synth_emit_bytes(s, [90, 89, 133, 192, 117, 11, 72, 255, 194, 72, 255, 193, 76, 33, 241, 235, 182, 73, 137, 200, 77, 141, 72, 1, 77, 33, 241, 76, 137, 200, 72, 193, 224, 5, 77, 141, 20, 4, 77, 139, 90, 24, 68, 137, 217, 76, 137, 192, 72, 193, 224, 5, 73, 141, 20, 4, 131, 249, 1, 126, 34, 73, 139, 2, 72, 137, 2, 73, 139, 66, 8, 72, 137, 66, 8, 73, 139, 66, 16, 72, 137, 66, 16, 73, 255, 203, 76, 137, 90, 24, 77, 137, 200, 235, 181, 72, 199, 2, 0, 0, 0, 0, 72, 199, 66, 8, 0, 0, 0, 0, 72, 199, 66, 16, 0, 0, 0, 0, 72, 199, 66, 24, 0, 0, 0, 0, 72, 139, 69, 208, 72, 255, 8, 240, 72, 15, 186, 112, 8, 63, 184, 1, 0, 0, 0, 235, 13, 76, 139, 93, 208, 240, 73, 15, 186, 115, 8, 63, 49, 192, 72, 131, 196, 24, 65, 95, 65, 94, 65, 93, 65, 92, 91, 93, 195])
    return off

fn x86_synth_emit__lipi_dict_keys s
    // WHY: Thread-safe snapshot of dict keys under per-dict bit-63 spinlock on [r15+8].
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_dict_keys", off)
    x86_synth_register_helper_fn(s, "map_keys", off)
    x86_synth_register_helper_fn(s, "keys", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 83, 65, 84, 65, 85, 65, 86, 65, 87, 72, 131, 236, 8, 73, 137, 255, 49, 255, 49, 246])
    x86_synth_emit_call_helper(s, "_lipi_list_create")
    x86_synth_emit_bytes(s, [73, 137, 197, 77, 133, 255, 116, 73, 240, 73, 15, 186, 111, 8, 63, 115, 4, 243, 144, 235, 243, 77, 139, 119, 16, 73, 139, 95, 8, 72, 15, 186, 243, 63, 69, 49, 228, 73, 57, 220, 115, 32, 76, 137, 224, 72, 193, 224, 5, 65, 131, 124, 6, 24, 0, 116, 12, 76, 137, 239, 73, 139, 52, 6])
    x86_synth_emit_call_helper(s, "_lipi_list_push")
    x86_synth_emit_bytes(s, [73, 255, 196, 235, 219, 240, 73, 15, 186, 119, 8, 63, 76, 137, 232, 72, 131, 196, 8, 65, 95, 65, 94, 65, 93, 65, 92, 91, 93, 195])
    return off

fn x86_synth_emit__lipi_dict_values s
    // WHY: Thread-safe snapshot of dict values under per-dict bit-63 spinlock on [r15+8].
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_dict_values", off)
    x86_synth_register_helper_fn(s, "map_values", off)
    x86_synth_register_helper_fn(s, "values", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 83, 65, 84, 65, 85, 65, 86, 65, 87, 72, 131, 236, 8, 73, 137, 255, 49, 255, 49, 246])
    x86_synth_emit_call_helper(s, "_lipi_list_create")
    x86_synth_emit_bytes(s, [73, 137, 197, 77, 133, 255, 116, 74, 240, 73, 15, 186, 111, 8, 63, 115, 4, 243, 144, 235, 243, 77, 139, 119, 16, 73, 139, 95, 8, 72, 15, 186, 243, 63, 69, 49, 228, 73, 57, 220, 115, 33, 76, 137, 224, 72, 193, 224, 5, 65, 131, 124, 6, 24, 0, 116, 13, 76, 137, 239, 73, 139, 116, 6, 8])
    x86_synth_emit_call_helper(s, "_lipi_list_push")
    x86_synth_emit_bytes(s, [73, 255, 196, 235, 218, 240, 73, 15, 186, 119, 8, 63, 76, 137, 232, 72, 131, 196, 8, 65, 95, 65, 94, 65, 93, 65, 92, 91, 93, 195])
    return off

fn x86_synth_emit__lipi_ensure_str_tagged s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_ensure_str_tagged", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 131, 254, 1, 116, 7])
    x86_synth_emit_call_helper(s, "_lipi_ensure_str")
    x86_synth_emit_bytes(s, [93, 195])
    x86_synth_emit_call_helper(s, "_lipi_float_to_str")
    x86_synth_emit_bytes(s, [93, 195])
    return off

fn x86_synth_emit__lipi_print_tagged s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_print_tagged", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 131, 254, 1, 116, 7])
    x86_synth_emit_call_helper(s, "_lipi_print_dynamic")
    x86_synth_emit_bytes(s, [93, 195])
    x86_synth_emit_call_helper(s, "_lipi_print_float")
    x86_synth_emit_bytes(s, [93, 195])
    return off

fn x86_synth_emit__lipi_binop_tagged s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_binop_tagged", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 83, 65, 84, 65, 85, 65, 86, 65, 87, 72, 131, 236, 8, 73, 137, 252, 73, 137, 245, 73, 137, 214, 73, 137, 207, 76, 137, 195, 72, 133, 219, 117, 94, 65, 131, 254, 2, 116, 42, 65, 131, 255, 2, 116, 36, 65, 131, 254, 1, 116, 12, 76, 137, 231])
    x86_synth_emit_call_helper(s, "_lipi_is_str")
    x86_synth_emit_bytes(s, [133, 192, 117, 18, 65, 131, 255, 1, 116, 74, 76, 137, 239])
    x86_synth_emit_call_helper(s, "_lipi_is_str")
    x86_synth_emit_bytes(s, [133, 192, 116, 46, 76, 137, 231, 76, 137, 246])
    x86_synth_emit_call_helper(s, "_lipi_ensure_str_tagged")
    x86_synth_emit_bytes(s, [73, 137, 196, 76, 137, 239, 76, 137, 254])
    x86_synth_emit_call_helper(s, "_lipi_ensure_str_tagged")
    x86_synth_emit_bytes(s, [76, 137, 231, 72, 137, 198])
    x86_synth_emit_call_helper(s, "_lipi_str_concat")
    x86_synth_emit_bytes(s, [186, 2, 0, 0, 0, 233, 9, 2, 0, 0, 65, 131, 254, 1, 116, 10, 65, 131, 255, 1, 15, 133, 13, 1, 0, 0, 65, 131, 254, 1, 116, 7, 242, 73, 15, 42, 196, 235, 5, 102, 73, 15, 110, 196, 65, 131, 255, 1, 116, 7, 242, 73, 15, 42, 205, 235, 5, 102, 73, 15, 110, 205, 131, 251, 0, 117, 6, 242, 15, 88, 193, 235, 64, 131, 251, 1, 117, 6, 242, 15, 92, 193, 235, 53, 131, 251, 2, 117, 6, 242, 15, 89, 193, 235, 42, 131, 251, 3, 117, 6, 242, 15, 94, 193, 235, 31, 131, 251, 4, 117, 41, 102, 15, 40, 208, 242, 15, 94, 193, 102, 15, 58, 11, 192, 3, 242, 15, 89, 193, 242, 15, 92, 208, 102, 15, 40, 194, 102, 72, 15, 126, 192, 186, 1, 0, 0, 0, 233, 123, 1, 0, 0, 131, 251, 5, 117, 18, 102, 15, 46, 200, 15, 151, 192, 72, 15, 182, 192, 49, 210, 233, 100, 1, 0, 0, 131, 251, 6, 117, 18, 102, 15, 46, 200, 15, 147, 192, 72, 15, 182, 192, 49, 210, 233, 77, 1, 0, 0, 131, 251, 7, 117, 18, 102, 15, 46, 193, 15, 151, 192, 72, 15, 182, 192, 49, 210, 233, 54, 1, 0, 0, 131, 251, 8, 117, 18, 102, 15, 46, 193, 15, 147, 192, 72, 15, 182, 192, 49, 210, 233, 31, 1, 0, 0, 131, 251, 9, 117, 23, 102, 15, 46, 193, 15, 148, 192, 15, 155, 193, 32, 200, 72, 15, 182, 192, 49, 210, 233, 3, 1, 0, 0, 102, 15, 46, 193, 15, 149, 192, 15, 154, 193, 8, 200, 72, 15, 182, 192, 49, 210, 233, 236, 0, 0, 0, 131, 251, 0, 117, 11, 75, 141, 4, 44, 49, 210, 233, 220, 0, 0, 0, 131, 251, 1, 117, 13, 76, 137, 224, 76, 41, 232, 49, 210, 233, 202, 0, 0, 0, 131, 251, 2, 117, 14, 76, 137, 224, 73, 15, 175, 197, 49, 210, 233, 183, 0, 0, 0, 131, 251, 3, 117, 41, 49, 192, 77, 133, 237, 15, 132, 165, 0, 0, 0, 73, 131, 253, 255, 117, 11, 76, 137, 224, 72, 247, 216, 233, 148, 0, 0, 0, 76, 137, 224, 72, 153, 73, 247, 253, 233, 135, 0, 0, 0, 131, 251, 4, 117, 26, 49, 192, 77, 133, 237, 116, 123, 73, 131, 253, 255, 116, 117, 76, 137, 224, 72, 153, 73, 247, 253, 72, 137, 208, 235, 104, 131, 251, 5, 117, 12, 77, 57, 236, 15, 156, 192, 72, 15, 182, 192, 235, 87, 131, 251, 6, 117, 12, 77, 57, 236, 15, 158, 192, 72, 15, 182, 192, 235, 70, 131, 251, 7, 117, 12, 77, 57, 236, 15, 159, 192, 72, 15, 182, 192, 235, 53, 131, 251, 8, 117, 12, 77, 57, 236, 15, 157, 192, 72, 15, 182, 192, 235, 36, 76, 137, 231, 76, 137, 238])
    x86_synth_emit_call_helper(s, "_lipi_cmp_dynamic")
    x86_synth_emit_bytes(s, [131, 251, 9, 117, 11, 133, 192, 15, 148, 192, 72, 15, 182, 192, 235, 9, 133, 192, 15, 149, 192, 72, 15, 182, 192, 49, 210, 72, 131, 196, 8, 65, 95, 65, 94, 65, 93, 65, 92, 91, 93, 195])
    return off

fn x86_synth_emit_all_dict_helpers s
    x86_synth_emit__lipi_dict_key_hash(s)
    x86_synth_emit__lipi_dict_key_eq(s)
    x86_synth_emit__lipi_dict_new(s)
    x86_synth_emit__lipi_dict_insert_raw(s)
    x86_synth_emit__lipi_dict_set(s)
    x86_synth_emit__lipi_dict_set_typed(s)
    x86_synth_emit__lipi_dict_get(s)
    x86_synth_emit__lipi_dict_has(s)
    x86_synth_emit__lipi_dict_del(s)
    x86_synth_emit__lipi_dict_keys(s)
    x86_synth_emit__lipi_dict_values(s)
    x86_synth_emit__lipi_ensure_str_tagged(s)
    x86_synth_emit__lipi_print_tagged(s)
    x86_synth_emit__lipi_binop_tagged(s)
    return 0
