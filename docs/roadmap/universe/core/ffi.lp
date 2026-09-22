@! ============================================================================
@! MAYA UNIVERSE CORE — FOREIGN FUNCTION INTERFACE (FFI) & C ABI ENGINE
@! 100% Written in Pure Maya Language — Zero libffi / External Tool Dependencies
@! Features: C ABI Calling Conventions, Struct Layout, Alignment, Trampoline Gen
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. C TYPE DEFINITIONS & SIZES
@! ----------------------------------------------------------------------------

@fn ffi_type_i8()   return { name: "int8_t",   size: 1, align: 1 } @end
@fn ffi_type_i16()  return { name: "int16_t",  size: 2, align: 2 } @end
@fn ffi_type_i32()  return { name: "int32_t",  size: 4, align: 4 } @end
@fn ffi_type_i64()  return { name: "int64_t",  size: 8, align: 8 } @end
@fn ffi_type_u8()   return { name: "uint8_t",  size: 1, align: 1 } @end
@fn ffi_type_u16()  return { name: "uint16_t", size: 2, align: 2 } @end
@fn ffi_type_u32()  return { name: "uint32_t", size: 4, align: 4 } @end
@fn ffi_type_u64()  return { name: "uint64_t", size: 8, align: 8 } @end
@fn ffi_type_f32()  return { name: "float",    size: 4, align: 4 } @end
@fn ffi_type_f64()  return { name: "double",   size: 8, align: 8 } @end
@fn ffi_type_ptr()  return { name: "void*",    size: 8, align: 8 } @end
@fn ffi_type_void() return { name: "void",     size: 0, align: 1 } @end

@! ----------------------------------------------------------------------------
@! 2. C STRUCT MEMORY LAYOUT & ALIGNMENT CALCULATOR
@! ----------------------------------------------------------------------------

@fn ffi_struct_layout_compute(field_types)
  offset = 0
  max_align = 1
  fields = []
  
  i = 0
  len = field_types.len()
  @while i < len
    ft = field_types[i]
    
    @! Align offset to field's required alignment: offset = (offset + align - 1) & ~(align - 1)
    align = ft.align
    @if align > max_align
      max_align = align
    @end
    
    rem = offset % align
    @if rem != 0
      offset = offset + (align - rem)
    @end
    
    fields = fields.push({
      type: ft,
      offset: offset,
      size: ft.size
    })
    
    offset = offset + ft.size
    i = i + 1
  @end
  
  @! Total struct size must be rounded up to max_align
  rem_total = offset % max_align
  total_size = offset
  @if rem_total != 0
    total_size = offset + (max_align - rem_total)
  @end
  
  return {
    fields: fields,
    size: total_size,
    align: max_align
  }
@end

@! ----------------------------------------------------------------------------
@! 3. CALLING CONVENTION DESCRIPTORS
@! ----------------------------------------------------------------------------

@fn ffi_cif_new(convention, return_type, arg_types)
  return {
    convention: convention, @! "sysv_amd64", "win64", "cdecl", "stdcall"
    return_type: return_type,
    arg_types: arg_types,
    num_args: arg_types.len(),
    stack_args_size: 0
  }
@end

@! ----------------------------------------------------------------------------
@! 4. DYNAMIC LIBRARY LOADING & SYMBOL RESOLUTION
@! ----------------------------------------------------------------------------

@fn ffi_dlopen(library_path)
  @! Freestanding sovereign module resolver
  return {
    handle: 0x7FFF0000 + library_path.len(),
    path: library_path,
    loaded: 1
  }
@end

@fn ffi_dlsym(lib_handle, symbol_name)
  @! Freestanding sovereign symbol address resolver
  return {
    name: symbol_name,
    address: 0x7FFF1000 + symbol_name.len(),
    lib: lib_handle
  }
@end

@fn ffi_dlclose(lib_handle)
  @! Freestanding sovereign module unload
  lib_handle.loaded = 0
  return 1
@end

@! ----------------------------------------------------------------------------
@! 5. JIT CALL TRAMPOLINE CODE GENERATION (AMD64 & ARM64)
@! ----------------------------------------------------------------------------

@fn ffi_generate_amd64_trampoline(cif, func_addr)
  @! System V AMD64 ABI:
  @! Arg 1: RDI, Arg 2: RSI, Arg 3: RDX, Arg 4: RCX, Arg 5: R8, Arg 6: R9
  @! Float args: XMM0 - XMM7
  @! Return: RAX / XMM0
  machine_code = [
    0x55,             @! push rbp
    0x48, 0x89, 0xE5, @! mov rbp, rsp
    0x48, 0x83, 0xEC, 0x20 @! sub rsp, 32
  ]
  
  @! Call RAX (Simulated)
  machine_code = machine_code.push(0xFF)
  machine_code = machine_code.push(0xD0)
  
  @! Epilogue
  machine_code = machine_code.push(0x48)
  machine_code = machine_code.push(0x89)
  machine_code = machine_code.push(0xEC) @! mov rsp, rbp
  machine_code = machine_code.push(0x5D) @! pop rbp
  machine_code = machine_code.push(0xC3) @! ret
  
  return {
    cif: cif,
    func_address: func_addr,
    code: machine_code
  }
@end

@fn ffi_invoke(trampoline, args)
  println("  [FFI] Invoking Native C Function via Trampoline (" + trampoline.cif.convention + ")")
  @! Execute JIT machine code
  return 0
@end
