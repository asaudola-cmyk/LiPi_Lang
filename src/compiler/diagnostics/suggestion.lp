// ==============================================================================
// 👑 LIPI FIRST 1.0.0 COMPILER DIAGNOSTICS: LEVENSHTEIN SPELLING SUGGESTER
// ⚡ 100% Pure Lipi First 1.0.0 | Zero Libc | Zero C | Direct Silicon
// 🏛️ File: src/compiler/diagnostics/suggestion.lp
//
// WHY: Typo tolerance dramatically reduces developer frustration during compilation.
//      When an undefined symbol, keyword, or struct field is encountered,
//      a deterministic Levenshtein distance suggester identifies likely intended
//      identifiers (e.g. "Did you mean 'count'?" when 'cont' is typed).
// ==============================================================================

// ── Case Normalization Helpers ───────────────────────────────────────────────
// WHY: Case-insensitive comparison allows suggesting 'Point' when 'point' is typed.
fn to_lower_char ch
    code = ord(ch)
    if code >= 65 and code <= 90
        return chr(code + 32)
    return ch

fn str_to_lower s
    slen = len(s)
    if slen == 0
        return ""
    res = ""
    i = 0
    while i < slen
        res = res + to_lower_char(char_at(s, i))
        i = i + 1
    return res

// ── Math Minimum Helper ──────────────────────────────────────────────────────
fn min2 a b
    if a < b
        return a
    return b

fn min3 a b c
    m = a
    if b < m
        m = b
    if c < m
        m = c
    return m

// ── Memory-Optimized Levenshtein Distance Algorithm ──────────────────────────
// WHY: Classic Wagner-Fischer algorithm using 2-row rolling buffer O(min(M, N)) space.
//      Avoids (M+1)*(N+1) heap matrix allocation, making it lightweight for fast compilation.
fn levenshtein_distance s1 s2
    len1 = len(s1)
    len2 = len(s2)

    // Fast-path trivial edge cases
    if s1 == s2
        return 0
    if len1 == 0
        return len2
    if len2 == 0
        return len1

    // Orient strings so s2 is shorter, minimizing row buffer allocations
    str_a = s1
    str_b = s2
    m = len1
    n = len2
    if n > m
        str_a = s2
        str_b = s1
        m = len2
        n = len1

    // Initialize previous row [0, 1, 2, ..., n]
    prev_row = list()
    j = 0
    while j <= n
        push(prev_row, j)
        j = j + 1

    curr_row = list()
    j = 0
    while j <= n
        push(curr_row, 0)
        j = j + 1

    i = 1
    while i <= m
        curr_row[0] = i
        ca = char_at(str_a, i - 1)

        j = 1
        while j <= n
            cb = char_at(str_b, j - 1)
            cost = 1
            if ca == cb
                cost = 0

            del_cost = prev_row[j] + 1
            ins_cost = curr_row[j - 1] + 1
            sub_cost = prev_row[j - 1] + cost

            curr_row[j] = min3(del_cost, ins_cost, sub_cost)
            j = j + 1

        // Copy curr_row into prev_row for next iteration
        k = 0
        while k <= n
            prev_row[k] = curr_row[k]
            k = k + 1

        i = i + 1

    return prev_row[n]

// ── Case-Insensitive Levenshtein Distance ─────────────────────────────────────
// WHY: Handles casing mistakes (e.g. 'Print' vs 'print') with distance 0 substitution.
fn levenshtein_distance_ci s1 s2
    return levenshtein_distance(str_to_lower(s1), str_to_lower(s2))

// ── Suggestion Threshold Evaluator ───────────────────────────────────────────
// WHY: Dynamically computes maximum allowable edit distance based on target token length.
//      Short words (length <= 3) permit at most 1 edit; long words permit 2-3 edits.
fn suggestion_max_threshold word_len
    if word_len <= 3
        return 1
    if word_len <= 6
        return 2
    return 3

// ── Best Suggestion Candidate Finder ─────────────────────────────────────────
// WHY: Searches candidate identifier list for the closest spelling match within threshold.
//      Returns the best matching string, or "" if no candidates meet the threshold.
fn suggestion_find_best target candidates
    tlen = len(target)
    if tlen == 0 or len(candidates) == 0
        return ""

    threshold = suggestion_max_threshold(tlen)
    best_match = ""
    best_dist = 999999

    n = len(candidates)
    i = 0
    while i < n
        cand = candidates[i]
        dist = levenshtein_distance(target, cand)

        // Case-insensitive bonus: check if lowercased match is exact or closer
        dist_ci = levenshtein_distance_ci(target, cand)
        effective_dist = dist
        if dist_ci < dist
            effective_dist = dist_ci

        if effective_dist < best_dist and effective_dist <= threshold
            best_dist = effective_dist
            best_match = cand

        i = i + 1

    return best_match

// ── Top-K Candidates Finder ──────────────────────────────────────────────────
// WHY: When multiple symbols are equally plausible, returns up to K nearest matches.
fn suggestion_find_top_k target candidates k
    res = list()
    if len(target) == 0 or len(candidates) == 0 or k <= 0
        return res

    threshold = suggestion_max_threshold(len(target))
    n = len(candidates)

    // Collect candidates with their distances
    dists = list()
    filtered = list()

    i = 0
    while i < n
        cand = candidates[i]
        d = levenshtein_distance(target, cand)
        d_ci = levenshtein_distance_ci(target, cand)
        if d_ci < d
            d = d_ci

        if d <= threshold
            push(filtered, cand)
            push(dists, d)
        i = i + 1

    // Sort by distance (simple selection sort since filtered list is small)
    m = len(filtered)
    si = 0
    while si < m
        min_idx = si
        sj = si + 1
        while sj < m
            if dists[sj] < dists[min_idx]
                min_idx = sj
            sj = sj + 1

        // Swap in filtered and dists
        if min_idx != si
            tmp_c = filtered[si]
            filtered[si] = filtered[min_idx]
            filtered[min_idx] = tmp_c

            tmp_d = dists[si]
            dists[si] = dists[min_idx]
            dists[min_idx] = tmp_d
        si = si + 1

    // Return top K
    limit = k
    if len(filtered) < limit
        limit = len(filtered)

    out = list()
    idx = 0
    while idx < limit
        push(out, filtered[idx])
        idx = idx + 1

    return out

// ── Diagnostic Message Formatters ────────────────────────────────────────────
// WHY: Formats standard user-facing guidance messages.
fn suggestion_format_did_you_mean suggestion
    if len(suggestion) == 0
        return ""
    return "did you mean '" + suggestion + "'?"

// WHY: Formats multiple candidate suggestions: "did you mean one of: 'foo', 'bar'?"
fn suggestion_format_choices candidates
    n = len(candidates)
    if n == 0
        return ""
    if n == 1
        return suggestion_format_did_you_mean(candidates[0])

    msg = "did you mean one of: "
    i = 0
    while i < n
        msg = msg + "'" + candidates[i] + "'"
        if i < n - 1
            msg = msg + ", "
        i = i + 1
    msg = msg + "?"
    return msg
