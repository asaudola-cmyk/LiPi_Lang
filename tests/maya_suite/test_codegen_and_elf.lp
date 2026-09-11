import "compiler/backend/maya_ir"
import "compiler/backend/x86_64/codegen"
import "compiler/backend/elf_writer"

@fn main()
  println("================================================================")
  println("TESTING PURE MAYA CODEGEN & ELF64 EMISSION PIPELINE")
  println("================================================================")

  mod = ir_module_new("sovereign_test_module")
  
  @! Create main function
  f_main = ir_function_new("main", [], ir_type_i64())
  
  @! Add instruction: RET 42
  ret_val = ir_val_const_int(42, ir_type_i64())
  inst_ret = ir_inst_ret(ret_val, ir_type_i64())
  
  entry_bb = ir_block_add_inst(f_main.blocks[0], inst_ret)
  f_main.blocks = [entry_bb]
  mod = ir_module_add_function(mod, f_main)
  
  println("Lowering IR module to x86-64 machine code...")
  x86_res = x86_codegen_module(mod)
  println("Codegen complete:")
  println("  Text bytes count: " + x86_res.text_bytes.len().to_str())
  println("  Rodata bytes count: " + x86_res.rodata_bytes.len().to_str())
  println("  Entry offset: " + x86_res.entry_offset.to_str())
  
  out_path = "/tmp/maya_pure_elf_test"
  println("Writing ELF64 executable to " + out_path + "...")
  elf_res = elf_write_executable(x86_res, out_path)
  
  println("ELF Writer Result:")
  println("  Success: " + elf_res.ew_success.to_str())
  println("  File size: " + elf_res.ew_file_size.to_str())
  println("  Entry vaddr: " + elf_res.ew_entry_vaddr.to_str())
  @if elf_res.ew_error_msg != ""
    println("  Error: " + elf_res.ew_error_msg)
  @end

  return 0
@end
