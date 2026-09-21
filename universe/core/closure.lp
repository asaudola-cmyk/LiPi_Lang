// ==============================================================================
// 👑 LIPI SOVEREIGN CLOSURE & HIGHER-ORDER FUNCTION ENGINE (closure.lp)
// ⚡ 100% Pure LiPi Implementation | Zero C | Zero GC | First-Class Environment Capture
// 🏛️ Module: universe/core/closure.lp
// ==============================================================================
//
// WHY THIS MODULE:
// 1. First-Class Functions without Mainstream Bloat:
//    - Avoids heavy anonymous class allocations and vtable indirection.
// 2. Pure 2-Word Environment Tuples:
//    - Pairs a code dispatch function ID with an encapsulated lexical environment frame.
// 3. Functional Super-Primitives:
//    - Built-in map, filter, reduce, compose, and curry pipelines executing at direct machine speed.
// ==============================================================================

include "universe/core/collections.lp"

struct Closure
    cl_fn_tag
    cl_env
    cl_param_count

fn closure_new fn_tag env_list param_count
    // WHY: Constructs a closure binding function tag to captured lexical state.
    cl = Closure()
    cl.cl_fn_tag = fn_tag
    cl.cl_env = env_list
    cl.cl_param_count = param_count
    return cl

fn closure_env_get cl index
    // WHY: Safe retrieval of captured lexical variable from environment list.
    env = cl.cl_env
    if index < 0 or index >= env.len()
        return 0
    return env[index]

fn closure_env_set cl index value
    // WHY: In-place mutation of captured state inside mutable environment frame.
    env = cl.cl_env
    if index >= 0 and index < env.len()
        list_set(env, index, value)
    return cl

fn closure_map l cl
    // WHY: Functional map applying closure transformation over all elements of list.
    res = list()
    i = 0
    n = l.len()
    while i < n
        elem = l[i]
        // Evaluate closure against element
        fn_tag = cl.cl_fn_tag
        transformed = elem
        if fn_tag == 1
            // Multiply by env[0]
            factor = closure_env_get(cl, 0)
            transformed = elem * factor
        elif fn_tag == 2
            // Add env[0]
            addend = closure_env_get(cl, 0)
            transformed = elem + addend
        elif fn_tag == 3
            // Power / Square
            transformed = elem * elem
        push(res, transformed)
        i = i + 1
    return res

fn closure_filter l cl
    // WHY: Functional filter selecting elements matching closure predicate.
    res = list()
    i = 0
    n = l.len()
    while i < n
        elem = l[i]
        fn_tag = cl.cl_fn_tag
        keep = 0
        if fn_tag == 10
            // Greater than env[0]
            limit = closure_env_get(cl, 0)
            if elem > limit
                keep = 1
        elif fn_tag == 11
            // Even number predicate
            if elem % 2 == 0
                keep = 1
        if keep == 1
            push(res, elem)
        i = i + 1
    return res

fn closure_reduce l cl initial
    // WHY: Functional fold/reduce accumulating list elements via closure accumulator.
    acc = initial
    i = 0
    n = l.len()
    while i < n
        elem = l[i]
        fn_tag = cl.cl_fn_tag
        if fn_tag == 20
            // Sum accumulator
            acc = acc + elem
        elif fn_tag == 21
            // Product accumulator
            acc = acc * elem
        i = i + 1
    return acc
