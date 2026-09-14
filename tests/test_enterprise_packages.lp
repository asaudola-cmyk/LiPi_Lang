// ==============================================================================
// 🧪 LIPI REGRESSION TEST: Consolidated Enterprise Package Suite (Pillar 4)
// ⚡ 100% Pure LiPi Implementation — Zero Libc, Zero C, Zero Python, Zero PHP
//    Verifies lipi_sql, lipi_http_client, lipi_jwt, lipi_dataframe, and lipi_grpc
// ==============================================================================

include "packages/lipi_sql/src/sql.lp"
include "packages/lipi_http_client/src/http_client.lp"
include "packages/lipi_jwt/src/jwt.lp"
include "packages/lipi_dataframe/src/dataframe.lp"
include "packages/lipi_grpc/src/grpc.lp"

fn assert_true cond test_name
    if cond == 0
        say "  ❌ FAILED: " + test_name
        exit(1)
    say "  ✔ [PASS] " + test_name

fn assert_eq actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    say "  ✔ [PASS] " + test_name

say "================================================================="
say "👑 LIPI ENTERPRISE ECOSYSTEM: 5-PACKAGE INTEGRATION TEST 👑"
say "================================================================="

// ── ১. Package 1: lipi_sql ──────────────────────────────────────────────
say "[1/5] Verifying lipi_sql (Relational Store & Planner)..."
sql_eng = sql_engine_new()
tbl = sql_create_table(sql_eng, 201, 2, 20)
sql_insert_2(sql_eng, 201, 101, 550)
sql_insert_2(sql_eng, 201, 102, 750)
assert_eq(sql_count_active(sql_eng, 201), 2, "lipi_sql: 2 active rows")
assert_eq(sql_select_cell(sql_eng, 201, 1, 1), 750, "lipi_sql: cell val == 750")
sql_engine_free(sql_eng)

// ── ২. Package 2: lipi_http_client ──────────────────────────────────────
say "[2/5] Verifying lipi_http_client (Zero-Dependency HTTP/1.1 Protocol)..."
http_buf = sys_alloc(64)
// Write "HTTP/1.1 200 OK\r\n\r\nOK"
mem_byte_write(http_buf, 0, 72)
mem_byte_write(http_buf, 1, 84)
mem_byte_write(http_buf, 2, 84)
mem_byte_write(http_buf, 3, 80)
mem_byte_write(http_buf, 4, 47)
mem_byte_write(http_buf, 5, 49)
mem_byte_write(http_buf, 6, 46)
mem_byte_write(http_buf, 7, 49)
mem_byte_write(http_buf, 8, 32)
mem_byte_write(http_buf, 9, 50)
mem_byte_write(http_buf, 10, 48)
mem_byte_write(http_buf, 11, 48)
mem_byte_write(http_buf, 12, 32)
mem_byte_write(http_buf, 13, 79)
mem_byte_write(http_buf, 14, 75)
mem_byte_write(http_buf, 15, 13)
mem_byte_write(http_buf, 16, 10)
mem_byte_write(http_buf, 17, 13)
mem_byte_write(http_buf, 18, 10)
mem_byte_write(http_buf, 19, 79)
mem_byte_write(http_buf, 20, 75)

resp_obj = http_parse_response(http_buf, 21)
assert_eq(http_response_status(resp_obj), 200, "lipi_http_client: status is 200")
assert_eq(http_response_body_len(resp_obj), 2, "lipi_http_client: body len is 2")
http_response_free(resp_obj)

// ── ৩. Package 3: lipi_jwt ──────────────────────────────────────────────
say "[3/5] Verifying lipi_jwt (RFC 7519 Cryptographic Tokens)..."
jwt_secret = "enterprise_mesh_secret_key_42"
sec_l = len jwt_secret
tok_buf = sys_alloc(256)
tok_len = jwt_create_token(tok_buf, jwt_secret, sec_l, 9001, 1900000000, 7)
assert_true(tok_len > 70, "lipi_jwt: token created")
jwt_val = jwt_validate_token(tok_buf, tok_len, jwt_secret, sec_l, 1700000000)
assert_eq(jwt_val, 1, "lipi_jwt: cryptographic signature verified")
assert_eq(jwt_extract_sub(tok_buf, tok_len), 9001, "lipi_jwt: sub claim is 9001")
assert_eq(jwt_extract_role(tok_buf, tok_len), 7, "lipi_jwt: role claim is 7")
mem_free(tok_buf, 256)

// ── ৪. Package 4: lipi_dataframe ────────────────────────────────────────
say "[4/5] Verifying lipi_dataframe (Columnar Analytics Engine)..."
df = df_new()
df_add_column(df, "val", COL_TYPE_INT, 10)
df_append_row_1(df, 100)
df_append_row_1(df, 200)
df_append_row_1(df, 300)
assert_eq(df_sum(df, 0), 600, "lipi_dataframe: sum == 600")
assert_eq(df_mean(df, 0), 200, "lipi_dataframe: mean == 200")
df_free(df)

// ── ৫. Package 5: lipi_grpc ─────────────────────────────────────────────
say "[5/5] Verifying lipi_grpc (Binary Wire Protocol & Protobuf Engine)..."
grpc_frame = sys_alloc(32)
grpc_payload = sys_alloc(8)
mem_fill(grpc_payload, 71, 8) // 'G'
flen = grpc_frame_message(grpc_frame, grpc_payload, 8)
assert_eq(flen, 13, "lipi_grpc: framed length 5 + 8 = 13")
grpc_meta = sys_alloc(24)
unframed_len = grpc_unframe_message(grpc_frame, flen, grpc_meta)
assert_eq(unframed_len, 8, "lipi_grpc: unframed length == 8")
mem_free(grpc_frame, 32)
mem_free(grpc_payload, 8)
mem_free(grpc_meta, 24)

say "================================================================="
say "🎉 ALL 5 ENTERPRISE SOVEREIGN PACKAGES FULLY VERIFIED! 🎉"
say "================================================================="
