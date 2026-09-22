// ==============================================================================
// 🧪 LIPI TEST SUITE: HNSW MULTI-LAYER VECTOR DATABASE & LOCAL RAG
// File: tests/test_vector_hnsw_rag.lp
// Standard: Hierarchical Navigable Small World Index & Local RAG Prompt Synthesizer
// 100% Pure Lipi — Zero Python | Zero Faiss | Zero External Runtimes
// ==============================================================================

import "universe/db/vector/hnsw"
import "universe/core/string"

@fn assert_true(cond: i64, msg: string)
  @if cond == 0
    println(str_concat("  [FAIL] Assertion failed: ", msg))
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual: i64, expected: i64, msg: string)
  @if actual != expected
    s_act = to_str(actual)
    s_exp = to_str(expected)
    err = str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> Expected ", str_concat(s_exp, str_concat(", got ", s_act)))))
    println(err)
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("🧠 LIPI HNSW VECTOR DATABASE & LOCAL RAG TEST SUITE 🧠")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  // ── Section 1: Vector Metric Kernels (Cosine & Euclidean) ───────────────────
  println("▶ Section 1: Vector Metric Math (Fixed-Point Cosine & L2)...")
  total_tests = total_tests + 1

  v1 = [10, 20, 30]
  v2 = [10, 20, 30] // Identical vector
  v3 = [0, 0, 0]    // Zero vector

  sim_ident = hnsw_cosine_similarity(v1, v2)
  dist_ident = hnsw_euclidean_distance(v1, v2)

  // Cosine similarity of identical vector should be ~1000 (1.000)
  ok_sim = assert_true(sim_ident >= 990, "Cosine similarity of identical vector ~1000")
  ok_dist = assert_eq_int(dist_ident, 0, "Euclidean distance of identical vector = 0")

  @if ok_sim == 1 && ok_dist == 1
    println("  ✔ [PASS] Vector metric calculations verified.")
    passed_tests = passed_tests + 1
  @end

  // ── Section 2: HNSW Multi-Layer Index Insertion ──────────────────────────────
  println("▶ Section 2: HNSW Multi-Layer Vector Graph Insertion...")
  total_tests = total_tests + 1

  idx = hnsw_index_new("lipi_kb", 4, 16)
  ok_init = assert_eq_int(idx.total_documents, 0, "New index has 0 documents")

  // Insert Knowledge Base passages
  idx = hnsw_insert(idx, "doc_os", [100, 10, 5, 0], "Lipi OS is a 100% sovereign bare-metal unikernel operating system.")
  idx = hnsw_insert(idx, "doc_ai", [10, 100, 20, 5], "Silicon AI runner executes GGUF models directly on CPU memory.")
  idx = hnsw_insert(idx, "doc_db", [5, 20, 100, 10], "LipiDB is a Redis-compatible in-memory store supporting RESP 2/3.")
  idx = hnsw_insert(idx, "doc_gui", [0, 5, 10, 100], "Direct Linear Framebuffer renders tear-free desktop GUI shells.")

  ok_cnt = assert_eq_int(idx.total_documents, 4, "Total documents count is 4")
  ok_ep = assert_true(idx.entry_point_id >= 0, "HNSW Entry point initialized")

  @if ok_init == 1 && ok_cnt == 1 && ok_ep == 1
    println("  ✔ [PASS] Multi-layer HNSW graph construction verified.")
    passed_tests = passed_tests + 1
  @end

  // ── Section 3: Logarithmic k-NN Nearest Neighbor Retrieval ───────────────────
  println("▶ Section 3: Semantic k-NN Vector Search...")
  total_tests = total_tests + 1

  // Query vector strongly matching doc_ai: [15, 95, 25, 10]
  q_ai = [15, 95, 25, 10]
  top_matches = hnsw_search_knn(idx, q_ai, 2)
  ok_m_len = assert_eq_int(top_matches.len(), 2, "Returned top-2 matches")

  match0 = top_matches[0]
  ok_top_doc = assert_true(str_eq(match0.doc_id, "doc_ai") == 1, "Top match is doc_ai")
  ok_high_score = assert_true(match0.score > 800, "Top match score > 800 (high semantic similarity)")

  @if ok_m_len == 1 && ok_top_doc == 1 && ok_high_score == 1
    println("  ✔ [PASS] Semantic k-NN retrieval verified.")
    passed_tests = passed_tests + 1
  @end

  // ── Section 4: Local RAG Context Prompt Synthesis ────────────────────────────
  println("▶ Section 4: Local RAG Enriched Prompt Synthesis...")
  total_tests = total_tests + 1

  rag_prompt = hnsw_rag_synthesize_prompt(idx, q_ai, "How does Lipi run AI on CPU?", 1)
  ok_has_ctx = assert_true(starts_with(rag_prompt, "CONTEXT:") == 1, "RAG prompt contains CONTEXT header")
  ok_has_body = assert_true(str_contains(rag_prompt, "Silicon AI runner executes GGUF") == 1, "RAG prompt contains retrieved passage")
  ok_has_query = assert_true(str_contains(rag_prompt, "QUERY: How does Lipi run AI on CPU?") == 1, "RAG prompt contains original query")

  @if ok_has_ctx == 1 && ok_has_body == 1 && ok_has_query == 1
    println("  ✔ [PASS] Local RAG prompt synthesis verified.")
    passed_tests = passed_tests + 1
  @end

  println("-----------------------------------------------------------------")
  summary = str_concat("RESULTS: ", str_concat(to_str(passed_tests), str_concat("/", str_concat(to_str(total_tests), " sections passed."))))
  println(summary)
  @if passed_tests == total_tests
    println("🎉 ALL HNSW VECTOR DATABASE & LOCAL RAG TESTS PASSED!")
    return 0
  @end
  return 1
@end

main()
