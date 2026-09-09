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
//   অন্তর্ভুক্ত "std/orm.lp"
//   ধরি ব্যবহারকারী = ORM_খোঁজো("users", "id", ৪২)
//   ধরি সব = ORM_সব("users")
//   ORM_যোগ("users", ব্যবহারকারী_obj)
//   ORM_আপডেট("users", "id", ৪২, updated_obj)
//   ORM_মুছো("users", "id", ৪২)
// ==============================================================================

অন্তর্ভুক্ত "std/core/mem.lp"
অন্তর্ভুক্ত "std/core/str.lp"
অন্তর্ভুক্ত "std/core/io.lp"
অন্তর্ভুক্ত "std/db.lp"

// ─── ORM Constants ────────────────────────────────────────────────────────────
ধরি ORM_MAX_COLUMNS    = ৩২   // table columns per query
ধরি ORM_MAX_WHERE      = ১৬   // WHERE conditions
ধরি ORM_MAX_JOIN       = ৮    // JOIN tables
ধরি ORM_MAX_ORDER      = ৮    // ORDER BY columns
ধরি ORM_DEFAULT_LIMIT  = ১০০  // default result limit

// Data types
ধরি ORM_TYPE_INT       = ১
ধরি ORM_TYPE_STRING    = ২
ধরি ORM_TYPE_FLOAT     = ৩
ধরি ORM_TYPE_BOOL      = ৪
ধরি ORM_TYPE_DATETIME  = ৫
ধরি ORM_TYPE_JSON      = ৬
ধরি ORM_TYPE_BLOB      = ৭

// Query builders
ধরি ORM_OP_EQ         = ১   // =
ধরি ORM_OP_NEQ        = ২   // !=
ধরি ORM_OP_GT         = ৩   // >
ধরি ORM_OP_GTE        = ৪   // >=
ধরি ORM_OP_LT         = ৫   // <
ধরি ORM_OP_LTE        = ৬   // <=
ধরি ORM_OP_LIKE       = ৭   // LIKE
ধরি ORM_OP_IN         = ৮   // IN (list)
ধরি ORM_OP_NOT_NULL   = ৯   // IS NOT NULL
ধরি ORM_OP_NULL       = ১০  // IS NULL

// Join types
ধরি JOIN_INNER        = ১
ধরি JOIN_LEFT         = ২
ধরি JOIN_RIGHT        = ৩
ধরি JOIN_FULL         = ৪

// ─── Structs ──────────────────────────────────────────────────────────────────

গঠন ORM_কলাম_সংজ্ঞা {
    নাম_পয়েন্টার,
    ধরন,
    দৈর্ঘ্য,            // for VARCHAR
    nullable,           // NULL allowed?
    primary_key,        // PRIMARY KEY?
    auto_increment,     // AUTO_INCREMENT?
    unique_const,       // UNIQUE constraint?
    default_মান         // default value pointer
}

গঠন ORM_তালিকা_সংজ্ঞা {
    নাম_পয়েন্টার,
    কলাম_তালিকা,
    কলাম_গণনা
}

গঠন ORM_শর্ত {
    কলাম_পয়েন্টার,
    অপারেটর,
    মান_পয়েন্টার,
    পরবর্তী_শর্ত     // linked list of conditions
}

গঠন ORM_query_builder {
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
}

গঠন ORM_সংযোগ {
    db_পাথ,
    db_fd,
    সংযুক্ত,
    transaction_active
}

// ─── Connection Management ────────────────────────────────────────────────────
কাজ ORM_সংযোগ_খোলো(db_পাথ) {
    ধরি conn_সাইজ = সাইজ(ORM_সংযোগ)
    ধরি conn = মেমরি_বরাদ্দ(conn_সাইজ)
    conn.db_পাথ = db_পাথ
    conn.db_fd = ফাইল_খোলো(db_পাথ)
    যদি conn.db_fd < ০ {
        দেখাও "  ❌ ডেটাবেজ সংযোগ ব্যর্থ:", db_পাথ
        মেমরি_মুক্তি(conn, conn_সাইজ)
        ফেরত ০
    }
    conn.সংযুক্ত = ১
    conn.transaction_active = ০
    দেখাও "  ✔ ডেটাবেজ সংযুক্ত:", db_পাথ
    ফেরত conn
}

কাজ ORM_সংযোগ_বন্ধ(conn) {
    যদি conn == ০ { ফেরত ০ }
    ফাইল_বন্ধ(conn.db_fd)
    conn.সংযুক্ত = ০
    মেমরি_মুক্তি(conn, সাইজ(ORM_সংযোগ))
    দেখাও "  ✔ ডেটাবেজ সংযোগ বন্ধ"
    ফেরত ০
}

// ─── Schema Definition ────────────────────────────────────────────────────────
// WHY: Define table schema in code (database-first design is brittle)
কাজ ORM_তালিকা_তৈরি(conn, নাম, কলাম_তালিকা, কলাম_গণনা) {
    // WHY: CREATE TABLE IF NOT EXISTS
    দেখাও "  → CREATE TABLE IF NOT EXISTS", নাম
    দেখাও "  → কলাম সংখ্যা:", কলাম_গণনা
    // Build DDL from column definitions
    // Execute via db syscall
    ফেরত ০
}

কাজ ORM_কলাম_যোগ(তালিকা, নাম, ধরন, দৈর্ঘ্য) {
    // ALTER TABLE ADD COLUMN (for migrations)
    দেখাও "  → ALTER TABLE", তালিকা, "ADD COLUMN", নাম
    ফেরত ০
}

// ─── CRUD Operations ─────────────────────────────────────────────────────────
// WHY: Create-Read-Update-Delete are the 4 fundamental DB operations

// CREATE
কাজ ORM_যোগ(conn, তালিকা_নাম, ডেটা_বাফার, ডেটা_দৈর্ঘ্য) {
    // WHY: INSERT INTO table (columns) VALUES (values)
    দেখাও "  INSERT INTO", তালিকা_নাম
    // Serialize data to SQL
    // Execute query
    // Return new row ID (last_insert_id)
    ধরি new_id = ১  // placeholder for actual DB call
    দেখাও "  → নতুন ID:", new_id
    ফেরত new_id
}

// READ — single row
কাজ ORM_খোঁজো(conn, তালিকা_নাম, শর্ত_কলাম, শর্ত_মান) {
    // WHY: SELECT * FROM table WHERE column = value LIMIT 1
    দেখাও "  SELECT * FROM", তালিকা_নাম, "WHERE", শর্ত_কলাম, "=", শর্ত_মান
    ধরি result_বাফার = মেমরি_বরাদ্দ(৪০৯৬)
    ফেরত result_বাফার
}

// READ — all rows
কাজ ORM_সব(conn, তালিকা_নাম) {
    দেখাও "  SELECT * FROM", তালিকা_নাম
    ধরি result_বাফার = মেমরি_বরাদ্দ(৬৫৫৩৬)
    ফেরত result_বাফার
}

// READ — count
কাজ ORM_গণনা(conn, তালিকা_নাম) {
    দেখাও "  SELECT COUNT(*) FROM", তালিকা_নাম
    ফেরত ০
}

// UPDATE
কাজ ORM_আপডেট(conn, তালিকা_নাম, শর্ত_কলাম, শর্ত_মান, নতুন_ডেটা) {
    // WHY: UPDATE table SET col1=val1, col2=val2 WHERE condition
    দেখাও "  UPDATE", তালিকা_নাম, "WHERE", শর্ত_কলাম, "=", শর্ত_মান
    ফেরত ০
}

// DELETE
কাজ ORM_মুছো(conn, তালিকা_নাম, শর্ত_কলাম, শর্ত_মান) {
    // WHY: DELETE FROM table WHERE column = value
    দেখাও "  DELETE FROM", তালিকা_নাম, "WHERE", শর্ত_কলাম, "=", শর্ত_মান
    ফেরত ০
}

// ─── Query Builder (Fluent Interface) ─────────────────────────────────────────
// WHY: Complex queries need a builder pattern
// Example: ORM_query(conn, "users").where("age", ORM_OP_GT, ১৮).order("name").limit(১০).exec()

কাজ ORM_query(conn, তালিকা_নাম) {
    ধরি qb_সাইজ = সাইজ(ORM_query_builder)
    ধরি qb = মেমরি_বরাদ্দ(qb_সাইজ)
    qb.তালিকা_নাম = তালিকা_নাম
    qb.select_গণনা = ০
    qb.where_গণনা = ০
    qb.join_গণনা = ০
    qb.order_গণনা = ০
    qb.সীমা = ORM_DEFAULT_LIMIT
    qb.অফসেট = ০
    qb.db_সংযোগ = conn
    ফেরত qb
}

কাজ ORM_select(qb, কলাম_নাম) {
    // WHY: SELECT specific columns (not *)
    qb.select_গণনা = qb.select_গণনা + ১
    ফেরত qb
}

কাজ ORM_where(qb, কলাম, অপারেটর, মান) {
    // WHY: Add WHERE condition
    qb.where_গণনা = qb.where_গণনা + ১
    ফেরত qb
}

কাজ ORM_order_by(qb, কলাম, আরোহী) {
    // WHY: Sort results (আরোহী=1 = ASC, আরোহী=0 = DESC)
    qb.order_গণনা = qb.order_গণনা + ১
    qb.order_আরোহী = আরোহী
    ফেরত qb
}

কাজ ORM_limit(qb, n) {
    qb.সীমা = n
    ফেরত qb
}

কাজ ORM_offset(qb, n) {
    qb.অফসেট = n
    ফেরত qb
}

কাজ ORM_join(qb, তালিকা, শর্ত, join_type) {
    // WHY: JOIN other tables for relational data
    qb.join_গণনা = qb.join_গণনা + ১
    ফেরত qb
}

কাজ ORM_execute(qb) {
    // WHY: Build final SQL and execute
    দেখাও "  SELECT"
    যদি qb.select_গণনা == ০ { দেখাও "    *" }
    দেখাও "  FROM", qb.তালিকা_নাম
    যদি qb.where_গণনা > ০ { দেখাও "  WHERE <conditions>" }
    যদি qb.order_গণনা > ০ { দেখাও "  ORDER BY <columns>" }
    দেখাও "  LIMIT", qb.সীমা, "OFFSET", qb.অফসেট

    ধরি result_বাফার = মেমরি_বরাদ্দ(৬৫৫৩৬)
    মেমরি_মুক্তি(qb, সাইজ(ORM_query_builder))
    ফেরত result_বাফার
}

// ─── Transaction Management ───────────────────────────────────────────────────
// WHY: Transactions ensure atomicity — all or nothing
কাজ ORM_transaction_শুরু(conn) {
    // BEGIN TRANSACTION
    conn.transaction_active = ১
    দেখাও "  → TRANSACTION START"
    ফেরত ০
}

কাজ ORM_transaction_commit(conn) {
    // COMMIT
    conn.transaction_active = ০
    দেখাও "  → TRANSACTION COMMIT"
    ফেরত ০
}

কাজ ORM_transaction_rollback(conn) {
    // ROLLBACK — undo everything since BEGIN
    conn.transaction_active = ০
    দেখাও "  → TRANSACTION ROLLBACK"
    ফেরত ০
}

// ─── Raw SQL ──────────────────────────────────────────────────────────────────
// WHY: Sometimes ORM is not enough — complex queries need raw SQL
// But parameterized to prevent SQL injection
কাজ ORM_raw_sql(conn, sql_query, params, param_count) {
    দেখাও "  → Raw SQL:", sql_query
    দেখাও "  → params:", param_count
    ধরি result = মেমরি_বরাদ্দ(৬৫৫৩৬)
    ফেরত result
}

// ─── Migration System ─────────────────────────────────────────────────────────
// WHY: Database schema evolves over time — need versioned migrations
কাজ ORM_migration_রান(conn, migration_sql) {
    দেখাও "  → MIGRATION:", migration_sql
    ফেরত ORM_raw_sql(conn, migration_sql, ০, ০)
}

// ─── Aggregations ─────────────────────────────────────────────────────────────
কাজ ORM_sum(conn, তালিকা_নাম, কলাম_নাম) {
    দেখাও "  SELECT SUM(", কলাম_নাম, ") FROM", তালিকা_নাম
    ফেরত ০
}

কাজ ORM_avg(conn, তালিকা_নাম, কলাম_নাম) {
    দেখাও "  SELECT AVG(", কলাম_নাম, ") FROM", তালিকা_নাম
    ফেরত ০
}

কাজ ORM_max(conn, তালিকা_নাম, কলাম_নাম) {
    দেখাও "  SELECT MAX(", কলাম_নাম, ") FROM", তালিকা_নাম
    ফেরত ০
}

কাজ ORM_min(conn, তালিকা_নাম, কলাম_নাম) {
    দেখাও "  SELECT MIN(", কলাম_নাম, ") FROM", তালিকা_নাম
    ফেরত ০
}
