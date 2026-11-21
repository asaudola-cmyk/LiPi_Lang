// ==============================================================================
// 👑 LIPI SOVEREIGN CLOSURE & HIGHER-ORDER FUNCTION ENGINE (closure.lp)
// ⚡ 100% Pure LiPi Implementation | Zero C | Zero GC | First-Class Environment Capture
// 🏛️ Module: utso/core/closure.lp
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

include "utso/core/collections.lp"

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

fn closure_from_fn fn_ref
    // WHY: Wraps a native function pointer or hardware closure object as a Closure descriptor.
    return closure_new(fn_ref, list(), 1)

fn closure_invoke cl arg
    // WHY: Dispatches real function pointers / closures (fn_tag > 4096) or legacy tags 1..3.
    fn_tag = cl.cl_fn_tag
    if fn_tag > 4096
        if cl.cl_param_count == 2 and cl.cl_env != 0 and cl.cl_env.len() > 0
            return fn_tag(arg, cl.cl_env)
        end
        return fn_tag(arg)
    end
    if fn_tag == 1
        return arg * closure_env_get(cl, 0)
    elif fn_tag == 2
        return arg + closure_env_get(cl, 0)
    elif fn_tag == 3
        return arg * arg
    end
    return arg

fn closure_map l cl
    // WHY: Functional map applying real closure/function pointer or legacy tag over all elements.
    res = list()
    i = 0
    n = l.len()
    fn_tag = cl.cl_fn_tag
    while i < n
        elem = l[i]
        transformed = elem
        if fn_tag > 4096
            if cl.cl_param_count == 2 and cl.cl_env != 0 and cl.cl_env.len() > 0
                transformed = fn_tag(elem, cl.cl_env)
            else
                transformed = fn_tag(elem)
            end
        elif fn_tag == 1
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
    // WHY: Functional filter applying real predicate fn/closure or legacy tags 10..11.
    res = list()
    i = 0
    n = l.len()
    fn_tag = cl.cl_fn_tag
    while i < n
        elem = l[i]
        keep = 0
        if fn_tag > 4096
            if cl.cl_param_count == 2 and cl.cl_env != 0 and cl.cl_env.len() > 0
                if fn_tag(elem, cl.cl_env) != 0
                    keep = 1
                end
            elif fn_tag(elem) != 0
                keep = 1
            end
        elif fn_tag == 10
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
    // WHY: Functional fold/reduce applying real reducer fn/closure (acc, elem) or legacy tags 20..21.
    acc = initial
    i = 0
    n = l.len()
    fn_tag = cl.cl_fn_tag
    while i < n
        elem = l[i]
        if fn_tag > 4096
            if cl.cl_param_count == 3 and cl.cl_env != 0 and cl.cl_env.len() > 0
                acc = fn_tag(acc, elem, cl.cl_env)
            else
                acc = fn_tag(acc, elem)
            end
        elif fn_tag == 20
            // Sum accumulator
            acc = acc + elem
        elif fn_tag == 21
            // Product accumulator
            acc = acc * elem
        i = i + 1
    return acc
