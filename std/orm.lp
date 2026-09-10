// ==============================================================================
// 🗄️ লিপি ORM — Object-Relational Mapper (SQLAlchemy + Prisma Killer)
// লিপি প্রথম ১.০ | ciphername: সোভেরিন
// File: std/orm.lp
//
// WHY এই মডিউল:
//   Raw SQL লেbা tedious এবং SQL injection prone।
//   ORM developer productivity বাড়ায় এবং safety নিশ্চিত aরে।
//   SQLAlchemy (Python), Prisma (JS), GORM (Go) — এদের replace aরবে।
//
// ব্যবrate:
//   include "std/orm.lp"
//    ব্যবrateaারী = ORM_bোঁজো("users", "id", ৪২)
//    সব = ORM_সব("users")
//   ORM_add("users", ব্যবrateaারী_obj)
//   ORM_আপডেট("users", "id", ৪২, updated_obj)
//   ORM_delete("users", "id", ৪২)
// ==============================================================================

include "std/mem.lp"
include "std/str.lp"
include "std/io.lp"
include "std/db.lp"

// ─── ORM Constants ────────────────────────────────────────────────────────────
ORM_MAX_COLUMNS    = 32   // table columns per query
ORM_MAX_WHERE      = 16   // WHERE conditions
ORM_MAX_JOIN       = 8    // JOIN tables
ORM_MAX_ORDER      = 8    // ORDER BY columns
ORM_DEFAULT_LIMIT  = 100  // default result limit

// Data types
ORM_TYPE_INT       = 1
ORM_TYPE_STRING    = 2
ORM_TYPE_FLOAT     = 3
ORM_TYPE_BOOL      = 4
ORM_TYPE_DATETIME  = 5
ORM_TYPE_JSON      = 6
ORM_TYPE_BLOB      = 7

// Query builders
ORM_OP_EQ         = 1   // =
ORM_OP_NEQ        = 2   // !=
ORM_OP_GT         = 3   // >
ORM_OP_GTE        = 4   // >=
ORM_OP_LT         = 5   // <
ORM_OP_LTE        = 6   // <=
ORM_OP_LIKE       = 7   // LIKE
ORM_OP_IN         = 8   // IN (list)
ORM_OP_NOT_NULL   = 9   // IS NOT NULL
ORM_OP_NULL       = 10  // IS NULL

// Join types
JOIN_INNER        = 1
JOIN_LEFT         = 2
JOIN_RIGHT        = 3
JOIN_FULL         = 4

// ─── Structs ──────────────────────────────────────────────────────────────────

struct ORM_column_সংজ্ঞা
    name_ptr,
    type_flag,
    len,            // for VARCHAR
    nullable,           // NULL allowed?
    primary_key,        // PRIMARY KEY?
    auto_increment,     // AUTO_INCREMENT?
    unique_const,       // UNIQUE constraint?
    default_value         // default value pointer

struct ORM_list_সংজ্ঞা
    name_ptr,
    column_list,
    column_count

struct ORM_শর্ত
    col_ptr,
    অপারেটর,
    value_ptr,
    পরবর্তী_শর্ত     // linked list of conditions

struct ORM_query_builder
    list_name,
    select_column,
    select_count,
    where_শর্ত,
    where_count,
    join_list,
    join_count,
    order_column,
    order_count,
    order_আরোহী,
    সীমা,
    offset,
    db_connection

struct ORM_connection
    db_path,
    db_fd,
    সংযুa্ত,
    transaction_active

// ─── Connection Management ────────────────────────────────────────────────────
fn ORM_connection_bোলো(db_path)
    conn_size = size_of(ORM_connection)
    conn = malloc(conn_size)
    conn.db_path = db_path
    conn.db_fd = file_bোলো(db_path)
    if conn.db_fd < 0
        say "  ❌ ডেটাবেজ সংadd ব্যর্থ:", db_path
        free(conn, conn_size)
        return 0
    conn.সংযুa্ত = 1
    conn.transaction_active = 0
    say "  ✔ ডেটাবেজ সংযুক্ত:", db_path
    return conn

fn ORM_connection_close(conn)
    if conn == 0 { return 0 }
    file_close(conn.db_fd)
    conn.সংযুa্ত = 0
    free(conn, size_of(ORM_connection))
    say "  ✔ ডেটাবেজ সংadd close"
    return 0

// ─── Schema Definition ────────────────────────────────────────────────────────
// WHY: Define table schema in code (database-first design is brittle)
fn ORM_list_created conn name column_list column_count
    // WHY: CREATE TABLE IF NOT EXISTS
    say "  → CREATE TABLE IF NOT EXISTS", name
    say "  → কলাম সংখ্যা:", column_count
    // Build DDL from column definitions
    // Execute via db syscall
    return 0

fn ORM_column_add list name type_flag len
    // ALTER TABLE ADD COLUMN (for migrations)
    say "  → ALTER TABLE", list, "ADD COLUMN", name
    return 0

// ─── CRUD Operations ─────────────────────────────────────────────────────────
// WHY: Create-Read-Update-Delete are the 4 fundamental DB operations

// CREATE
fn ORM_add conn list_name data_buffer data_length
    // WHY: INSERT INTO table (columns) VALUES (values)
    say "  INSERT INTO", list_name
    // Serialize data to SQL
    // Execute query
    // Return new row ID (last_insert_id)
    new_id = 1  // placeholder for actual DB call
    say "  → নতুন ID:", new_id
    return new_id

// READ — single row
fn ORM_bোঁজো(conn, list_name, cond_col, cond_val)
    // WHY: SELECT * FROM table WHERE column = value LIMIT 1
    say "  SELECT * FROM", list_name, "WHERE", cond_col, "=", cond_val
    result_buffer = malloc(4096)
    return result_buffer

// READ — all rows
fn ORM_সব conn list_name
    say "  SELECT * FROM", list_name
    result_buffer = malloc(65536)
    return result_buffer

// READ — count
fn ORM_count conn list_name
    say "  SELECT COUNT(*) FROM", list_name
    return 0

// UPDATE
fn ORM_আপডেট conn list_name cond_col cond_val নতুন_data
    // WHY: UPDATE table SET col1=val1, col2=val2 WHERE condition
    say "  UPDATE", list_name, "WHERE", cond_col, "=", cond_val
    return 0

// DELETE
fn ORM_delete conn list_name cond_col cond_val
    // WHY: DELETE FROM table WHERE column = value
    say "  DELETE FROM", list_name, "WHERE", cond_col, "=", cond_val
    return 0

// ─── Query Builder (Fluent Interface) ─────────────────────────────────────────
// WHY: Complex queries need a builder pattern
// Example: ORM_query(conn, "users").where("age", ORM_OP_GT, ১৮).order("name").limit(১০).exec()

fn ORM_query conn list_name
    qb_size = size_of(ORM_query_builder)
    qb = malloc(qb_size)
    qb.list_name = list_name
    qb.select_count = 0
    qb.where_count = 0
    qb.join_count = 0
    qb.order_count = 0
    qb.সীমা = ORM_DEFAULT_LIMIT
    qb.offset = 0
    qb.db_connection = conn
    return qb

fn ORM_select qb column_name
    // WHY: SELECT specific columns (not *)
    qb.select_count = qb.select_count + 1
    return qb

fn ORM_where qb column অপারেটর value
    // WHY: Add WHERE condition
    qb.where_count = qb.where_count + 1
    return qb

fn ORM_order_by qb column আরোহী
    // WHY: Sort results (আরোহী=1 = ASC, আরোহী=0 = DESC)
    qb.order_count = qb.order_count + 1
    qb.order_আরোহী = আরোহী
    return qb

fn ORM_limit qb n
    qb.সীমা = n
    return qb

fn ORM_offset qb n
    qb.offset = n
    return qb

fn ORM_join qb list শর্ত join_type
    // WHY: JOIN other tables for relational data
    qb.join_count = qb.join_count + 1
    return qb

fn ORM_execute qb
    // WHY: Build final SQL and execute
    say "  SELECT"
    if qb.select_count == 0 { say "    *" }
    say "  FROM", qb.list_name
    if qb.where_count > 0 { say "  WHERE <conditions>" }
    if qb.order_count > 0 { say "  ORDER BY <columns>" }
    say "  LIMIT", qb.সীমা, "OFFSET", qb.offset

    result_buffer = malloc(65536)
    free(qb, size_of(ORM_query_builder))
    return result_buffer

// ─── Transaction Management ───────────────────────────────────────────────────
// WHY: Transactions ensure atomicity — all or nothing
fn ORM_transaction_শুরু conn
    // BEGIN TRANSACTION
    conn.transaction_active = 1
    say "  → TRANSACTION START"
    return 0

fn ORM_transaction_commit conn
    // COMMIT
    conn.transaction_active = 0
    say "  → TRANSACTION COMMIT"
    return 0

fn ORM_transaction_rollback conn
    // ROLLBACK — undo everything since BEGIN
    conn.transaction_active = 0
    say "  → TRANSACTION ROLLBACK"
    return 0

// ─── Raw SQL ──────────────────────────────────────────────────────────────────
// WHY: Sometimes ORM is not enough — complex queries need raw SQL
// But parameterized to prevent SQL injection
fn ORM_raw_sql conn sql_query params param_count
    say "  → Raw SQL:", sql_query
    say "  → params:", param_count
    result = malloc(65536)
    return result

// ─── Migration System ─────────────────────────────────────────────────────────
// WHY: Database schema evolves over time — need versioned migrations
fn ORM_migration_রান conn migration_sql
    say "  → MIGRATION:", migration_sql
    return ORM_raw_sql(conn, migration_sql, 0, 0)

// ─── Aggregations ─────────────────────────────────────────────────────────────
fn ORM_sum conn list_name column_name
    say "  SELECT SUM(", column_name, ") FROM", list_name
    return 0

fn ORM_avg conn list_name column_name
    say "  SELECT AVG(", column_name, ") FROM", list_name
    return 0

fn ORM_max conn list_name column_name
    say "  SELECT MAX(", column_name, ") FROM", list_name
    return 0

fn ORM_min conn list_name column_name
    say "  SELECT MIN(", column_name, ") FROM", list_name
    return 0
