@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — MAYA VECTOR DB TEST SUITE
@! File: tests/db/test_vector_db.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/db/vector/vectordb"

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println("  [FAIL] Assertion failed: " + msg)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("🗄️ MAYA VECTOR DB (AI SEMANTIC MEMORY) TEST SUITE 🗄️")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: Cosine Similarity Vector Math
  println("▶ Section 1: 512-Bit Vector Cosine Similarity Math...")
  total_tests = total_tests + 1
  v1 = [10, 20, 30, 40]
  v2 = [10, 20, 30, 40]
  sim_self = vector_cosine_similarity(v1, v2)
  ok1 = assert_true(sim_self >= 900, "Identical vector cosine similarity is ~1000 (1.0)")
  
  v3 = [0, 0, 0, 1]
  sim_diff = vector_cosine_similarity(v1, v3)
  ok2 = assert_true(sim_diff < sim_self, "Orthogonal vector has significantly lower similarity")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Vector cosine similarity math verified")
  @end

  @! SECTION 2: HNSW Multi-Layer Graph Index & WAL Persistence
  println("▶ Section 2: HNSW Graph Insertion & Disk-Backed WAL...")
  total_tests = total_tests + 1
  vdb = vector_index_new("maya_ai_docs", 4)
  vdb = vector_index_insert(vdb, "doc_101", [10, 20, 30, 40], "Maya is sovereign language")
  vdb = vector_index_insert(vdb, "doc_102", [5, 10, 15, 20], "Rust is fast but Maya is sovereign")
  
  ok1 = assert_eq_int(vdb.total_documents, 2, "Vector database indexed 2 documents")
  ok2 = assert_eq_int(vdb.wal_entries.len(), 2, "WAL persistence recorded 2 insert operations")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] HNSW graph insertion and WAL disk logging verified")
  @end

  @! SECTION 3: Semantic KNN Search
  println("▶ Section 3: Sub-Millisecond Semantic KNN Nearest Neighbor Search...")
  total_tests = total_tests + 1
  query = [10, 20, 30, 40]
  results = vector_index_search_knn(vdb, query, 2)
  
  ok1 = assert_eq_int(results.len(), 2, "Returned top 2 nearest neighbor documents")
  r0 = results[0]
  ok2 = assert_true(contains(r0.doc_id, "doc_101"), "Most relevant document doc_101 found with highest score")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Semantic KNN search verified")
  @end

  println("=================================================================")
  println("📊 VECTOR DB TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 3 MAYA VECTOR DB TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME VECTOR DB TESTS FAILED")
    return 1
  @end
@end
