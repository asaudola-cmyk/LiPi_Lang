"""
লিপি ২.০ Standard Library Modules
WHY: Additional stdlib functions separated for optional inclusion.
Core builtins are already in interpreter.py _load_stdlib().
"""


def get_math_builtins():
    """Math functions for optional inclusion."""
    import math
    return {
        'sqrt': math.sqrt,
        'floor': math.floor,
        'ceil': math.ceil,
        'round': round,
        'pow': pow,
        'sin': math.sin,
        'cos': math.cos,
        'tan': math.tan,
        'log': math.log,
        'log2': math.log2,
        'log10': math.log10,
        'pi': math.pi,
        'e': math.e,
        'inf': math.inf,
    }


def get_string_builtins():
    """String manipulation functions."""
    return {
        'upper': lambda s: s.upper(),
        'lower': lambda s: s.lower(),
        'trim': lambda s: s.strip(),
        'ltrim': lambda s: s.lstrip(),
        'rtrim': lambda s: s.rstrip(),
        'split': lambda s, sep=' ': s.split(sep),
        'join': lambda sep, lst: sep.join(str(i) for i in lst),
        'contains': lambda s, sub: sub in s,
        'starts_with': lambda s, pre: s.startswith(pre),
        'ends_with': lambda s, suf: s.endswith(suf),
        'replace': lambda s, old, new: s.replace(old, new),
        'repeat_str': lambda s, n: s * n,
        'char_at': lambda s, i: s[i],
        'substring': lambda s, start, end=None: s[start:end],
    }


def get_list_builtins():
    """List/array functions."""
    return {
        'push': lambda lst, item: lst.append(item) or lst,
        'pop': lambda lst: lst.pop(),
        'first': lambda lst: lst[0] if lst else None,
        'last': lambda lst: lst[-1] if lst else None,
        'reverse': lambda lst: lst[::-1],
        'sort': lambda lst: sorted(lst),
        'filter': lambda fn, lst: [x for x in lst if fn(x)],
        'map': lambda fn, lst: [fn(x) for x in lst],
        'sum': sum,
        'any': lambda lst: any(lst),
        'all': lambda lst: all(lst),
    }


def load_stdlib(env, modules=None):
    """Load stdlib modules into an Environment.
    WHY: Allow selective loading of stdlib modules.
    Usage: load_stdlib(interpreter.global_env, ['math', 'string'])
    """
    all_modules = {
        'math': get_math_builtins,
        'string': get_string_builtins,
        'list': get_list_builtins,
    }
    if modules is None:
        modules = list(all_modules.keys())
    for mod_name in modules:
        if mod_name in all_modules:
            for name, fn in all_modules[mod_name]().items():
                env.set(name, fn)
