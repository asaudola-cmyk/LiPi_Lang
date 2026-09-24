import "universe/fs/lipifs"

@fn main()
  println("--- LipiFS CoW File System Test ---")

  // 1. Create LipiFS volume
  fs = lipifs_create(0 - 1, 1024)
  @if fs.total_blocks_count != 1024 || fs.free_block_pointer != 1
    println("FAIL: lipifs_create")
    return 1
  @end
  println("PASS: lipifs_create")

  // 2. Write file via Copy-on-Write
  fs = lipifs_write_file_cow(fs, "manifest.lp", "sovereign_first_100")
  @if lipifs_file_exists(fs, "manifest.lp") != 1
    println("FAIL: lipifs_file_exists")
    return 1
  @end
  println("PASS: lipifs_write_file_cow & file_exists")

  // 3. Read file content
  content = lipifs_read_file(fs, "manifest.lp")
  @if content != "sovereign_first_100"
    println("FAIL: lipifs_read_file")
    return 1
  @end
  println("PASS: lipifs_read_file")

  // 4. Write second file and verify list
  fs = lipifs_write_file_cow(fs, "kernel.lp", "pure_silicon_kernel")
  files = lipifs_list_files(fs)
  @if len(files) != 2
    println("FAIL: lipifs_list_files")
    return 1
  @end
  println("PASS: lipifs_list_files")

  // 5. CoW overwrite of existing file (generation increments, blocks preserved)
  gen_before = fs.active_root_generation
  fs = lipifs_write_file_cow(fs, "manifest.lp", "updated_sovereign_content")
  updated_content = lipifs_read_file(fs, "manifest.lp")
  @if updated_content != "updated_sovereign_content" || fs.active_root_generation <= gen_before
    println("FAIL: lipifs_write_file_cow overwrite")
    return 1
  @end
  println("PASS: lipifs_write_file_cow overwrite")

  // 6. Delete file via CoW
  fs = lipifs_delete_file_cow(fs, "kernel.lp")
  @if lipifs_file_exists(fs, "kernel.lp") != 0
    println("FAIL: lipifs_delete_file_cow")
    return 1
  @end
  println("PASS: lipifs_delete_file_cow")

  // 7. Verify block integrity
  verified = lipifs_verify_and_heal_block(fs, 1, "test")
  @if verified != 1
    println("FAIL: lipifs_verify_and_heal_block")
    return 1
  @end
  println("PASS: lipifs_verify_and_heal_block")

  println("=== ALL LIPIFS TESTS PASSED ===")
  return 0
@end
