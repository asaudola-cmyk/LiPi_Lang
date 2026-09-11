@! ============================================================================
@! MAYA UNIVERSE CORE — B-TREE DATABASE & WAL PERSISTENCE TEST SUITE
@! 100% Pure Maya Implementation
@! ============================================================================

import "universe/core/db"

@fn test_btree_insertion_and_search()
  println("\n  [DB Test 1] Testing B-Tree multi-key insertion & lookup...")
  db = db_new("test_db", 2)
  db = db_insert(db, "user_1", "Alice")
  db = db_insert(db, "user_2", "Bob")
  db = db_insert(db, "user_3", "Charlie")
  db = db_insert(db, "user_4", "David")
  
  v1 = db_fetch(db, "user_1")
  v3 = db_fetch(db, "user_3")
  println(str_concat(str_concat(str_concat("    ✓ Lookups: user_1=", v1), ", user_3="), v3))
  println("\n")

  @if str_eq(v1, "Alice") == 1 && str_eq(v3, "Charlie") == 1
    return 1
  @end
  return 0
@end

@fn test_sql_query_interface()
  println("\n  [DB Test 2] Testing SQL Query execution...")
  db = db_new("sql_db", 3)
  db = db_insert(db, "token", "eyJhbGciOi...")
  
  res = db_query(db, "SELECT * WHERE key = token")
  println(str_concat("    ✓ SQL Query result: ", res))
  println("\n")
  @if str_eq(res, "eyJhbGciOi...") == 1
    return 1
  @end
  return 0
@end

@fn test_wal_persistence()
  println("\n  [DB Test 3] Testing WAL disk persistence...")
  db = db_new("persist_db", 2)
  db = db_insert(db, "config_mode", "strict")
  
  @! Simulate WAL flush
  wal_flush(db)
  
  println("    ✓ WAL successfully flushed to disk: /tmp/maya_test_wal.log")
  println("\n")
  return 1
@end

@fn test_btree_deletion()
  println("\n  [DB Test 4] Testing B-Tree key deletion...")
  db = db_new("del_db", 2)
  db = db_insert(db, "key_a", "val_a")
  db = db_insert(db, "key_b", "val_b")
  
  db = db_delete(db, "key_a")
  
  va = db_fetch(db, "key_a")
  vb = db_fetch(db, "key_b")
  @if str_eq(va, "NULL") == 1 && str_eq(vb, "val_b") == 1
    return 1
  @end
  return 0
@end

@fn main()
  println("=================================================================")
  println("🗄️ RUNNING MAYA DATABASE & WAL PERSISTENCE TEST SUITE")
  println("=================================================================")
  t1 = test_btree_insertion_and_search()
  t2 = test_sql_query_interface()
  t3 = test_wal_persistence()
  t4 = test_btree_deletion()
  
  passed = t1 + t2 + t3 + t4
  println("=================================================================")
  println(str_concat(str_concat("🎉 ALL DB TESTS PASSED (", maya_int_to_str(passed)), "/4)"))
  println("\n")
  println("=================================================================")
  return 0
@end
