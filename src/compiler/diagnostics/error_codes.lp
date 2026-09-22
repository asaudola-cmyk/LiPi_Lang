// ==============================================================================
// 👑 LIPI FIRST 1.0.0 COMPILER DIAGNOSTICS: STANDARD ERROR CODE CATALOG
// ⚡ 100% Pure Lipi First 1.0.0 | Zero Libc | Zero C | Direct Silicon
// 🏛️ File: src/compiler/diagnostics/error_codes.lp
//
// WHY: Enterprise compilers (e.g. rustc, clang, ghc) enforce stable, structured
//      error catalogs. Error codes (E0001..E0999) provide deterministic identifiers
//      for compiler diagnostic tooling, IDE integrations, documentation lookup,
//      and machine-readable triage pipelines.
// ==============================================================================

// ── Error Code Data Structure ────────────────────────────────────────────────
// WHY: Struct fields encapsulate the full identity, categorization, severity,
//      and human-readable guidance needed to generate high-fidelity diagnostics.
struct ErrorCode
    id
    name
    msg_template
    category
    default_severity
    explanation

// WHY: Allocates and initializes an immutable ErrorCode descriptor.
fn error_code_new id name msg_template category default_severity explanation
    ec = ErrorCode()
    ec.id = id
    ec.name = name
    ec.msg_template = msg_template
    ec.category = category
    ec.default_severity = default_severity
    ec.explanation = explanation
    return ec

// ── Error Code Catalog Registry ──────────────────────────────────────────────
// WHY: Central catalog list container enables O(N) lookup without dynamic hash maps,
//      guaranteeing zero external dependencies and deterministic execution.
struct ErrorCatalog
    codes
    count

// WHY: Creates an empty error catalog container.
fn error_catalog_create
    cat = ErrorCatalog()
    cat.codes = list()
    cat.count = 0
    return cat

// WHY: Registers a new error code into the catalog.
fn error_catalog_register cat ec
    push(cat.codes, ec)
    cat.count = cat.count + 1
    return ec

// WHY: Searches catalog for a specific error code string (e.g. "E0001").
// Returns the ErrorCode struct if found, or 0 if uncataloged.
fn error_catalog_find cat id
    n = cat.count
    i = 0
    while i < n
        candidate = cat.codes[i]
        if candidate.id == id
            return candidate
        i = i + 1
    return 0

// WHY: Formats standard diagnostic badge: "error[E0001]" or "warning[E0109]".
fn error_code_format_badge ec
    if ec == 0
        return "error"
    return ec.default_severity + "[" + ec.id + "]"

// WHY: Formats descriptive title: "E0001: UnexpectedToken".
fn error_code_format_title ec
    if ec == 0
        return "UnknownDiagnostic"
    return ec.id + ": " + ec.name

// WHY: Retrieves the detailed multi-sentence documentation explanation for a code.
fn error_catalog_get_explanation cat id
    ec = error_catalog_find(cat, id)
    if ec == 0
        return "No extended explanation available for uncataloged diagnostic code " + id + "."
    return ec.explanation

// ── Master Error Catalog Initializer ─────────────────────────────────────────
// WHY: Populates the standard enterprise catalog for all compiler stages:
//      - E0001..E0049: Lexer, Scanner & Syntax Parsing
//      - E0101..E0149: Type Checking & Static Semantics
//      - E0201..E0249: Name Resolution, Symbols & Struct Fields
//      - E0301..E0349: Module System, Imports & Filesystem
//      - E0401..E0449: Codegen, Hardware Registers & ABI
//      - E0901..E0949: Internal Compiler Errors & Resource Limits
fn error_catalog_init
    cat = error_catalog_create()

    // ── 1. Syntax & Lexing (E0001..E0012) ────────────────────────────────────
    error_catalog_register(cat, error_code_new(
        "E0001",
        "UnexpectedToken",
        "unexpected token encountered during parsing",
        "Syntax",
        "error",
        "The parser encountered a token that does not conform to the LiPi grammar at this position. Check for missing punctuation, mismatched parentheses, or malformed statements."
    ))

    error_catalog_register(cat, error_code_new(
        "E0002",
        "UnterminatedString",
        "string literal not terminated before end of line or file",
        "Syntax",
        "error",
        "A string literal began with an opening quote but was not closed before the end of the line or the file. Ensure every double or single quotation mark is properly closed."
    ))

    error_catalog_register(cat, error_code_new(
        "E0003",
        "UnterminatedComment",
        "multi-line comment not closed with '*/'",
        "Syntax",
        "error",
        "A block comment was opened with '/*' but the compiler reached the end of the file without finding the closing '*/' delimiter."
    ))

    error_catalog_register(cat, error_code_new(
        "E0004",
        "InvalidIndentation",
        "inconsistent indentation level in block",
        "Syntax",
        "error",
        "LiPi indentation syntax requires consistent spacing (e.g. 4 spaces) across statements in the same scope block. Mixed tabs and spaces or misaligned indentation are prohibited."
    ))

    error_catalog_register(cat, error_code_new(
        "E0005",
        "ExpectedExpression",
        "expected an expression but found statement or keyword",
        "Syntax",
        "error",
        "The grammar expected a valid value expression (variable, literal, binary operation, or call), but encountered an empty position or statement keyword."
    ))

    error_catalog_register(cat, error_code_new(
        "E0006",
        "InvalidNumberLiteral",
        "malformed numeric literal",
        "Syntax",
        "error",
        "The numeric token could not be parsed as a valid integer, hexadecimal, or floating-point constant. Check for illegal digit characters or misplaced radix prefixes."
    ))

    error_catalog_register(cat, error_code_new(
        "E0007",
        "UnmatchedDelimiter",
        "unmatched opening delimiter",
        "Syntax",
        "error",
        "An opening parenthesis '(', bracket '[', or brace '{' does not have a corresponding closing delimiter of the same type."
    ))

    error_catalog_register(cat, error_code_new(
        "E0008",
        "InvalidAssignmentTarget",
        "left-hand side of assignment is not a valid mutable target",
        "Syntax",
        "error",
        "Assignments require an lvalue target such as an identifier, struct field ('obj.field'), or array slot ('arr[index]'). Constant literals or complex expressions cannot be assigned to."
    ))

    error_catalog_register(cat, error_code_new(
        "E0009",
        "ExpectedIdentifier",
        "expected identifier name",
        "Syntax",
        "error",
        "A declaration (e.g. 'fn', 'struct', 'var') must be followed by a valid identifier symbol name."
    ))

    error_catalog_register(cat, error_code_new(
        "E0010",
        "DuplicateFieldDef",
        "duplicate field definition in struct declaration",
        "Syntax",
        "error",
        "A field name within a struct definition was specified more than once. Each field in a LiPi struct layout must have a unique identifier."
    ))

    error_catalog_register(cat, error_code_new(
        "E0011",
        "InvalidEscapeSequence",
        "unrecognized escape sequence in string literal",
        "Syntax",
        "error",
        "An unrecognized character followed a backslash escape character in a string literal. LiPi supports '\\n', '\\r', '\\t', '\\\\', '\\\"', and '\\xHH' escape sequences."
    ))

    error_catalog_register(cat, error_code_new(
        "E0012",
        "MissingFunctionBody",
        "function declaration lacks a body block or return statement",
        "Syntax",
        "error",
        "A function was declared with parameter names, but has no subsequent indented statements or return expression."
    ))

    // ── 2. Type Checking & Semantics (E0101..E0110) ──────────────────────────
    error_catalog_register(cat, error_code_new(
        "E0101",
        "TypeMismatch",
        "mismatched types in expression or assignment",
        "Type",
        "error",
        "The operation expected a specific data type but received an incompatible type. LiPi enforces monomorphic ALU operations and static type boundaries."
    ))

    error_catalog_register(cat, error_code_new(
        "E0102",
        "InvalidOperandTypes",
        "binary or unary operator cannot be applied to operand types",
        "Type",
        "error",
        "The operator is not defined for the given operand types (for example, attempting integer arithmetic on unaligned struct pointers)."
    ))

    error_catalog_register(cat, error_code_new(
        "E0103",
        "ReturnTypeMismatch",
        "function return expression does not match declared return type",
        "Type",
        "error",
        "The expression in the 'return' statement does not evaluate to the declared return type of the enclosing function signature."
    ))

    error_catalog_register(cat, error_code_new(
        "E0104",
        "NonCallableType",
        "attempted to invoke a value that is not a function",
        "Type",
        "error",
        "The expression being called does not resolve to a callable function pointer, closure, or method."
    ))

    error_catalog_register(cat, error_code_new(
        "E0105",
        "ArgumentCountMismatch",
        "function called with wrong number of arguments",
        "Type",
        "error",
        "The number of arguments provided in the call expression does not match the parameter count required by the function definition."
    ))

    error_catalog_register(cat, error_code_new(
        "E0106",
        "CannotIndexType",
        "type cannot be indexed with bracket notation",
        "Type",
        "error",
        "The target of the index operator ('obj[key]') is neither a list, an array, nor a string buffer."
    ))

    error_catalog_register(cat, error_code_new(
        "E0107",
        "ImmutableMutation",
        "cannot mutate immutable variable or read-only buffer",
        "Type",
        "error",
        "The target variable was declared as immutable or belongs to a read-only memory segment. Re-assignment is disallowed."
    ))

    error_catalog_register(cat, error_code_new(
        "E0108",
        "DivisionByZero",
        "compile-time constant division or modulo by zero",
        "Type",
        "error",
        "The divisor evaluated to a static integer zero, which would cause a hardware CPU divide error (SIGFPE) at runtime."
    ))

    error_catalog_register(cat, error_code_new(
        "E0109",
        "UnusedVariable",
        "variable bound but never accessed",
        "Type",
        "warning",
        "A local variable was assigned a value but is never read or referenced subsequently in its enclosing scope."
    ))

    error_catalog_register(cat, error_code_new(
        "E0110",
        "UnreachableCode",
        "unreachable code detected after terminating statement",
        "Type",
        "warning",
        "Statements placed after an unconditional 'return', 'exit', or infinite loop can never execute."
    ))

    // ── 3. Name Resolution & Symbols (E0201..E0207) ──────────────────────────
    error_catalog_register(cat, error_code_new(
        "E0201",
        "UndefinedSymbol",
        "cannot find symbol in current scope",
        "Resolution",
        "error",
        "The identifier is not defined in the local scope, parameter list, outer closure, or global module imports. Check for typos or missing includes."
    ))

    error_catalog_register(cat, error_code_new(
        "E0202",
        "DuplicateSymbol",
        "symbol already defined in this scope",
        "Resolution",
        "error",
        "An identifier with the same name was already declared in this lexical scope. Rename one of the declarations to prevent collisions."
    ))

    error_catalog_register(cat, error_code_new(
        "E0203",
        "NoSuchField",
        "struct layout does not contain field",
        "Resolution",
        "error",
        "The field name does not exist in the struct definition. Verify the struct definition or check for spelling errors."
    ))

    error_catalog_register(cat, error_code_new(
        "E0204",
        "NoSuchMethod",
        "no method with this name found for type",
        "Resolution",
        "error",
        "The method does not exist on the target struct type. Verify that the method was declared via 'fn Struct.method self ...' or within an '@impl' block."
    ))

    error_catalog_register(cat, error_code_new(
        "E0205",
        "ShadowedVariable",
        "inner variable shadows declaration in outer scope",
        "Resolution",
        "warning",
        "The identifier in the nested block has the same name as a variable in the outer block, obscuring access to the outer variable."
    ))

    error_catalog_register(cat, error_code_new(
        "E0206",
        "PrivateSymbolAccess",
        "attempted access to private symbol from external module",
        "Resolution",
        "error",
        "The requested function, struct, or constant is not marked for export and cannot be referenced outside its home module."
    ))

    error_catalog_register(cat, error_code_new(
        "E0207",
        "CircularDependency",
        "circular dependency detected between modules",
        "Resolution",
        "error",
        "A cycle was detected in the include/import dependency graph. Break the cycle by factoring shared types into a common module."
    ))

    // ── 4. Module System & Filesystem (E0301..E0304) ─────────────────────────
    error_catalog_register(cat, error_code_new(
        "E0301",
        "ModuleNotFound",
        "included or imported source file not found",
        "Module",
        "error",
        "The path specified in the 'include' or 'import' directive could not be resolved on the filesystem or within the LiPi sysroot."
    ))

    error_catalog_register(cat, error_code_new(
        "E0302",
        "PermissionDenied",
        "permission denied reading source file",
        "Module",
        "error",
        "The operating system denied read access to the specified source file path."
    ))

    error_catalog_register(cat, error_code_new(
        "E0303",
        "EmptySourceFile",
        "source file contains zero bytes",
        "Module",
        "warning",
        "The source file opened successfully but has a size of 0 bytes."
    ))

    error_catalog_register(cat, error_code_new(
        "E0304",
        "InvalidModulePath",
        "module import path contains illegal characters",
        "Module",
        "error",
        "The include/import string contains invalid filesystem characters or illegal directory traversal patterns."
    ))

    // ── 5. Codegen & Hardware Backend (E0401..E0405) ─────────────────────────
    error_catalog_register(cat, error_code_new(
        "E0401",
        "RegisterSpillOverflow",
        "register allocator exhausted scratch registers",
        "Codegen",
        "error",
        "The expression complexity exceeded available CPU physical hardware registers and the stack frame spill capacity."
    ))

    error_catalog_register(cat, error_code_new(
        "E0402",
        "UnsupportedTarget",
        "compilation target is not supported",
        "Codegen",
        "error",
        "The requested compilation backend target is not supported by the LiPi sovereign compiler. Supported targets: x86_64, arm64, wasm."
    ))

    error_catalog_register(cat, error_code_new(
        "E0403",
        "InvalidSyscallNumber",
        "syscall number exceeds valid architecture range",
        "Codegen",
        "error",
        "The syscall integer passed to 'syscall(...)' is outside the valid Linux kernel syscall range for the current target architecture."
    ))

    error_catalog_register(cat, error_code_new(
        "E0404",
        "RelocationOutOfRange",
        "branch displacement exceeds 32-bit relative displacement",
        "Codegen",
        "error",
        "The distance between the call/jump site and the target symbol exceeds the 32-bit sign-extended displacement limit."
    ))

    error_catalog_register(cat, error_code_new(
        "E0405",
        "MemoryAlignmentViolation",
        "vector or atomic instruction requires aligned pointer",
        "Codegen",
        "error",
        "AVX2 / AVX-512 SIMD vector operations or atomic memory instructions require pointers aligned to natural memory boundaries (e.g. 32 or 64 bytes)."
    ))

    // ── 6. Internal Compiler Errors & Limits (E0901..E0903) ──────────────────
    error_catalog_register(cat, error_code_new(
        "E0901",
        "InternalCompilerError",
        "internal compiler error: invariant assertion failed",
        "Internal",
        "error",
        "The compiler encountered an illegal internal invariant violation. This represents an unexpected state inside the compiler pipeline."
    ))

    error_catalog_register(cat, error_code_new(
        "E0902",
        "OutOfMemory",
        "compiler memory budget exhausted",
        "Internal",
        "error",
        "The compiler exceeded available system virtual memory during AST construction or code generation."
    ))

    error_catalog_register(cat, error_code_new(
        "E0903",
        "RecursionLimitExceeded",
        "macro or expression expansion recursion depth limit exceeded",
        "Internal",
        "error",
        "The parser or evaluator exceeded the maximum recursion depth limit (128 frames) while expanding nested expressions or macros."
    ))

    return cat
