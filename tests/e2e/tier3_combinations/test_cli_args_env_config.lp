@! ============================================================================
@! MAYA E2E TIER 3 — CROSS-FEATURE: CLI ARGS + ENV VARS + CONFIG STRUCT
@! File: tests/e2e/tier3_combinations/test_cli_args_env_config.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 3
@! ============================================================================

import "universe/core/string"

@struct ServerConfig
  host: ""
  port: 0
  threads: 0
  verbose: 0
  max_connections: 0
  valid: 0
  error_msg: ""
@end

@fn parse_int_safe(s, default_val)
  len = str_len(s)
  @if len == 0
    return default_val
  @end
  num = 0
  i = 0
  is_neg = 0
  @if char_at(s, 0) == char_code("-")
    is_neg = 1
    i = 1
  @end
  @while i < len
    c = char_at(s, i)
    @if c < char_code("0") || c > char_code("9")
      return default_val
    @end
    num = num * 10 + (c - char_code("0"))
    i = i + 1
  @end
  @if is_neg == 1
    return 0 - num
  @end
  return num
@end

@fn parse_cli_args(args_arr)
  config = {
    host: "127.0.0.1",
    port: 8080,
    threads: 1,
    verbose: 0,
    max_connections: 1000,
    valid: 1,
    error_msg: ""
  }

  i = 0
  len = args_arr.len()
  @while i < len
    arg = args_arr[i]
    @if arg == "--host" || arg == "-h"
      @if i + 1 < len
        config.host = args_arr[i + 1]
        i = i + 1
      @else
        config.valid = 0
        config.error_msg = "Missing value for --host"
        return config
      @end
    @elif arg == "--port" || arg == "-p"
      @if i + 1 < len
        p = parse_int_safe(args_arr[i + 1], -1)
        @if p <= 0 || p > 65535
          config.valid = 0
          config.error_msg = "Port out of range (1-65535)"
          return config
        @end
        config.port = p
        i = i + 1
      @else
        config.valid = 0
        config.error_msg = "Missing value for --port"
        return config
      @end
    @elif arg == "--threads" || arg == "-t"
      @if i + 1 < len
        config.threads = parse_int_safe(args_arr[i + 1], 1)
        i = i + 1
      @end
    @elif arg == "--verbose" || arg == "-v"
      config.verbose = 1
    @elif arg == "--max-conn"
      @if i + 1 < len
        config.max_connections = parse_int_safe(args_arr[i + 1], 1000)
        i = i + 1
      @end
    @end
    i = i + 1
  @end

  return config
@end

@fn parse_env_string(env_str, base_cfg)
  @! Parses semicolon-delimited key=val string: "HOST=0.0.0.0;PORT=9000;VERBOSE=1"
  pos = 0
  len = str_len(env_str)
  @while pos < len
    next_semi = pos
    @while next_semi < len && char_at(env_str, next_semi) != char_code(";")
      next_semi = next_semi + 1
    @end
    pair = str_substr(env_str, pos, next_semi)
    pos = next_semi + 1

    @! Find '=' in pair
    eq_idx = 0
    pair_len = str_len(pair)
    @while eq_idx < pair_len && char_at(pair, eq_idx) != char_code("=")
      eq_idx = eq_idx + 1
    @end

    @if eq_idx > 0 && eq_idx < pair_len
      k = str_substr(pair, 0, eq_idx)
      v = str_substr(pair, eq_idx + 1, pair_len)
      @if k == "HOST"
        base_cfg.host = v
      @elif k == "PORT"
        base_cfg.port = parse_int_safe(v, base_cfg.port)
      @elif k == "THREADS"
        base_cfg.threads = parse_int_safe(v, base_cfg.threads)
      @elif k == "VERBOSE"
        @if v == "1" || v == "true"
          base_cfg.verbose = 1
        @else
          base_cfg.verbose = 0
        @end
      @elif k == "MAX_CONN"
        base_cfg.max_connections = parse_int_safe(v, base_cfg.max_connections)
      @end
    @end
  @end
  return base_cfg
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 3] Combination 12: CLI Args + Env Vars + Config Struct")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T3.12.1: Default Config Values
  total = total + 1
  cfg_def = parse_cli_args([])
  @if cfg_def.host == "127.0.0.1" && cfg_def.port == 8080 && cfg_def.threads == 1 && cfg_def.verbose == 0
    passed = passed + 1
    println("  [PASS] T3.12.1: Default ServerConfig loaded (127.0.0.1:8080, threads=1, verbose=0)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.12.1: Default config values mismatch")
  @end

  @! T3.12.2: Full CLI Flag Overrides
  total = total + 1
  argv = ["--host", "0.0.0.0", "--port", "443", "--threads", "8", "--verbose", "--max-conn", "50000"]
  cfg_cli = parse_cli_args(argv)

  @if cfg_cli.valid == 1 && cfg_cli.host == "0.0.0.0" && cfg_cli.port == 443 && cfg_cli.threads == 8 && cfg_cli.verbose == 1 && cfg_cli.max_connections == 50000
    passed = passed + 1
    println("  [PASS] T3.12.2: CLI argv parsed successfully into typed ServerConfig (host=0.0.0.0, port=443, threads=8, verbose=1, max_conn=50000)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.12.2: CLI flag parsing failed")
  @end

  @! T3.12.3: Port Range Boundary Validation
  total = total + 1
  bad_argv = ["--port", "70000"]
  cfg_bad_port = parse_cli_args(bad_argv)

  @if cfg_bad_port.valid == 0 && cfg_bad_port.error_msg == "Port out of range (1-65535)"
    passed = passed + 1
    println("  [PASS] T3.12.3: Invalid port range rejected cleanly: \"" + cfg_bad_port.error_msg + "\"")
  @else
    failed = failed + 1
    println("  [FAIL] T3.12.3: Port range validation failed")
  @end

  @! T3.12.4: Missing Value Error Handling
  total = total + 1
  missing_argv = ["--host"]
  cfg_missing = parse_cli_args(missing_argv)

  @if cfg_missing.valid == 0 && cfg_missing.error_msg == "Missing value for --host"
    passed = passed + 1
    println("  [PASS] T3.12.4: Missing CLI flag value rejected cleanly: \"" + cfg_missing.error_msg + "\"")
  @else
    failed = failed + 1
    println("  [FAIL] T3.12.4: Missing value check failed")
  @end

  @! T3.12.5: Environment Variable Merging
  total = total + 1
  env_payload = "HOST=192.168.1.100;PORT=3000;THREADS=16;VERBOSE=true;MAX_CONN=25000"
  cfg_merged = parse_env_string(env_payload, cfg_def)

  @if cfg_merged.host == "192.168.1.100" && cfg_merged.port == 3000 && cfg_merged.threads == 16 && cfg_merged.verbose == 1 && cfg_merged.max_connections == 25000
    passed = passed + 1
    println("  [PASS] T3.12.5: Environment variable parsing & merge updated all config properties correctly")
  @else
    failed = failed + 1
    println("  [FAIL] T3.12.5: Environment variable merge failed")
  @end

  println("-----------------------------------------------------------------")
  println("Combination 12 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Combination 12 (CLI Args & Config Struct) PASSED")
    return 0
  @else
    println("✗ Combination 12 (CLI Args & Config Struct) FAILED")
    return 1
  @end
@end
