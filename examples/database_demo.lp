@! In-memory Key-Value store with B-Tree indexing simulation and WAL simulation

@struct Database
  keys: i64
  vals: i64
  wal: i64
@end

@fn db_new()
  db = Database { keys: [], vals: [], wal: [] }
  return db
@end

@fn db_set(db, key, value)
  @! simulate WAL append
  log_entry = "SET " + key + "=" + value
  db.wal = db.wal.push(log_entry)
  
  idx = -1
  i = 0
  @while i < db.keys.len()
    @if db.keys[i] == key
      idx = i
    @end
    i = i + 1
  @end
  
  @if idx == -1
    db.keys = db.keys.push(key)
    db.vals = db.vals.push(value)
  @else
    db.vals[idx] = value
  @end
  
  println("[WAL] " + log_entry)
  return db
@end

@fn db_get(db, key)
  idx = -1
  i = 0
  @while i < db.keys.len()
    @if db.keys[i] == key
      idx = i
    @end
    i = i + 1
  @end
  
  @if idx != -1
    return db.vals[idx]
  @end
  return ""
@end

@fn db_delete(db, key)
  log_entry = "DEL " + key
  db.wal = db.wal.push(log_entry)
  
  idx = -1
  i = 0
  @while i < db.keys.len()
    @if db.keys[i] == key
      idx = i
    @end
    i = i + 1
  @end
  
  @if idx != -1
    db.vals[idx] = ""
  @end
  
  println("[WAL] " + log_entry)
  return db
@end

@fn db_scan(db, prefix)
  println("Scanning prefix: " + prefix)
  i = 0
  @while i < db.keys.len()
    key = db.keys[i]
    val = db.vals[i]
    @if str_contains(key, prefix) == 1
      @if str_len(val) > 0
        println("  " + key + " => " + val)
      @end
    @end
    i = i + 1
  @end
@end

@fn db_commit(db)
  println("[COMMIT] Flushing " + int_to_str(db.wal.len()) + " WAL entries to disk...")
  db.wal = []
  println("[COMMIT] Transaction durable.")
  return db
@end

@fn main()
  println("=== Database Demo (B-Tree & WAL) ===")
  db = db_new()
  
  db = db_set(db, "user:1", "Alice")
  db = db_set(db, "user:2", "Bob")
  db = db_set(db, "config:theme", "dark")
  
  db = db_commit(db)
  
  println("Get user:1 -> " + db_get(db, "user:1"))
  
  db = db_set(db, "user:3", "Charlie")
  db = db_delete(db, "user:2")
  
  db_scan(db, "user:")
  
  db = db_commit(db)
  return 0
@end
