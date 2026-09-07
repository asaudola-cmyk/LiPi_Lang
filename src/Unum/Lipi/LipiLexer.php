<?php

declare(strict_types=1);

namespace Unum\Lipi;

require_once __DIR__ . '/LipiToken.php';

use RuntimeException;

/**
 * 📜 Lipi Multi-Byte UTF-8 Bilingual Lexer
 *
 * WHY: Traditional lexers rely on single-byte ASCII assumptions (ctype_alpha, is_numeric),
 * which corrupt multi-byte UTF-8 scripts like Bengali (U+0980 to U+09FF).
 * LipiLexer scans UTF-8 code points, recognizing Bengali consonants, vowels, vowel marks (কার),
 * virama/hasanta (্), and conjuncts (যুক্তবর্ণ), alongside Bengali numerals (০-৯).
 * Seamlessly treats English and Bengali keywords as first-class synonyms.
 *
 * @author Shafiullah (Gyani Supreme Core)
 */
final class LipiLexer
{
    private string $source;
    private int $length;
    private int $cursor = 0;
    private int $line = 1;
    private int $column = 1;

    /** @var list<LipiToken> */
    private array $tokens = [];

    /** Map Bengali digits to ASCII digits */
    private const BANGLA_DIGITS = [
        '০' => '0', '১' => '1', '২' => '2', '৩' => '3', '৪' => '4',
        '৫' => '5', '৬' => '6', '৭' => '7', '৮' => '8', '৯' => '9',
    ];

    /** Bilingual keyword map */
    private const KEYWORDS = [
        // Bengali Keywords
        'ধরি'         => LipiToken::TYPE_LET,
        'ধ্রুবক'       => LipiToken::TYPE_CONST,
        'কাজ'         => LipiToken::TYPE_FN,
        'যদি'         => LipiToken::TYPE_IF,
        'তবে'         => LipiToken::TYPE_THEN,
        'নাহলে'       => LipiToken::TYPE_ELSE,
        'নাহলে_যদি'   => LipiToken::TYPE_ELIF,
        'যতক্ষণ'       => LipiToken::TYPE_WHILE,
        'প্রতিটি'     => LipiToken::TYPE_FOR,
        'ভেতরে'       => LipiToken::TYPE_IN,
        'ফেরত'        => LipiToken::TYPE_RETURN,
        'থামো'        => LipiToken::TYPE_BREAK,
        'চালিয়ে_যাও'  => LipiToken::TYPE_CONTINUE,
        'দেখাও'       => LipiToken::TYPE_SHOW,
        'সত্য'        => LipiToken::TYPE_TRUE,
        'মিথ্যা'      => LipiToken::TYPE_FALSE,
        'শূন্য'       => LipiToken::TYPE_NULL,
        'এবং'         => LipiToken::TYPE_AND,
        'অথবা'        => LipiToken::TYPE_OR,
        'না'          => LipiToken::TYPE_NOT,
        'সার্ভার'     => LipiToken::TYPE_SERVER,
        'পর্দা'        => LipiToken::TYPE_UI,
        'স্মৃতি'       => LipiToken::TYPE_MEMORY,
        'গণনা'        => LipiToken::TYPE_COMPUTE,

        // English Keywords (Full Equivalence)
        'let'         => LipiToken::TYPE_LET,
        'var'         => LipiToken::TYPE_LET,
        'const'       => LipiToken::TYPE_CONST,
        'fn'          => LipiToken::TYPE_FN,
        'def'         => LipiToken::TYPE_FN,
        'func'        => LipiToken::TYPE_FN,
        'function'    => LipiToken::TYPE_FN,
        'if'          => LipiToken::TYPE_IF,
        'then'        => LipiToken::TYPE_THEN,
        'else'        => LipiToken::TYPE_ELSE,
        'elif'        => LipiToken::TYPE_ELIF,
        'elseif'      => LipiToken::TYPE_ELIF,
        'while'       => LipiToken::TYPE_WHILE,
        'for'         => LipiToken::TYPE_FOR,
        'in'          => LipiToken::TYPE_IN,
        'return'      => LipiToken::TYPE_RETURN,
        'break'       => LipiToken::TYPE_BREAK,
        'continue'    => LipiToken::TYPE_CONTINUE,
        'show'        => LipiToken::TYPE_SHOW,
        'print'       => LipiToken::TYPE_SHOW,
        'echo'        => LipiToken::TYPE_SHOW,
        'true'        => LipiToken::TYPE_TRUE,
        'false'       => LipiToken::TYPE_FALSE,
        'null'        => LipiToken::TYPE_NULL,
        'nil'         => LipiToken::TYPE_NULL,
        'and'         => LipiToken::TYPE_AND,
        'or'          => LipiToken::TYPE_OR,
        'not'         => LipiToken::TYPE_NOT,
        'server'      => LipiToken::TYPE_SERVER,
        'ui'          => LipiToken::TYPE_UI,
        'memory'      => LipiToken::TYPE_MEMORY,
        'compute'     => LipiToken::TYPE_COMPUTE,
    ];

    public function __construct(string $source)
    {
        // Normalize newlines to \n
        $this->source = str_replace(["\r\n", "\r"], "\n", $source);
        $this->length = mb_strlen($this->source, 'UTF-8');
    }

    /**
     * Scans the entire source into a list of LipiTokens.
     *
     * @return list<LipiToken>
     */
    public function tokenize(): array
    {
        $this->tokens = [];
        $this->cursor = 0;
        $this->line = 1;
        $this->column = 1;

        while (!$this->isAtEnd()) {
            $char = $this->peek();

            // 1. Whitespace (Horizontal)
            if ($char === ' ' || $char === "\t") {
                $this->advance();
                continue;
            }

            // 2. Newlines (Line-delimited grammar)
            if ($char === "\n") {
                $startLine = $this->line;
                $startCol = $this->column;
                $this->advance();

                // Collapse multiple newlines into a single NEWLINE token
                while (!$this->isAtEnd() && $this->peek() === "\n") {
                    $this->advance();
                }

                // Only emit NEWLINE if previous token was an expression/statement ender
                if (!empty($this->tokens)) {
                    $lastType = end($this->tokens)->type;
                    if (!in_array($lastType, [
                        LipiToken::TYPE_NEWLINE,
                        LipiToken::TYPE_PLUS,
                        LipiToken::TYPE_MINUS,
                        LipiToken::TYPE_STAR,
                        LipiToken::TYPE_SLASH,
                        LipiToken::TYPE_PERCENT,
                        LipiToken::TYPE_ASSIGN,
                        LipiToken::TYPE_ARROW,
                        LipiToken::TYPE_COMMA,
                        LipiToken::TYPE_COLON,
                        LipiToken::TYPE_LPAREN,
                        LipiToken::TYPE_LBRACE,
                        LipiToken::TYPE_LBRACKET,
                    ], true)) {
                        $this->tokens[] = new LipiToken(LipiToken::TYPE_NEWLINE, "\n", $startLine, $startCol);
                    }
                }
                continue;
            }

            // 3. Comments (// or # for single-line, /* */ for multi-line)
            if ($char === '#' || ($char === '/' && $this->peekNext() === '/')) {
                $this->skipLineComment();
                continue;
            }
            if ($char === '/' && $this->peekNext() === '*') {
                $this->skipBlockComment();
                continue;
            }

            // 4. String Literals ("..." or '...')
            if ($char === '"' || $char === "'") {
                $this->scanString($char);
                continue;
            }

            // 5. Number Literals (ASCII 0-9 or Bengali ০-৯)
            if ($this->isDigit($char)) {
                $this->scanNumber();
                continue;
            }

            // 6. Identifiers & Keywords (ASCII or Bengali script)
            if ($this->isIdentifierStart($char)) {
                $this->scanIdentifier();
                continue;
            }

            // 7. Operators & Punctuation
            $this->scanOperatorOrPunctuation();
        }

        // Add EOF
        $this->tokens[] = new LipiToken(LipiToken::TYPE_EOF, null, $this->line, $this->column);

        return $this->tokens;
    }

    private function scanString(string $quote): void
    {
        $startLine = $this->line;
        $startCol = $this->column;
        $this->advance(); // consume opening quote
        $str = '';

        while (!$this->isAtEnd() && $this->peek() !== $quote) {
            $c = $this->peek();
            if ($c === "\n") {
                // Multi-line strings allowed
                $this->advance();
                $str .= "\n";
                continue;
            }
            if ($c === '\\') {
                $this->advance();
                $escaped = $this->peek();
                $str .= match ($escaped) {
                    'n'  => "\n",
                    't'  => "\t",
                    'r'  => "\r",
                    '"'  => '"',
                    "'"  => "'",
                    '\\' => '\\',
                    default => $escaped,
                };
                $this->advance();
                continue;
            }
            $str .= $c;
            $this->advance();
        }

        if ($this->isAtEnd()) {
            throw new RuntimeException("Unterminated string literal at line {$startLine}, column {$startCol}");
        }

        $this->advance(); // consume closing quote
        $this->tokens[] = new LipiToken(LipiToken::TYPE_STRING, $str, $startLine, $startCol);
    }

    private function scanNumber(): void
    {
        $startLine = $this->line;
        $startCol = $this->column;
        $numStr = '';
        $isFloat = false;

        while (!$this->isAtEnd() && $this->isDigit($this->peek())) {
            $numStr .= $this->normalizeDigit($this->advance());
        }

        // Check for decimal point (either . or Bengali ।) followed by digit
        if (!$this->isAtEnd() && ($this->peek() === '.' || $this->peek() === '।')) {
            if ($this->isDigit($this->peekNext())) {
                $isFloat = true;
                $this->advance(); // consume decimal point
                $numStr .= '.';
                while (!$this->isAtEnd() && $this->isDigit($this->peek())) {
                    $numStr .= $this->normalizeDigit($this->advance());
                }
            }
        }

        $value = $isFloat ? (float)$numStr : (int)$numStr;
        $this->tokens[] = new LipiToken(LipiToken::TYPE_NUMBER, $value, $startLine, $startCol);
    }

    private function scanIdentifier(): void
    {
        $startLine = $this->line;
        $startCol = $this->column;
        $ident = '';

        while (!$this->isAtEnd() && $this->isIdentifierPart($this->peek())) {
            $ident .= $this->advance();
        }

        // Check if identifier matches a bilingual keyword
        $lower = mb_strtolower($ident, 'UTF-8');
        $type = self::KEYWORDS[$lower] ?? self::KEYWORDS[$ident] ?? LipiToken::TYPE_IDENTIFIER;

        $value = match ($type) {
            LipiToken::TYPE_TRUE  => true,
            LipiToken::TYPE_FALSE => false,
            LipiToken::TYPE_NULL  => null,
            default               => $ident,
        };

        $this->tokens[] = new LipiToken($type, $value, $startLine, $startCol, $ident);
    }

    private function scanOperatorOrPunctuation(): void
    {
        $startLine = $this->line;
        $startCol = $this->column;
        $c = $this->advance();

        switch ($c) {
            case '+':
                if ($this->match('=')) {
                    $this->tokens[] = new LipiToken(LipiToken::TYPE_PLUS_EQ, '+=', $startLine, $startCol);
                } else {
                    $this->tokens[] = new LipiToken(LipiToken::TYPE_PLUS, '+', $startLine, $startCol);
                }
                break;
            case '-':
                if ($this->match('>')) {
                    $this->tokens[] = new LipiToken(LipiToken::TYPE_ARROW, '->', $startLine, $startCol);
                } elseif ($this->match('=')) {
                    $this->tokens[] = new LipiToken(LipiToken::TYPE_MINUS_EQ, '-=', $startLine, $startCol);
                } else {
                    $this->tokens[] = new LipiToken(LipiToken::TYPE_MINUS, '-', $startLine, $startCol);
                }
                break;
            case '*':
                if ($this->match('=')) {
                    $this->tokens[] = new LipiToken(LipiToken::TYPE_STAR_EQ, '*=', $startLine, $startCol);
                } else {
                    $this->tokens[] = new LipiToken(LipiToken::TYPE_STAR, '*', $startLine, $startCol);
                }
                break;
            case '/':
                if ($this->match('=')) {
                    $this->tokens[] = new LipiToken(LipiToken::TYPE_SLASH_EQ, '/=', $startLine, $startCol);
                } else {
                    $this->tokens[] = new LipiToken(LipiToken::TYPE_SLASH, '/', $startLine, $startCol);
                }
                break;
            case '%':
                $this->tokens[] = new LipiToken(LipiToken::TYPE_PERCENT, '%', $startLine, $startCol);
                break;
            case '^':
                $this->tokens[] = new LipiToken(LipiToken::TYPE_CARET, '^', $startLine, $startCol);
                break;
            case '=':
                if ($this->match('=')) {
                    $this->tokens[] = new LipiToken(LipiToken::TYPE_EQ, '==', $startLine, $startCol);
                } else {
                    $this->tokens[] = new LipiToken(LipiToken::TYPE_ASSIGN, '=', $startLine, $startCol);
                }
                break;
            case '!':
                if ($this->match('=')) {
                    $this->tokens[] = new LipiToken(LipiToken::TYPE_NOT_EQ, '!=', $startLine, $startCol);
                } else {
                    $this->tokens[] = new LipiToken(LipiToken::TYPE_NOT, '!', $startLine, $startCol);
                }
                break;
            case '<':
                if ($this->match('=')) {
                    $this->tokens[] = new LipiToken(LipiToken::TYPE_LT_EQ, '<=', $startLine, $startCol);
                } else {
                    $this->tokens[] = new LipiToken(LipiToken::TYPE_LT, '<', $startLine, $startCol);
                }
                break;
            case '>':
                if ($this->match('=')) {
                    $this->tokens[] = new LipiToken(LipiToken::TYPE_GT_EQ, '>=', $startLine, $startCol);
                } else {
                    $this->tokens[] = new LipiToken(LipiToken::TYPE_GT, '>', $startLine, $startCol);
                }
                break;
            case '&':
                if ($this->match('&')) {
                    $this->tokens[] = new LipiToken(LipiToken::TYPE_AND, '&&', $startLine, $startCol);
                } else {
                    throw new RuntimeException("Unexpected single '&' at line {$startLine}, column {$startCol}. Did you mean '&&' or 'এবং'?");
                }
                break;
            case '|':
                if ($this->match('|')) {
                    $this->tokens[] = new LipiToken(LipiToken::TYPE_OR, '||', $startLine, $startCol);
                } else {
                    throw new RuntimeException("Unexpected single '|' at line {$startLine}, column {$startCol}. Did you mean '||' or 'অথবা'?");
                }
                break;
            case '(':
                $this->tokens[] = new LipiToken(LipiToken::TYPE_LPAREN, '(', $startLine, $startCol);
                break;
            case ')':
                $this->tokens[] = new LipiToken(LipiToken::TYPE_RPAREN, ')', $startLine, $startCol);
                break;
            case '{':
                $this->tokens[] = new LipiToken(LipiToken::TYPE_LBRACE, '{', $startLine, $startCol);
                break;
            case '}':
                $this->tokens[] = new LipiToken(LipiToken::TYPE_RBRACE, '}', $startLine, $startCol);
                break;
            case '[':
                $this->tokens[] = new LipiToken(LipiToken::TYPE_LBRACKET, '[', $startLine, $startCol);
                break;
            case ']':
                $this->tokens[] = new LipiToken(LipiToken::TYPE_RBRACKET, ']', $startLine, $startCol);
                break;
            case ',':
                $this->tokens[] = new LipiToken(LipiToken::TYPE_COMMA, ',', $startLine, $startCol);
                break;
            case ':':
                $this->tokens[] = new LipiToken(LipiToken::TYPE_COLON, ':', $startLine, $startCol);
                break;
            case '.':
                $this->tokens[] = new LipiToken(LipiToken::TYPE_DOT, '.', $startLine, $startCol);
                break;
            case ';':
                $this->tokens[] = new LipiToken(LipiToken::TYPE_SEMICOLON, ';', $startLine, $startCol);
                break;
            default:
                throw new RuntimeException(sprintf(
                    "Unexpected character '%s' (Unicode U+%04X) at line %d, column %d",
                    $c,
                    mb_ord($c, 'UTF-8'),
                    $startLine,
                    $startCol
                ));
        }
    }

    private function isDigit(string $char): bool
    {
        if ($char >= '0' && $char <= '9') {
            return true;
        }
        return isset(self::BANGLA_DIGITS[$char]);
    }

    private function normalizeDigit(string $char): string
    {
        return self::BANGLA_DIGITS[$char] ?? $char;
    }

    /**
     * Checks if char can start an identifier:
     * - ASCII letters a-z, A-Z, or _
     * - Bengali consonants, independent vowels (U+0985 to U+09B9, U+09CE, U+09DC-U+09DF)
     */
    private function isIdentifierStart(string $char): bool
    {
        if (($char >= 'a' && $char <= 'z') || ($char >= 'A' && $char <= 'Z') || $char === '_') {
            return true;
        }
        $ord = mb_ord($char, 'UTF-8');
        // Bengali vowel and consonant range
        return ($ord >= 0x0985 && $ord <= 0x09B9) || ($ord >= 0x09DC && $ord <= 0x09DF) || $ord === 0x09CE;
    }

    /**
     * Checks if char can continue an identifier:
     * Includes all letters, digits, kar (vowel signs 0x09BE-0x09CC), virama/hasanta (0x09CD),
     * nukta (0x09BC), anusvara/visarga/chandrabindu (0x0981-0x0983).
     */
    private function isIdentifierPart(string $char): bool
    {
        if ($this->isIdentifierStart($char) || $this->isDigit($char)) {
            return true;
        }
        $ord = mb_ord($char, 'UTF-8');
        // Bengali combining characters, vowel signs (কার), hasanta, nukta, signs
        return ($ord >= 0x0981 && $ord <= 0x0983)
            || ($ord >= 0x09BC && $ord <= 0x09CD)
            || ($ord >= 0x09D7 && $ord <= 0x09E3);
    }

    private function skipLineComment(): void
    {
        while (!$this->isAtEnd() && $this->peek() !== "\n") {
            $this->advance();
        }
    }

    private function skipBlockComment(): void
    {
        $this->advance(); // /
        $this->advance(); // *
        while (!$this->isAtEnd()) {
            if ($this->peek() === '*' && $this->peekNext() === '/') {
                $this->advance();
                $this->advance();
                return;
            }
            $this->advance();
        }
        throw new RuntimeException("Unterminated block comment at line {$this->line}");
    }

    private function advance(): string
    {
        if ($this->isAtEnd()) {
            return '';
        }
        $char = mb_substr($this->source, $this->cursor, 1, 'UTF-8');
        $this->cursor++;
        if ($char === "\n") {
            $this->line++;
            $this->column = 1;
        } else {
            $this->column++;
        }
        return $char;
    }

    private function match(string $expected): bool
    {
        if ($this->isAtEnd() || $this->peek() !== $expected) {
            return false;
        }
        $this->advance();
        return true;
    }

    private function peek(): string
    {
        if ($this->isAtEnd()) {
            return '';
        }
        return mb_substr($this->source, $this->cursor, 1, 'UTF-8');
    }

    private function peekNext(): string
    {
        if ($this->cursor + 1 >= $this->length) {
            return '';
        }
        return mb_substr($this->source, $this->cursor + 1, 1, 'UTF-8');
    }

    private function isAtEnd(): bool
    {
        return $this->cursor >= $this->length;
    }
}
