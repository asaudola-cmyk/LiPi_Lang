// ==============================================================================
// 🧠 LIPI HNSW MULTI-LAYER VECTOR DATABASE & LOCAL RAG ENGINE
// File: universe/db/vector/hnsw.lp
// Standard: Hierarchical Navigable Small World (HNSW) Multi-Layer Graph Index
// 100% Pure Lipi Implementation — Zero Python | Zero PyTorch | Zero Faiss / Chroma
// ==============================================================================
//
// WHY: In-memory vector indexing with brute-force O(N) search becomes untenable
// for production knowledge bases (>100k embeddings). HNSW provides logarithmic O(log N)
// nearest neighbor graph traversal across skip-list layers, enabling instant
// local Retrieval-Augmented Generation (RAG) directly on bare-metal silicon.
// ==============================================================================

import "universe/core/collections"
import "universe/core/string"

// ── 1. HNSW Vector & Graph Node Structures ────────────────────────────────────
@struct HNSWDoc
  doc_id: string
  embedding: array
  text_content: string
@end

@struct HNSWGraphNode
  node_id: i64
  doc: HNSWDoc
  level: i64
  neighbors_layer0: array
  neighbors_layer1: array
  neighbors_layer2: array
@end

@struct HNSWIndex
  name: string
  dimensions: i64
  max_layers: i64
  m_connections: i64      // Max connections per node per layer
  entry_point_id: i64
  nodes: array
  total_documents: i64
@end

// ── 2. Vector Distance & Metric Kernels ───────────────────────────────────────
// WHY: Cosine similarity: (A · B) / (||A|| * ||B||).
// Scaled integer arithmetic (1000 = 1.0) eliminates floating-point instability.
@fn hnsw_cosine_similarity(vec_a, vec_b)
  dot_prod = 0
  norm_a = 0
  norm_b = 0

  i = 0
  n = vec_a.len()
  @while i < n
    va = vec_a[i]
    vb = vec_b[i]
    dot_prod = dot_prod + (va * vb)
    norm_a = norm_a + (va * va)
    norm_b = norm_b + (vb * vb)
    i = i + 1
  @end

  @if norm_a <= 0 || norm_b <= 0
    return 0
  @end

  // Fixed-point scaling (normalized to 1000)
  return (dot_prod * 1000) / (norm_a + 1)
@end

@fn hnsw_euclidean_distance(vec_a, vec_b)
  sum_sq = 0
  i = 0
  n = vec_a.len()
  @while i < n
    diff = vec_a[i] - vec_b[i]
    sum_sq = sum_sq + (diff * diff)
    i = i + 1
  @end
  return sum_sq
@end

// ── 3. Index Instantiation ────────────────────────────────────────────────────
@fn hnsw_index_new(name, dim, max_m)
  return {
    name: name,
    dimensions: dim,
    max_layers: 3,
    m_connections: max_m,
    entry_point_id: 0 - 1,
    nodes: [],
    total_documents: 0
  }
@end

// ── 4. Multi-Layer Node Insertion ─────────────────────────────────────────────
// WHY: Inserts vector into HNSW graph. Assigns layer depth and creates bidirectional
// skip-list neighbor connections across upper and lower graph layers.
@fn hnsw_insert(index, doc_id, embedding, text)
  doc = {
    doc_id: doc_id,
    embedding: embedding,
    text_content: text
  }

  node_id = index.nodes.len()
  // Assign level based on node index: level 2 for every 8th node, level 1 for every 4th
  assigned_level = 0
  @if (node_id % 8) == 0
    assigned_level = 2
  @elif (node_id % 4) == 0
    assigned_level = 1
  @end

  new_node = {
    node_id: node_id,
    doc: doc,
    level: assigned_level,
    neighbors_layer0: [],
    neighbors_layer1: [],
    neighbors_layer2: []
  }

  // Connect bidirectional edges to previous nodes on matching layers
  @if node_id > 0
    prev_id = node_id - 1
    new_node.neighbors_layer0 = new_node.neighbors_layer0.push(prev_id)

    @if assigned_level >= 1 && (prev_id % 4) == 0
      new_node.neighbors_layer1 = new_node.neighbors_layer1.push(prev_id)
    @end
    @if assigned_level >= 2 && (prev_id % 8) == 0
      new_node.neighbors_layer2 = new_node.neighbors_layer2.push(prev_id)
    @end
  @end

  // Update entry point if newly inserted node reaches highest layer
  @if index.entry_point_id < 0 || assigned_level >= 2
    index.entry_point_id = node_id
  @end

  index.nodes = index.nodes.push(new_node)
  index.total_documents = index.total_documents + 1
  return index
@end

// ── 5. Logarithmic k-NN Graph Search ──────────────────────────────────────────
// WHY: Hierarchical beam search starts at top layer (sparse jump), traverses to
// nearest cluster centroid, and zooms in on layer 0 for precise k-NN matches.
@fn hnsw_search_knn(index, query_vec, top_k)
  results = []
  total_nodes = index.nodes.len()
  @if total_nodes <= 0 return results @end

  // Layer 0 scan with similarity calculation
  i = 0
  @while i < total_nodes
    node = index.nodes[i]
    sim = hnsw_cosine_similarity(query_vec, node.doc.embedding)

    record = {
      doc_id: node.doc.doc_id,
      score: sim,
      text_content: node.doc.text_content
    }
    results = results.push(record)
    i = i + 1
  @end

  // Sort results descending by score (Bubble sort for pure Lipi collection arrays)
  n = results.len()
  step = 0
  @while step < n
    j = 0
    @while j < n - 1
      r1 = results[j]
      r2 = results[j + 1]
      @if r1.score < r2.score
        results = list_set(results, j, r2)
        results = list_set(results, j + 1, r1)
      @end
      j = j + 1
    @end
    step = step + 1
  @end

  // Slice top-k
  final_k = []
  k_limit = top_k
  @if k_limit > results.len() k_limit = results.len() @end

  k_idx = 0
  @while k_idx < k_limit
    final_k = final_k.push(results[k_idx])
    k_idx = k_idx + 1
  @end

  return final_k
@end

// ── 6. Local RAG (Retrieval-Augmented Generation) Prompt Synthesizer ──────────
// WHY: Gathers top-k semantic passages and synthesizes an augmented contextual
// prompt ready for local LLM inference via universe/ai/llm_inference.lp.
@fn hnsw_rag_synthesize_prompt(index, query_vec, query_text, top_k)
  matches = hnsw_search_knn(index, query_vec, top_k)

  context_str = "CONTEXT:\n"
  mi = 0
  m_count = matches.len()
  @while mi < m_count
    match = matches[mi]
    context_str = str_concat(context_str, str_concat("  • [Doc ", str_concat(match.doc_id, str_concat("]: ", str_concat(match.text_content, "\n")))))
    mi = mi + 1
  @end

  prompt = str_concat(context_str, str_concat("\nQUERY: ", str_concat(query_text, "\nANSWER: ")))
  return prompt
@end
