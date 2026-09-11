@! ============================================================================
@! MAYA UNIVERSE DB - SEARCH ENGINE (universe/db/search.maya)
@! 100% Pure Maya Implementation — Zero External / C Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@struct InvertedIndex
  doc_count: 0,
  avg_doc_len: 0.0,
  postings: {}, @! term -> [{doc_id: 1, tf: 2}]
  doc_lens: {}  @! doc_id -> length
@end

@fn new_inverted_index()
  return {
    doc_count: 0,
    avg_doc_len: 0.0,
    postings: {},
    doc_lens: {}
  }
@end

@fn porter_stemmer(word)
  @if word.len() <= 3
    return word
  @end

  @! Suffix normalization rules
  @if string_ends_with(word, "sses")
    return string_slice(word, 0, word.len() - 2)
  @elif string_ends_with(word, "ies")
    return string_slice(word, 0, word.len() - 2)
  @elif string_ends_with(word, "ing") && word.len() > 5
    return string_slice(word, 0, word.len() - 3)
  @elif string_ends_with(word, "ed") && word.len() > 4
    return string_slice(word, 0, word.len() - 2)
  @elif string_ends_with(word, "s") && !string_ends_with(word, "ss")
    return string_slice(word, 0, word.len() - 1)
  @end

  return word
@end

@fn bm25_score(tf, doc_len, avg_doc_len, df, total_docs)
  k1 = 1.2
  b = 0.75

  @! IDF = ln((N - n + 0.5) / (n + 0.5) + 1.0)
  numerator = (total_docs - df) + 0.5
  denominator = df + 0.5
  idf_ratio = numerator / denominator
  @if idf_ratio < 0.01 idf_ratio = 0.01 @end

  @! Term frequency saturation with length normalization
  len_norm = 1.0 - b + b * (doc_len / avg_doc_len)
  tf_component = (tf * (k1 + 1.0)) / (tf + k1 * len_norm)

  return idf_ratio * tf_component
@end