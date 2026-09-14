// ==============================================================================
// 👑 LIPI EXAMPLE: DATABASE ENGINE & WAL (examples/database_demo.lp)
// ⚡ 100% Pure Lipi First 1.0.0
// ==============================================================================

struct Database
    keys
    vals
    wal

fn db_new
    db = Database()
    db.keys = list()
    db.vals = list()
    db.wal = list()
    return db

fn db_set db key value
    log_entry = "SET " + key + "=" + value
    push(db.wal, log_entry)
    
    idx = -1
    i = 0
    klen = len(db.keys)
    while i < klen
        if get(db.keys, i) == key
            idx = i
        i = i + 1
    
    if idx == -1
        push(db.keys, key)
        push(db.vals, value)
    else
        list_set(db.vals, idx, value)
    
    say "[WAL] " + log_entry
    return 1

fn db_get db key
    i = 0
    klen = len(db.keys)
    while i < klen
        if get(db.keys, i) == key
            return get(db.vals, i)
        i = i + 1
    return "(not found)"

fn db_delete db key
    log_entry = "DEL " + key
    push(db.wal, log_entry)
    
    i = 0
    klen = len(db.keys)
    while i < klen
        if get(db.keys, i) == key
            list_set(db.keys, i, "")
            list_set(db.vals, i, "")
            say "[WAL] " + log_entry
            return 1
        i = i + 1
    return 0

fn db_print db
    say "=== Database Contents ==="
    i = 0
    klen = len(db.keys)
    while i < klen
        k = get(db.keys, i)
        if len(k) > 0
            v = get(db.vals, i)
            say "  " + k + " => " + v
        i = i + 1
    say ""

fn main
    say "=== Lipi Database Engine Simulation ==="
    say ""
    
    db = db_new()
    
    say "-- Inserting Records --"
    db_set(db, "user:1001", "Shafiullah")
    db_set(db, "user:1002", "Ada Lovelace")
    db_set(db, "user:1003", "Alan Turing")
    db_set(db, "config:mode", "production")
    db_set(db, "config:threads", "8")
    say ""
    
    db_print(db)
    
    say "-- Querying Records --"
    say "user:1001 = " + db_get(db, "user:1001")
    say "user:1002 = " + db_get(db, "user:1002")
    say "user:9999 = " + db_get(db, "user:9999")
    say ""
    
    say "-- Updating Records --"
    db_set(db, "user:1001", "Shafiullah (Lead Architect)")
    say "user:1001 after update = " + db_get(db, "user:1001")
    say ""
    
    say "-- Deleting Record --"
    db_delete(db, "user:1003")
    say "user:1003 after delete = " + db_get(db, "user:1003")
    say ""
    
    db_print(db)
    
    say "Total WAL entries: " + str(len(db.wal))
    say "Database demo complete."
    return 0

main()
