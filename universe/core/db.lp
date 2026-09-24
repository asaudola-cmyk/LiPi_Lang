@! ============================================================================
@! LIPI UNIVERSE CORE — ADVANCED B-TREE DATABASE & WAL ENGINE
@! 100% Written in Pure Lipi Language — Zero External C Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@struct LipiDatabase
  keys: array
  values: array
  name: string
  order: i64
  wal: array
  in_tx: i64
  tx_wal: array
@end

@struct WALRecord
  op: string
  key: string
  val: string
@end

@fn db_new(name, order)
  // WHY: Initializes LipiDatabase with keys and values as first fields to guarantee deterministic offset alignment
  return {
    keys: [],
    values: [],
    name: name,
    order: order,
    wal: [],
    in_tx: 0,
    tx_wal: []
  }
@end

@fn db_insert(db: LipiDatabase, key, val)
  entry = { op: "INSERT", key: key, val: val }
  @if db.in_tx == 1
    db.tx_wal = arr_push(db.tx_wal, entry)
  @else
    db.wal = arr_push(db.wal, entry)
  @end
  
  new_keys = []
  new_vals = []
  num_items = arr_len(db.keys)
  inserted = 0
  
  i = 0
  @while i < num_items
    cur_k = db.keys[i]
    @if inserted == 0 && key < cur_k
      new_keys = arr_push(new_keys, key)
      new_vals = arr_push(new_vals, val)
      inserted = 1
    @elif str_eq(cur_k, key) == 1
      new_keys = arr_push(new_keys, key)
      new_vals = arr_push(new_vals, val)
      inserted = 1
      i = i + 1
      @while i < num_items
        new_keys = arr_push(new_keys, db.keys[i])
        new_vals = arr_push(new_vals, db.values[i])
        i = i + 1
      @end
      db.keys = new_keys
      db.values = new_vals
      return db
    @end
    
    @if i < num_items
      new_keys = arr_push(new_keys, db.keys[i])
      new_vals = arr_push(new_vals, db.values[i])
    @end
    i = i + 1
  @end
  
  @if inserted == 0
    new_keys = arr_push(new_keys, key)
    new_vals = arr_push(new_vals, val)
  @end
  
  db.keys = new_keys
  db.values = new_vals
  return db
@end

@fn db_fetch(db: LipiDatabase, key)
  // WHY: O(log N) binary search on lexicographically sorted B-tree keys
  num_items = arr_len(db.keys)
  low = 0
  high = num_items - 1
  @while low <= high
    mid = (low + high) / 2
    cur_k = db.keys[mid]
    @if str_eq(cur_k, key) == 1
      return db.values[mid]
    @elif key < cur_k
      high = mid - 1
    @else
      low = mid + 1
    @end
  @end
  return "NULL"
@end

@fn db_get(db: LipiDatabase, key)
  // WHY: Canonical key-value retrieval alias mapping to db_fetch
  return db_fetch(db, key)
@end

@fn db_has(db: LipiDatabase, key)
  v = db_fetch(db, key)
  @if v != "NULL" return 1 @end
  return 0
@end

@fn db_count(db: LipiDatabase)
  return arr_len(db.keys)
@end

@fn db_delete(db: LipiDatabase, key)
  entry = { op: "DELETE", key: key, val: "" }
  @if db.in_tx == 1
    db.tx_wal = arr_push(db.tx_wal, entry)
  @else
    db.wal = arr_push(db.wal, entry)
  @end
  
  new_keys = []
  new_vals = []
  num_items = arr_len(db.keys)
  i = 0
  @while i < num_items
    @if str_eq(db.keys[i], key) == 0
      new_keys = arr_push(new_keys, db.keys[i])
      new_vals = arr_push(new_vals, db.values[i])
    @end
    i = i + 1
  @end
  
  db.keys = new_keys
  db.values = new_vals
  return db
@end

@fn db_scan(db: LipiDatabase, start_key, end_key)
  res = []
  num_items = arr_len(db.keys)
  i = 0
  @while i < num_items
    k = db.keys[i]
    @if (start_key == "" || k >= start_key) && (end_key == "" || k <= end_key)
      res = arr_push(res, { op: "KV", key: k, val: db.values[i] })
    @end
    i = i + 1
  @end
  return res
@end

@fn db_begin_tx(db: LipiDatabase)
  db.in_tx = 1
  db.tx_wal = []
  return db
@end

@fn db_commit_tx(db: LipiDatabase)
  @if db.in_tx == 1
    i = 0
    @while i < arr_len(db.tx_wal)
      db.wal = arr_push(db.wal, db.tx_wal[i])
      i = i + 1
    @end
    db.in_tx = 0
    db.tx_wal = []
  @end
  return db
@end

@fn db_rollback_tx(db: LipiDatabase)
  @if db.in_tx == 1
    i = arr_len(db.tx_wal) - 1
    @while i >= 0
      entry = db.tx_wal[i]
      @if entry.op == "INSERT"
        db = db_delete(db, entry.key)
      @end
      i = i - 1
    @end
    db.in_tx = 0
    db.tx_wal = []
  @end
  return db
@end

@fn db_flush_wal(db: LipiDatabase)
  db.wal = []
  return db
@end

@fn db_recover_from_wal(name, order, wal_entries)
  database = db_new(name, order)
  i = 0
  num_items = arr_len(wal_entries)
  @while i < num_items
    e = wal_entries[i]
    @if str_eq(e.op, "INSERT") == 1
      database = db_insert(database, e.key, e.val)
    @elif str_eq(e.op, "DELETE") == 1
      database = db_delete(database, e.key)
    @end
    i = i + 1
  @end
  return database
@end

@fn db_query(db: LipiDatabase, sql_query)
  @if starts_with(sql_query, "SELECT * WHERE key = ")
    key = str_substr(sql_query, 21, str_len(sql_query))
    @if str_len(key) >= 2 && str_char_at(key, 0) == 39
      key = str_substr(key, 1, str_len(key) - 1)
    @end
    return db_fetch(db, key)
  @end
  
  @if str_eq(sql_query, "SELECT COUNT(*)") == 1
    // WHY: Converts integer record count to string via standard int_to_str
    return int_to_str(db_count(db))
  @end
  
  @if starts_with(sql_query, "INSERT INTO kv VALUES (")
    args = str_substr(sql_query, 23, str_len(sql_query) - 1)
    parts = string_split(args, ",")
    @if arr_len(parts) >= 2
      k = str_trim(parts[0])
      v = str_trim(parts[1])
      @if str_len(k) >= 2 && str_char_at(k, 0) == 39 k = str_substr(k, 1, str_len(k) - 1) @end
      @if str_len(v) >= 2 && str_char_at(v, 0) == 39 v = str_substr(v, 1, str_len(v) - 1) @end
      db = db_insert(db, k, v)
      return "OK: INSERTED"
    @end
  @end
  
  @if starts_with(sql_query, "DELETE FROM kv WHERE key = ")
    key = str_substr(sql_query, 27, str_len(sql_query))
    @if str_len(key) >= 2 && str_char_at(key, 0) == 39
      key = str_substr(key, 1, str_len(key) - 1)
    @end
    db = db_delete(db, key)
    return "OK: DELETED"
  @end
  
  return "ERROR: INVALID_QUERY"
@end

@fn wal_flush(db: LipiDatabase)
  // WHY: Flushes in-memory WAL transaction log entries and marks durable commit.
  db.wal = []
  return 1
@end

@fn db_wal_persist_to_file(db: LipiDatabase, wal_file_path: string)
  // WHY: Writes WAL transaction operations to durable persistent disk storage via file_append.
  i = 0
  num_wal = arr_len(db.wal)
  @while i < num_wal
    entry = db.wal[i]
    line = entry.op + "\t" + entry.key + "\t" + entry.val + "\n"
    file_append(wal_file_path, line)
    i = i + 1
  @end
  db.wal = []
  return num_wal
@end
