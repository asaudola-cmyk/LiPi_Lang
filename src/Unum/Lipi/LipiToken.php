<?php

declare(strict_types=1);

namespace Unum\Lipi;

/**
 * 📜 Lipi Programming Language Token Specification
 *
 * WHY: Serves as the fundamental atomic unit of the Lipi compiler and interpreter.
 * Fully supports multi-byte UTF-8 Unicode metadata (Bengali script, conjuncts, and numerals)
 * alongside international ASCII tokens. Tracks 1-indexed line and column positions for
 * human-friendly syntax error reporting with visual source pointers.
 *
 * @author Shafiullah (Gyani Supreme Core)
 */
final class LipiToken
{
    // Literals & Identifiers
    public const TYPE_IDENTIFIER = 'IDENTIFIER';
    public const TYPE_NUMBER     = 'NUMBER';
    public const TYPE_STRING     = 'STRING';

    // Keywords (Bilingual: Bengali & English)
    public const TYPE_LET        = 'LET';        // ধরি / let / var
    public const TYPE_CONST      = 'CONST';      // ধ্রুবক / const
    public const TYPE_FN         = 'FN';         // কাজ / fn / def
    public const TYPE_IF         = 'IF';         // যদি / if
    public const TYPE_THEN       = 'THEN';       // তবে / then
    public const TYPE_ELSE       = 'ELSE';       // নাহলে / else
    public const TYPE_ELIF       = 'ELIF';       // নাহলে_যদি / elif
    public const TYPE_WHILE      = 'WHILE';      // যতক্ষণ / while
    public const TYPE_FOR        = 'FOR';        // প্রতিটি / for
    public const TYPE_IN         = 'IN';         // ভেতরে / in
    public const TYPE_RETURN     = 'RETURN';     // ফেরত / return
    public const TYPE_BREAK      = 'BREAK';      // থামো / break
    public const TYPE_CONTINUE   = 'CONTINUE';   // চালিয়ে_যাও / continue
    public const TYPE_SHOW       = 'SHOW';       // দেখাও / show / print
    public const TYPE_TRUE       = 'TRUE';       // সত্য / true
    public const TYPE_FALSE      = 'FALSE';      // মিথ্যা / false
    public const TYPE_NULL       = 'NULL';       // শূন্য / null / nil

    // Logical Keywords
    public const TYPE_AND        = 'AND';        // এবং / and / &&
    public const TYPE_OR         = 'OR';         // অথবা / or / ||
    public const TYPE_NOT        = 'NOT';        // না / not / !

    // Module & Import Keywords
    public const TYPE_IMPORT     = 'IMPORT';     // আমদানি / import
    public const TYPE_AS         = 'AS';         // হিসেবে / as

    // Object / Struct Keywords
    public const TYPE_STRUCT     = 'STRUCT';     // গঠন / struct / class
    public const TYPE_NEW        = 'NEW';        // নতুন / new

    // Exception Handling Keywords
    public const TYPE_TRY        = 'TRY';        // চেষ্টা / try
    public const TYPE_CATCH      = 'CATCH';      // ধরো / catch
    public const TYPE_THROW      = 'THROW';      // নিক্ষেপ / throw

    // Built-in Silicon Subsystems
    public const TYPE_SERVER     = 'SERVER';     // সার্ভার / server
    public const TYPE_UI         = 'UI';         // পর্দা / ui
    public const TYPE_MEMORY     = 'MEMORY';     // স্মৃতি / memory
    public const TYPE_COMPUTE    = 'COMPUTE';    // গণনা / compute

    // Operators
    public const TYPE_PLUS       = '+';
    public const TYPE_MINUS      = '-';
    public const TYPE_STAR       = '*';
    public const TYPE_SLASH      = '/';
    public const TYPE_PERCENT    = '%';
    public const TYPE_CARET      = '^';

    // Assignments
    public const TYPE_ASSIGN     = '=';
    public const TYPE_PLUS_EQ    = '+=';
    public const TYPE_MINUS_EQ   = '-=';
    public const TYPE_STAR_EQ    = '*=';
    public const TYPE_SLASH_EQ   = '/=';

    // Comparisons
    public const TYPE_EQ         = '==';
    public const TYPE_NOT_EQ     = '!=';
    public const TYPE_LT         = '<';
    public const TYPE_LT_EQ      = '<=';
    public const TYPE_GT         = '>';
    public const TYPE_GT_EQ      = '>=';

    // Delimiters & Punctuation
    public const TYPE_LPAREN     = '(';
    public const TYPE_RPAREN     = ')';
    public const TYPE_LBRACE     = '{';
    public const TYPE_RBRACE     = '}';
    public const TYPE_LBRACKET   = '[';
    public const TYPE_RBRACKET   = ']';
    public const TYPE_ARROW      = '->';
    public const TYPE_COMMA      = ',';
    public const TYPE_COLON      = ':';
    public const TYPE_DOT        = '.';
    public const TYPE_SEMICOLON  = ';';

    // Special
    public const TYPE_NEWLINE    = 'NEWLINE';
    public const TYPE_EOF        = 'EOF';

    public function __construct(
        public readonly string $type,
        public readonly string|int|float|bool|null $value,
        public readonly int $line,
        public readonly int $column,
        public readonly ?string $rawText = null
    ) {
    }

    public function is(string $type): bool
    {
        return $this->type === $type;
    }

    public function isOneOf(string ...$types): bool
    {
        return in_array($this->type, $types, true);
    }

    public function __toString(): string
    {
        $valStr = is_string($this->value) ? '"' . $this->value . '"' : var_export($this->value, true);
        return sprintf("Token(%s, %s, L%d:C%d)", $this->type, $valStr, $this->line, $this->column);
    }
}
