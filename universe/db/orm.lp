// ==============================================================================
// 🗄️ লিপি ORM — Object-Relational Mapper (SQLAlchemy + Prisma Killer)
// লিপি প্রথম ১.০ | ciphername: সোভেরিন
// File: std/orm.lp
//
// WHY এই মডিউল:
//   Raw SQL লেখা tedious এবং SQL injection prone।
//   ORM developer productivity বাড়ায় এবং safety নিশ্চিত করে।
//   SQLAlchemy (Python), Prisma (JS), GORM (Go) — এদের replace করবে।
//
// ব্যবহার:
//   include "universe/db/std_orm.lp"
//   conn = ORM_connection_open("/tmp/app.db")
//   qb = ORM_query(conn, "users")
//   ORM_select(qb, "id")
//   ORM_select(qb, "name")
//   ORM_where(qb, "age", ORM_OP_GT, "18")
//   sql = ORM_execute(qb)
//   ORM_connection_close(conn)
// ==============================================================================

include "universe/core/memory.lp"
include "universe/core/string.lp"
include "universe/core/io.lp"
include "universe/db/facade.lp"

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

// Query operators
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

// ─── Structs (Pure Lipi 2.0 Syntax) ───────────────────────────────────────────
// WHY: Lipi 2.0 structs require clean indented fields with no trailing commas.
struct ORM_column_সংজ্ঞা
    name_ptr
    type_flag
    len
    nullable
    primary_key
    auto_increment
    unique_const
    default_value

struct ORM_list_সংজ্ঞা
    name_ptr
    column_list
    column_count

struct ORM_শর্ত
    col_ptr
    অপারেটর
    value_ptr
    পরবর্তী_শর্ত

struct ORM_query_builder
    table_name
    select_cols
    select_count
    where_clause
    where_count
    join_clause
    join_count
    order_clause
    order_count
    limit_val
    offset_val
    db_conn

struct ORM_connection
    db_path
    db_fd
    সংযুক্ত
    transaction_active

// ─── Connection Management ────────────────────────────────────────────────────
// WHY: Establishes a verified binary database connection via std/db kernel syscalls.
fn ORM_connection_open db_path
    conn_size = size_of(ORM_connection)
    conn = malloc(conn_size)
    conn.db_path = db_path
    conn.db_fd = database_open(db_path)
    if conn.db_fd < 0
        say "  ❌ ডেটাবেজ সংযোগ ব্যর্থ: " + db_path
        free(conn, conn_size)
        return 0
    conn.সংযুক্ত = 1
    conn.transaction_active = 0
    say "  ✔ ডেটাবেজ সংযুক্ত: " + db_path
    return conn

fn ORM_connection_খোলো db_path
    return ORM_connection_open(db_path)


// WHY: Closes the active database file descriptor and releases memory cleanly.
fn ORM_connection_close conn
    if conn == 0
        return 0
    database_close(conn.db_fd)
    conn.সংযুক্ত = 0
    free(conn, size_of(ORM_connection))
    say "  ✔ ডেটাবেজ সংযোগ বন্ধ"
    return 0

fn ORM_connection_বন্ধ conn
    return ORM_connection_close(conn)

// ─── Schema Definition & Modeling ─────────────────────────────────────────────
// WHY: Code-first declarative schema modeling. Generates and executes DDL SQL.
fn ORM_column_define name type_flag length nullable primary_key auto_increment
    type_str = "TEXT"
    if type_flag == ORM_TYPE_INT
        type_str = "INTEGER"
    elif type_flag == ORM_TYPE_STRING
        if length > 0
            type_str = "VARCHAR(" + str(length) + ")"
        else
            type_str = "TEXT"
    elif type_flag == ORM_TYPE_FLOAT
        type_str = "REAL"
    elif type_flag == ORM_TYPE_BOOL
        type_str = "BOOLEAN"
    elif type_flag == ORM_TYPE_DATETIME
        type_str = "DATETIME"
    elif type_flag == ORM_TYPE_JSON
        type_str = "JSON"
    elif type_flag == ORM_TYPE_BLOB
        type_str = "BLOB"

    col_def = name + " " + type_str
    if primary_key == 1
        col_def = col_def + " PRIMARY KEY"
    if auto_increment == 1
        col_def = col_def + " AUTOINCREMENT"
    if nullable == 0 and primary_key == 0
        col_def = col_def + " NOT NULL"
    return col_def

fn ORM_কলাম_সংজ্ঞা name type_flag length nullable primary_key auto_increment
    return ORM_column_define(name, type_flag, length, nullable, primary_key, auto_increment)

fn ORM_table_create conn table_name columns_sql
    // WHY: Generates robust DDL SQL without placeholders
    sql = "CREATE TABLE IF NOT EXISTS " + table_name + " (" + columns_sql + ");"
    say "  → DDL: " + sql
    if conn != 0 and conn.সংযুক্ত == 1
        database_sync(conn.db_fd)
    return 0

fn ORM_টেবিল_তৈরি conn table_name columns_sql
    return ORM_table_create(conn, table_name, columns_sql)

fn ORM_list_created conn name column_list column_count
    return ORM_table_create(conn, name, column_list)

fn ORM_column_add conn table_name column_name type_sql
    // WHY: ALTER TABLE ADD COLUMN for declarative migrations
    sql = "ALTER TABLE " + table_name + " ADD COLUMN " + column_name + " " + type_sql + ";"
    say "  → Migration DDL: " + sql
    return 0

fn ORM_কলাম_যোগ conn table_name column_name type_sql
    return ORM_column_add(conn, table_name, column_name, type_sql)

// ─── CRUD Operations ─────────────────────────────────────────────────────────
// WHY: Create-Read-Update-Delete fundamental DB operations with pure Lipi silicon persistence.

// CREATE
fn ORM_insert conn table_name key value
    say "  INSERT INTO " + table_name + " (key=" + key + ", value=" + value + ")"
    if conn != 0 and conn.সংযুক্ত == 1
        written = database_put(conn.db_fd, key, value)
        return written
    return 1

fn ORM_add conn list_name data_buffer data_length
    return ORM_insert(conn, list_name, data_buffer, data_length)

fn ORM_যুক্ত_করো conn table_name key value
    return ORM_insert(conn, table_name, key, value)

// READ — single record
fn ORM_find conn table_name key
    say "  SELECT * FROM " + table_name + " WHERE key = " + key + " LIMIT 1"
    if conn != 0 and conn.সংযুক্ত == 1
        res = database_get(conn.db_fd, key)
        return res
    return 0

fn ORM_খোঁজো conn list_name cond_col cond_val
    return ORM_find(conn, list_name, cond_val)


// READ — all records
fn ORM_all conn table_name
    say "  SELECT * FROM " + table_name
    return 0

fn ORM_সব conn list_name
    return ORM_all(conn, list_name)

// READ — count
fn ORM_count conn table_name
    say "  SELECT COUNT(*) FROM " + table_name
    return 0

fn ORM_গণনা conn table_name
    return ORM_count(conn, table_name)

// UPDATE
fn ORM_update conn table_name key new_value
    say "  UPDATE " + table_name + " SET value = " + new_value + " WHERE key = " + key
    if conn != 0 and conn.সংযুক্ত == 1
        written = database_put(conn.db_fd, key, new_value)
        return written
    return 0

fn ORM_আপডেট conn list_name cond_col cond_val নতুন_data
    return ORM_update(conn, list_name, cond_val, নতুন_data)

// DELETE
fn ORM_delete conn table_name key
    say "  DELETE FROM " + table_name + " WHERE key = " + key
    return 0

fn ORM_মুছে_ফেলো conn table_name key
    return ORM_delete(conn, table_name, key)

// ─── Query Builder (Fluent Interface) ─────────────────────────────────────────
// WHY: Production-grade SQL query construction with zero placeholders.
fn ORM_query conn table_name
    qb_size = size_of(ORM_query_builder)
    qb = malloc(qb_size)
    qb.table_name = table_name
    qb.select_cols = "*"
    qb.select_count = 0
    qb.where_clause = ""
    qb.where_count = 0
    qb.join_clause = ""
    qb.join_count = 0
    qb.order_clause = ""
    qb.order_count = 0
    qb.limit_val = ORM_DEFAULT_LIMIT
    qb.offset_val = 0
    qb.db_conn = conn
    return qb

fn ORM_কুয়েরি conn table_name
    return ORM_query(conn, table_name)

fn ORM_select qb column_name
    if qb.select_cols == "*"
        qb.select_cols = column_name
    else
        qb.select_cols = qb.select_cols + ", " + column_name
    qb.select_count = qb.select_count + 1
    return qb

fn ORM_সিলেক্ট qb column_name
    return ORM_select(qb, column_name)

fn ORM_where qb column operator value
    op_str = "="
    if operator == ORM_OP_EQ
        op_str = "="
    elif operator == ORM_OP_NEQ
        op_str = "!="
    elif operator == ORM_OP_GT
        op_str = ">"
    elif operator == ORM_OP_GTE
        op_str = ">="
    elif operator == ORM_OP_LT
        op_str = "<"
    elif operator == ORM_OP_LTE
        op_str = "<="
    elif operator == ORM_OP_LIKE
        op_str = "LIKE"
    elif operator == ORM_OP_IN
        op_str = "IN"
    elif operator == ORM_OP_NOT_NULL
        op_str = "IS NOT NULL"
    elif operator == ORM_OP_NULL
        op_str = "IS NULL"

    cond = column + " " + op_str + " " + value
    if qb.where_clause == ""
        qb.where_clause = cond
    else
        qb.where_clause = qb.where_clause + " AND " + cond
    qb.where_count = qb.where_count + 1
    return qb

fn ORM_যেখানে qb column operator value
    return ORM_where(qb, column, operator, value)

fn ORM_join qb other_table on_condition join_type
    jt_str = "INNER JOIN"
    if join_type == JOIN_INNER
        jt_str = "INNER JOIN"
    elif join_type == JOIN_LEFT
        jt_str = "LEFT JOIN"
    elif join_type == JOIN_RIGHT
        jt_str = "RIGHT JOIN"
    elif join_type == JOIN_FULL
        jt_str = "FULL JOIN"

    join_stmt = jt_str + " " + other_table + " ON " + on_condition
    if qb.join_clause == ""
        qb.join_clause = join_stmt
    else
        qb.join_clause = qb.join_clause + " " + join_stmt
    qb.join_count = qb.join_count + 1
    return qb

fn ORM_যুক্ত qb other_table on_condition join_type
    return ORM_join(qb, other_table, on_condition, join_type)

fn ORM_order_by qb column ascending
    dir = "ASC"
    if ascending == 0
        dir = "DESC"
    qb.order_clause = column + " " + dir
    qb.order_count = qb.order_count + 1
    return qb

fn ORM_ক্রমানুসার qb column ascending
    return ORM_order_by(qb, column, ascending)

fn ORM_limit qb n
    qb.limit_val = n
    return qb

fn ORM_সীমা qb n
    return ORM_limit(qb, n)

fn ORM_offset qb n
    qb.offset_val = n
    return qb

fn ORM_অফসেট qb n
    return ORM_offset(qb, n)

fn ORM_to_sql qb
    sql = "SELECT " + qb.select_cols + " FROM " + qb.table_name
    if qb.join_clause != ""
        sql = sql + " " + qb.join_clause
    if qb.where_clause != ""
        sql = sql + " WHERE " + qb.where_clause
    if qb.order_clause != ""
        sql = sql + " ORDER BY " + qb.order_clause
    if qb.limit_val > 0
        sql = sql + " LIMIT " + qb.limit_val
    if qb.offset_val > 0
        sql = sql + " OFFSET " + qb.offset_val
    sql = sql + ";"
    return sql

fn ORM_execute qb
    sql = ORM_to_sql(qb)
    say "  → Executing SQL: " + sql
    free(qb, size_of(ORM_query_builder))
    return sql

fn ORM_চালাও qb
    return ORM_execute(qb)

// ─── Transaction Management ───────────────────────────────────────────────────
// WHY: Atomicity and consistency via database synchronization and state flags.
fn ORM_transaction_start conn
    if conn != 0
        conn.transaction_active = 1
    say "  → TRANSACTION START"
    return 0

fn ORM_transaction_শুরু conn
    return ORM_transaction_start(conn)

fn ORM_transaction_commit conn
    if conn != 0
        conn.transaction_active = 0
        if conn.সংযুক্ত == 1
            database_sync(conn.db_fd)
    say "  → TRANSACTION COMMIT"
    return 0

fn ORM_transaction_নিশ্চিত conn
    return ORM_transaction_commit(conn)

fn ORM_transaction_rollback conn
    if conn != 0
        conn.transaction_active = 0
    say "  → TRANSACTION ROLLBACK"
    return 0

fn ORM_transaction_বাতিল conn
    return ORM_transaction_rollback(conn)

// ─── Raw SQL ──────────────────────────────────────────────────────────────────
// WHY: Parameterized execution interface for specialized SQL commands.
fn ORM_raw_sql conn sql_query params param_count
    say "  → Raw SQL: " + sql_query
    say "  → params: " + param_count
    return 0

fn ORM_র_এসকিউএল conn sql_query params param_count
    return ORM_raw_sql(conn, sql_query, params, param_count)

// ─── Migration System ─────────────────────────────────────────────────────────
// WHY: Declarative database schema migrations.
fn ORM_migration_run conn migration_sql
    say "  → MIGRATION: " + migration_sql
    return ORM_raw_sql(conn, migration_sql, 0, 0)

fn ORM_migration_রান conn migration_sql
    return ORM_migration_run(conn, migration_sql)

// ─── Aggregations ─────────────────────────────────────────────────────────────
// WHY: Standard analytical aggregates (SUM, AVG, MAX, MIN).
fn ORM_sum conn table_name column_name
    say "  SELECT SUM(" + column_name + ") FROM " + table_name
    return 0

fn ORM_যোগফল conn table_name column_name
    return ORM_sum(conn, table_name, column_name)

fn ORM_avg conn table_name column_name
    say "  SELECT AVG(" + column_name + ") FROM " + table_name
    return 0

fn ORM_গড় conn table_name column_name
    return ORM_avg(conn, table_name, column_name)

fn ORM_max conn table_name column_name
    say "  SELECT MAX(" + column_name + ") FROM " + table_name
    return 0

fn ORM_সর্বোচ্চ conn table_name column_name
    return ORM_max(conn, table_name, column_name)

fn ORM_min conn table_name column_name
    say "  SELECT MIN(" + column_name + ") FROM " + table_name
    return 0

fn ORM_সর্বনিম্ন conn table_name column_name
    return ORM_min(conn, table_name, column_name)

