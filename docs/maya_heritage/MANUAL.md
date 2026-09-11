# Maya Language Manual

## Language Philosophy
"Maya is the Universe". Maya is designed to be a universal programming language, capable of handling everything from systems programming to web development, AI, and GPU acceleration.

## Complete Syntax Guide

### Functions
Functions are defined using `@fn` and closed with `@end`.
```maya
@fn greet(name: string) -> string
    return "Hello, " + name
@end
```

### Structs
Structs are defined using `@struct` and closed with `@end`.
```maya
@struct Point
    x: i64
    y: i64
@end
```

### Implementations
Methods for structs are defined using `@impl`.
```maya
@impl Point
    @fn distance(self, other: Point) -> f64
        // ...
    @end
@end
```

### Enums
Enums are defined using `@enum`.
```maya
@enum State
    Pending,
    Running,
    Completed
@end
```

### Control Flow
```maya
// If/Elif/Else
@if condition
    // ...
@elif other_condition
    // ...
@else
    // ...
@end

// While Loop
@while condition
    // ...
@end

// For Loop
@for item in array
    // ...
@end

@for i in 0..10
    // ...
@end
```

## Types
- `i64`: 64-bit integer
- `f64`: 64-bit float
- `string`: UTF-8 encoded string
- `bool`: Boolean (`true` or `false`)
- `array`: Dynamically sized array, e.g. `[i64]`
- `struct`: User-defined structured types
- `map`: Key-value map, e.g. `map<string, i64>`
- `Result<T, E>`: For error handling
- `Option<T>`: Optional value

## Builtins, Syscalls, String Interpolation, Error Handling
- **Builtins**: `print`, `println`, `len`, `push`, `pop`.
- **String Interpolation**: Supports interpolation natively.
- **Syscalls**: Direct OS system call access via `syscall(num, args...)`.
- **Error Handling**: Uses `Result<T>` and `Option<T>` with implicit or explicit propagation.

## Tooling
- **Compiler**: `maya` (`./bin/maya file.maya`)
- **Package Manager**: `mpm`
- **Formatter**: `maya fmt`
- **LSP**: `maya lsp`
- **REPL**: `cmd/repl.maya`
