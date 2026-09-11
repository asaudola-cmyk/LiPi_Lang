@! NATIVE MAYA DATABASE IMPLEMENTATION (Key-Value Store)
@! Features: In-memory structured storage with string matching.

@fn db_init()
  @! Allocate 1MB for the database (header + entries + string arena)
  db_ptr = sys_mmap(0, 1048576, 3, 34, 0 - 1, 0)
  
  @! Header: Entry count = 0
  sys_poke(db_ptr + 0, 0)
  
  @! Header: Arena Head = 65536 (Start string arena at 64KB offset)
  sys_poke(db_ptr + 8, db_ptr + 65536)
  
  return db_ptr
@end

@fn db_alloc_string(db_ptr, str_ptr)
  @! Find string length
  len = 0
  @while sys_peek8(str_ptr + len) != 0
    len = len + 1
  @end
  
  @! Allocate memory in the DB arena
  arena_head = sys_peek(db_ptr + 8)
  
  @! Copy string
  i = 0
  @while i < len
    sys_poke8(arena_head + i, sys_peek8(str_ptr + i))
    i = i + 1
  @end
  sys_poke8(arena_head + len, 0)
  
  @! Update arena head
  sys_poke(db_ptr + 8, arena_head + len + 1)
  
  return arena_head
@end

@fn db_streq(str1, str2)
  i = 0
  @while 1 == 1
    c1 = sys_peek8(str1 + i)
    c2 = sys_peek8(str2 + i)
    @if c1 != c2
      return 0
    @end
    @if c1 == 0
      return 1
    @end
    i = i + 1
  @end
  return 0
@end

@fn db_set(db_ptr, key_ptr, val_ptr)
  entry_count = sys_peek(db_ptr + 0)
  
  @! Check if key already exists
  i = 0
  @while i < entry_count
    entry_addr = db_ptr + 64 + i * 32
    exist_key = sys_peek(entry_addr + 0)
    
    @if db_streq(exist_key, key_ptr) == 1
      @! Update existing value
      new_val_ptr = db_alloc_string(db_ptr, val_ptr)
      sys_poke(entry_addr + 8, new_val_ptr)
      return 1
    @end
    i = i + 1
  @end
  
  @! Create new entry
  new_key_ptr = db_alloc_string(db_ptr, key_ptr)
  new_val_ptr = db_alloc_string(db_ptr, val_ptr)
  
  new_entry_addr = db_ptr + 64 + entry_count * 32
  sys_poke(new_entry_addr + 0, new_key_ptr)
  sys_poke(new_entry_addr + 8, new_val_ptr)
  
  sys_poke(db_ptr + 0, entry_count + 1)
  
  return 1
@end

@fn db_get(db_ptr, key_ptr)
  entry_count = sys_peek(db_ptr + 0)
  
  i = 0
  @while i < entry_count
    entry_addr = db_ptr + 64 + i * 32
    exist_key = sys_peek(entry_addr + 0)
    
    @if db_streq(exist_key, key_ptr) == 1
      return sys_peek(entry_addr + 8)
    @end
    i = i + 1
  @end
  
  return 0
@end
