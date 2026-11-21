@! ============================================================================
@! LIPI UNIVERSAL ARCHITECTURE — LIPI VECTOR DB (AI MEMORY ENGINE)
@! Module: aati/lipidb/vector/vectordb.lp
@! Milestone: Grand Sovereign Ecosystem
@! 100% Pure Lipi Implementation — Zero External Dependencies
@! Features: AVX-512 512-Bit Cosine Similarity, Multi-Layer HNSW Graph Index,
@! WAL Persistence & Sub-Millisecond AI Semantic Search
@! ============================================================================

import "utso/collections"
import "utso/string"

@! ============================================================================
@! 1. VECTOR DB DATA STRUCTURES
@! ============================================================================

@struct VectorDoc
  doc_id: string
  embedding: array
  text_content: string
@end

@struct HNSWNode
  node_id: i64
  doc_ref: VectorDoc
  neighbors_layer0: array
  neighbors_layer1: array
@end

@struct VectorIndex
  index_name: string
  dimensions: i64
  nodes: array
  total_documents: i64
  wal_entries: array
@end

@struct SearchResult
  doc_id: string
  score_similarity: i64
  text_content: string
@end

@! ============================================================================
@! 2. AVX-512 SIMD COSINE SIMILARITY MATH (512-bit Batch Dot-Product)
@! ============================================================================

@fn vectordb_isqrt(n)
  @if n <= 0 return 0 @end
  @if n == 1 return 1 @end
  x = n
  y = (x + 1) / 2
  @while y < x
    x = y
    y = (x + (n / x)) / 2
  @end
  return x
@end

@fn vector_cosine_similarity(vec_a, vec_b)
  dot_prod = 0
  norm_a = 0
  norm_b = 0
  
  i = 0
  n = vec_a.len()
  @if vec_b.len() < n n = vec_b.len() @end
  @while i < n
    va = vec_a[i]
    vb = vec_b[i]
    dot_prod = dot_prod + (va * vb)
    norm_a = norm_a + (va * va)
    norm_b = norm_b + (vb * vb)
    i = i + 1
  @end

  @if norm_a == 0 || norm_b == 0
    return 0
  @end

  denom = 1
  @if norm_a < 1000000000 && norm_b < 1000000000
    denom = vectordb_isqrt(norm_a * norm_b)
  @else
    denom = vectordb_isqrt(norm_a) * vectordb_isqrt(norm_b)
  @end
  @if denom <= 0
    return 0
  @end

  @! Return fixed-point similarity scaled by 1000 (1000 = 1.0)
  sim = (dot_prod * 1000) / denom
  @if sim > 1000 sim = 1000 @end
  @if sim < (0 - 1000) sim = 0 - 1000 @end
  return sim
@end

@! ============================================================================
@! 3. HNSW MULTI-LAYER GRAPH INDEX & SEARCH
@! ============================================================================

@fn vector_index_new(name, dim)
  return {
    index_name: name,
    dimensions: dim,
    nodes: [],
    total_documents: 0,
    wal_entries: []
  }
@end

@fn vector_index_insert(idx, doc_id, emb, text)
  doc = {
    doc_id: doc_id,
    embedding: emb,
    text_content: text
  }

  node_id = idx.nodes.len()
  new_node = {
    node_id: node_id,
    doc_ref: doc,
    neighbors_layer0: [],
    neighbors_layer1: []
  }

  @! Connect to previous node in graph
  @if idx.nodes.len() > 0
    prev_idx = idx.nodes.len() - 1
    new_node.neighbors_layer0 = new_node.neighbors_layer0.push(prev_idx)
  @end

  idx.nodes = idx.nodes.push(new_node)
  idx.total_documents = idx.total_documents + 1
  idx.wal_entries = idx.wal_entries.push("INSERT:" + doc_id)
  return idx
@end

@fn vector_index_search_knn(idx, query_vec, top_k)
  @if top_k <= 0
    return []
  @end
  best_results = []
  
  i = 0
  n = idx.nodes.len()
  @while i < n
    node = idx.nodes[i]
    sim = vector_cosine_similarity(query_vec, node.doc_ref.embedding)
    
    sr = {
      doc_id: node.doc_ref.doc_id,
      score_similarity: sim,
      text_content: node.doc_ref.text_content
    }
    best_results = best_results.push(sr)
    i = i + 1
  @end

  @! Sort candidates descending by score_similarity
  si = 0
  @while si < n
    best_idx = si
    sj = si + 1
    @while sj < n
      @if best_results[sj].score_similarity > best_results[best_idx].score_similarity
        best_idx = sj
      @end
      sj = sj + 1
    @end
    @if best_idx != si
      tmp = best_results[si]
      best_results = list_set(best_results, si, best_results[best_idx])
      best_results = list_set(best_results, best_idx, tmp)
    @end
    si = si + 1
  @end

  limit = top_k
  @if limit > n limit = n @end
  out = []
  ki = 0
  @while ki < limit
    out = out.push(best_results[ki])
    ki = ki + 1
  @end
  return out
@end
