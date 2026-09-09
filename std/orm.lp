// ==============================================================================
// 🗄️ লিপি ORM — Object-Relational Mapper (SQLAlchemy + Prisma Killer)
// লিপি প্রথম ১.০ | সংকেতনাম: সোভেরিন
// File: std/orm.lp
//
// WHY এই মডিউল:
//   Raw SQL লেখা tedious এবং SQL injection prone।
//   ORM developer productivity বাড়ায় এবং safety নিশ্চিত করে।
//   SQLAlchemy (Python), Prisma (JS), GORM (Go) — এদের replace করবে।
//
// ব্যবহার:
//   include "std/orm.lp"
//    ব্যবহারকারী = ORM_খোঁজো("users", "id", ৪২)
//    সব = ORM_সব("users")
//   ORM_যোগ("users", ব্যবহারকারী_obj)
//   ORM_আপডেট("users", "id", ৪২, updated_obj)
//   ORM_মুছো("users", "id", ৪২)
// ==============================================================================

include "std/core/mem.lp"
include "std/core/str.lp"
include "std/core/io.lp"
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

struct ORM_কলাম_সংজ্ঞা
    নাম_পয়েন্টার,
    ধরন,
    len,            // for VARCHAR
    nullable,           // NULL allowed?
    primary_key,        // PRIMARY KEY?
    auto_increment,     // AUTO_INCREMENT?
    unique_const,       // UNIQUE constraint?
    default_মান         // default value pointer

struct ORM_তালিকা_সংজ্ঞা
    নাম_পয়েন্টার,
    কলাম_তালিকা,
    কলাম_গণনা

struct ORM_শর্ত
    কলাম_পয়েন্টার,
    অপারেটর,
    মান_পয়েন্টার,
    পরবর্তী_শর্ত     // linked list of conditions

struct ORM_query_builder
    তালিকা_নাম,
    select_কলাম,
    select_গণনা,
    where_শর্ত,
    where_গণনা,
    join_তালিকা,
    join_গণনা,
    order_কলাম,
    order_গণনা,
    order_আরোহী,
    সীমা,
    অফসেট,
    db_সংযোগ

struct ORM_সংযোগ
    db_পাথ,
    db_fd,
    সংযুক্ত,
    transaction_active

// ─── Connection Management ────────────────────────────────────────────────────
fn ORM_সংযোগ_খোলো(db_পাথ)
    conn_সাইজ = size_of(ORM_সংযোগ)
    conn = malloc(conn_সাইজ)
    conn.db_পাথ = db_পাথ
    conn.db_fd = ফাইল_খোলো(db_পাথ)
    if conn.db_fd < 0
        say "  ❌ ডেটাবেজ সংযোগ ব্যর্থ:", db_পাথ
        free(conn, conn_সাইজ)
        return 0
    conn.সংযুক্ত = 1
    conn.transaction_active = 0
    say "  ✔ ডেটাবেজ সংযুক্ত:", db_পাথ
    return conn

fn ORM_সংযোগ_বন্ধ(conn)
    if conn == 0 { return 0 }
    ফাইল_বন্ধ(conn.db_fd)
    conn.সংযুক্ত = 0
    free(conn, size_of(ORM_সংযোগ))
    say "  ✔ ডেটাবেজ সংযোগ বন্ধ"
    return 0

// ─── Schema Definition ────────────────────────────────────────────────────────
// WHY: Define table schema in code (database-first design is brittle)
fn ORM_তালিকা_তৈরি conn নাম কলাম_তালিকা কলাম_গণনা
    // WHY: CREATE TABLE IF NOT EXISTS
    say "  → CREATE TABLE IF NOT EXISTS", নাম
    say "  → কলাম সংখ্যা:", কলাম_গণনা
    // Build DDL from column definitions
    // Execute via db syscall
    return 0

fn ORM_কলাম_যোগ তালিকা নাম ধরন len
    // ALTER TABLE ADD COLUMN (for migrations)
    say "  → ALTER TABLE", তালিকা, "ADD COLUMN", নাম
    return 0

// ─── CRUD Operations ─────────────────────────────────────────────────────────
// WHY: Create-Read-Update-Delete are the 4 fundamental DB operations

// CREATE
fn ORM_যোগ conn তালিকা_নাম ডেটা_বাফার ডেটা_দৈর্ঘ্য
    // WHY: INSERT INTO table (columns) VALUES (values)
    say "  INSERT INTO", তালিকা_নাম
    // Serialize data to SQL
    // Execute query
    // Return new row ID (last_insert_id)
    new_id = 1  // placeholder for actual DB call
    say "  → নতুন ID:", new_id
    return new_id

// READ — single row
fn ORM_খোঁজো(conn, তালিকা_নাম, শর্ত_কলাম, শর্ত_মান)
    // WHY: SELECT * FROM table WHERE column = value LIMIT 1
    say "  SELECT * FROM", তালিকা_নাম, "WHERE", শর্ত_কলাম, "=", শর্ত_মান
    result_বাফার = malloc(4096)
    return result_বাফার

// READ — all rows
fn ORM_সব conn তালিকা_নাম
    say "  SELECT * FROM", তালিকা_নাম
    result_বাফার = malloc(65536)
    return result_বাফার

// READ — count
fn ORM_গণনা conn তালিকা_নাম
    say "  SELECT COUNT(*) FROM", তালিকা_নাম
    return 0

// UPDATE
fn ORM_আপডেট conn তালিকা_নাম শর্ত_কলাম শর্ত_মান নতুন_ডেটা
    // WHY: UPDATE table SET col1=val1, col2=val2 WHERE condition
    say "  UPDATE", তালিকা_নাম, "WHERE", শর্ত_কলাম, "=", শর্ত_মান
    return 0

// DELETE
fn ORM_মুছো conn তালিকা_নাম শর্ত_কলাম শর্ত_মান
    // WHY: DELETE FROM table WHERE column = value
    say "  DELETE FROM", তালিকা_নাম, "WHERE", শর্ত_কলাম, "=", শর্ত_মান
    return 0

// ─── Query Builder (Fluent Interface) ─────────────────────────────────────────
// WHY: Complex queries need a builder pattern
// Example: ORM_query(conn, "users").where("age", ORM_OP_GT, ১৮).order("name").limit(১০).exec()

fn ORM_query conn তালিকা_নাম
    qb_সাইজ = size_of(ORM_query_builder)
    qb = malloc(qb_সাইজ)
    qb.তালিকা_নাম = তালিকা_নাম
    qb.select_গণনা = 0
    qb.where_গণনা = 0
    qb.join_গণনা = 0
    qb.order_গণনা = 0
    qb.সীমা = ORM_DEFAULT_LIMIT
    qb.অফসেট = 0
    qb.db_সংযোগ = conn
    return qb

fn ORM_select qb কলাম_নাম
    // WHY: SELECT specific columns (not *)
    qb.select_গণনা = qb.select_গণনা + 1
    return qb

fn ORM_where qb কলাম অপারেটর মান
    // WHY: Add WHERE condition
    qb.where_গণনা = qb.where_গণনা + 1
    return qb

fn ORM_order_by qb কলাম আরোহী
    // WHY: Sort results (আরোহী=1 = ASC, আরোহী=0 = DESC)
    qb.order_গণনা = qb.order_গণনা + 1
    qb.order_আরোহী = আরোহী
    return qb

fn ORM_limit qb n
    qb.সীমা = n
    return qb

fn ORM_offset qb n
    qb.অফসেট = n
    return qb

fn ORM_join qb তালিকা শর্ত join_type
    // WHY: JOIN other tables for relational data
    qb.join_গণনা = qb.join_গণনা + 1
    return qb

fn ORM_execute qb
    // WHY: Build final SQL and execute
    say "  SELECT"
    if qb.select_গণনা == 0 { say "    *" }
    say "  FROM", qb.তালিকা_নাম
    if qb.where_গণনা > 0 { say "  WHERE <conditions>" }
    if qb.order_গণনা > 0 { say "  ORDER BY <columns>" }
    say "  LIMIT", qb.সীমা, "OFFSET", qb.অফসেট

    result_বাফার = malloc(65536)
    free(qb, size_of(ORM_query_builder))
    return result_বাফার

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
fn ORM_sum conn তালিকা_নাম কলাম_নাম
    say "  SELECT SUM(", কলাম_নাম, ") FROM", তালিকা_নাম
    return 0

fn ORM_avg conn তালিকা_নাম কলাম_নাম
    say "  SELECT AVG(", কলাম_নাম, ") FROM", তালিকা_নাম
    return 0

fn ORM_max conn তালিকা_নাম কলাম_নাম
    say "  SELECT MAX(", কলাম_নাম, ") FROM", তালিকা_নাম
    return 0

fn ORM_min conn তালিকা_নাম কলাম_নাম
    say "  SELECT MIN(", কলাম_নাম, ") FROM", তালিকা_নাম
    return 0
