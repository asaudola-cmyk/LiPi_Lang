<?php

declare(strict_types=1);

namespace Unum\Lipi;

/**
 * 📜 Lipi Programming Language Abstract Syntax Tree (AST) Hierarchy
 *
 * WHY: Represents the parsed structural grammar of Lipi programs.
 * Distinguishes executable statements from value-producing expressions.
 * Clean, immutable node structures enable both high-speed interpreted execution
 * and direct lowering into UNUM 64-bit Universal Numbers and machine code.
 *
 * @author Shafiullah (Gyani Supreme Core)
 */
abstract class LipiAstNode
{
    public function __construct(
        public readonly int $line,
        public readonly int $column
    ) {
    }
}

// =============================================================================
// STATEMENTS
// =============================================================================

abstract class LipiStmt extends LipiAstNode
{
}

/** Root program container */
final class ProgramNode extends LipiStmt
{
    /**
     * @param list<LipiStmt> $statements
     */
    public function __construct(
        public readonly array $statements,
        int $line = 1,
        int $column = 1
    ) {
        parent::__construct($line, $column);
    }
}

/** Block statement: { stmt1; stmt2; } */
final class BlockStmt extends LipiStmt
{
    /**
     * @param list<LipiStmt> $statements
     */
    public function __construct(
        public readonly array $statements,
        int $line,
        int $column
    ) {
        parent::__construct($line, $column);
    }
}

/** Variable declaration: ধরি x = 10 or let x = 10 */
final class VarDeclStmt extends LipiStmt
{
    public function __construct(
        public readonly string $name,
        public readonly ?LipiExpr $initializer,
        public readonly bool $isConst,
        int $line,
        int $column,
        public readonly ?string $typeAnnotation = null
    ) {
        parent::__construct($line, $column);
    }
}

/** Function declaration: কাজ যোগ(ক, খ) { ... } */
final class FnDeclStmt extends LipiStmt
{
    /**
     * @param list<string> $params
     */
    public function __construct(
        public readonly string $name,
        public readonly array $params,
        public readonly BlockStmt $body,
        int $line,
        int $column
    ) {
        parent::__construct($line, $column);
    }
}

/** If conditional: যদি শর্ত { ... } নাহলে { ... } */
final class IfStmt extends LipiStmt
{
    /**
     * @param list<array{condition: LipiExpr, branch: BlockStmt}> $elifBranches
     */
    public function __construct(
        public readonly LipiExpr $condition,
        public readonly BlockStmt $thenBranch,
        public readonly array $elifBranches,
        public readonly ?BlockStmt $elseBranch,
        int $line,
        int $column
    ) {
        parent::__construct($line, $column);
    }
}

/** While loop: যতক্ষণ শর্ত { ... } */
final class WhileStmt extends LipiStmt
{
    public function __construct(
        public readonly LipiExpr $condition,
        public readonly BlockStmt $body,
        int $line,
        int $column
    ) {
        parent::__construct($line, $column);
    }
}

/** For collection iteration: প্রতিটি উপাদান ভেতরে তালিকা { ... } */
final class ForStmt extends LipiStmt
{
    public function __construct(
        public readonly string $varName,
        public readonly LipiExpr $iterable,
        public readonly BlockStmt $body,
        int $line,
        int $column
    ) {
        parent::__construct($line, $column);
    }
}

/** Return statement: ফেরত মান */
final class ReturnStmt extends LipiStmt
{
    public function __construct(
        public readonly ?LipiExpr $value,
        int $line,
        int $column
    ) {
        parent::__construct($line, $column);
    }
}

/** Break loop */
final class BreakStmt extends LipiStmt
{
}

/** Continue loop */
final class ContinueStmt extends LipiStmt
{
}

/** Show/print output: দেখাও "হ্যালো" */
final class ShowStmt extends LipiStmt
{
    /**
     * @param list<LipiExpr> $expressions
     */
    public function __construct(
        public readonly array $expressions,
        int $line,
        int $column
    ) {
        parent::__construct($line, $column);
    }
}

/** Expression as a statement */
final class ExprStmt extends LipiStmt
{
    public function __construct(
        public readonly LipiExpr $expression,
        int $line,
        int $column
    ) {
        parent::__construct($line, $column);
    }
}

/** Built-in Server Statement: সার্ভার.চালু(পোর্ট: ৮০৮০) { req, res -> ... } */
final class ServerStmt extends LipiStmt
{
    public function __construct(
        public readonly LipiExpr $portExpr,
        public readonly FnExpr $handler,
        int $line,
        int $column
    ) {
        parent::__construct($line, $column);
    }
}

/** Module Import Statement: আমদানি "ফাইল.lp" হিসেবে মডিউল or import "file.lp" as mod */
final class ImportStmt extends LipiStmt
{
    public function __construct(
        public readonly string $path,
        public readonly ?string $alias,
        int $line,
        int $column
    ) {
        parent::__construct($line, $column);
    }
}

/** Struct / Record Declaration: গঠন শিক্ষার্থী { নাম, বয়স, রোল } */
final class StructDeclStmt extends LipiStmt
{
    /**
     * @param list<string> $fields
     * @param list<FnDeclStmt> $methods
     */
    public function __construct(
        public readonly string $name,
        public readonly array $fields,
        public readonly array $methods,
        int $line,
        int $column
    ) {
        parent::__construct($line, $column);
    }
}

/** Exception Handling Statement: চেষ্টা { ... } ধরো এরর { ... } */
final class TryCatchStmt extends LipiStmt
{
    public function __construct(
        public readonly BlockStmt $tryBranch,
        public readonly string $errorVar,
        public readonly BlockStmt $catchBranch,
        int $line,
        int $column
    ) {
        parent::__construct($line, $column);
    }
}

/** Exception Throw Statement: নিক্ষেপ "ভুল ইনপুট" or throw "Invalid input" */
final class ThrowStmt extends LipiStmt
{
    public function __construct(
        public readonly LipiExpr $expression,
        int $line,
        int $column
    ) {
        parent::__construct($line, $column);
    }
}

// =============================================================================
// EXPRESSIONS
// =============================================================================

abstract class LipiExpr extends LipiAstNode
{
}

/** Literal value: number, string, boolean, null */
final class LiteralExpr extends LipiExpr
{
    public function __construct(
        public readonly mixed $value,
        int $line,
        int $column
    ) {
        parent::__construct($line, $column);
    }
}

/** Variable reference: নাম */
final class VariableExpr extends LipiExpr
{
    public function __construct(
        public readonly string $name,
        int $line,
        int $column
    ) {
        parent::__construct($line, $column);
    }
}

/** Variable/Property Assignment: x = 20 or arr[0] = 5 */
final class AssignExpr extends LipiExpr
{
    public function __construct(
        public readonly LipiExpr $target,
        public readonly string $operator,
        public readonly LipiExpr $value,
        int $line,
        int $column
    ) {
        parent::__construct($line, $column);
    }
}

/** Binary operation: a + b, x == y, etc. */
final class BinaryExpr extends LipiExpr
{
    public function __construct(
        public readonly LipiExpr $left,
        public readonly string $operator,
        public readonly LipiExpr $right,
        int $line,
        int $column
    ) {
        parent::__construct($line, $column);
    }
}

/** Unary operation: -x, !flag, etc. */
final class UnaryExpr extends LipiExpr
{
    public function __construct(
        public readonly string $operator,
        public readonly LipiExpr $right,
        int $line,
        int $column
    ) {
        parent::__construct($line, $column);
    }
}

/** Function call: যোগ(১০, ২০) */
final class CallExpr extends LipiExpr
{
    /**
     * @param list<LipiExpr> $arguments
     */
    public function __construct(
        public readonly LipiExpr $callee,
        public readonly array $arguments,
        int $line,
        int $column
    ) {
        parent::__construct($line, $column);
    }
}

/** Array literal: [১, ২, ৩, "চার"] */
final class ArrayExpr extends LipiExpr
{
    /**
     * @param list<LipiExpr> $elements
     */
    public function __construct(
        public readonly array $elements,
        int $line,
        int $column
    ) {
        parent::__construct($line, $column);
    }
}

/** Map/Dictionary literal: {"নাম": "শফিউল্লাহ", "বয়স": ২৫} */
final class MapExpr extends LipiExpr
{
    /**
     * @param list<array{key: LipiExpr, value: LipiExpr}> $entries
     */
    public function __construct(
        public readonly array $entries,
        int $line,
        int $column
    ) {
        parent::__construct($line, $column);
    }
}

/** Index lookup: arr[০] or map["কী"] */
final class IndexExpr extends LipiExpr
{
    public function __construct(
        public readonly LipiExpr $object,
        public readonly LipiExpr $index,
        int $line,
        int $column
    ) {
        parent::__construct($line, $column);
    }
}

/** Property/Member access: obj.prop */
final class MemberExpr extends LipiExpr
{
    public function __construct(
        public readonly LipiExpr $object,
        public readonly string $property,
        int $line,
        int $column
    ) {
        parent::__construct($line, $column);
    }
}

/** Anonymous function / Closure: কাজ(ক, খ) { ফেরত ক + খ } or (a, b) -> a + b */
final class FnExpr extends LipiExpr
{
    /**
     * @param list<string> $params
     */
    public function __construct(
        public readonly array $params,
        public readonly BlockStmt $body,
        int $line,
        int $column
    ) {
        parent::__construct($line, $column);
    }
}

/** Struct Instantiation: নতুন শিক্ষার্থী(নাম: "শফিউল্লাহ", বয়স: ২৫) or new Student("Shafiullah", 25) */
final class NewExpr extends LipiExpr
{
    /**
     * @param list<LipiExpr> $arguments
     * @param array<string, LipiExpr> $namedArguments
     */
    public function __construct(
        public readonly string $structName,
        public readonly array $arguments = [],
        public readonly array $namedArguments = [],
        int $line = 1,
        int $column = 1
    ) {
        parent::__construct($line, $column);
    }
}

