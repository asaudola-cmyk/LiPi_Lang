<?php

declare(strict_types=1);

namespace Unum\Lipi;

require_once __DIR__ . '/LipiToken.php';
require_once __DIR__ . '/LipiAst.php';

use RuntimeException;

/**
 * 📜 Lipi Pratt Operator-Precedence Syntax Parser
 *
 * WHY: Traditional recursive-descent parsers struggle with mathematical operator precedence
 * and binary expressions without creating dozens of recursive stack frames.
 * LipiParser implements Vaughan Pratt's top-down operator precedence technique, parsing
 * complex expressions in linear time O(N) while naturally supporting bilingual keywords
 * and line-oriented statement termination without mandatory semicolons.
 *
 * @author Shafiullah (Gyani Supreme Core)
 */
final class LipiParser
{
    /** @var list<LipiToken> */
    private array $tokens;
    private int $pos = 0;
    private int $count;

    // Precedence levels
    private const PREC_NONE       = 0;
    private const PREC_ASSIGNMENT = 1; // = += -= *= /=
    private const PREC_OR         = 2; // অথবা or ||
    private const PREC_AND        = 3; // এবং and &&
    private const PREC_EQUALITY   = 4; // == !=
    private const PREC_COMPARISON = 5; // < <= > >=
    private const PREC_TERM       = 6; // + -
    private const PREC_FACTOR     = 7; // * / %
    private const PREC_EXPONENT   = 8; // ^
    private const PREC_UNARY      = 9; // ! - not না
    private const PREC_CALL       = 10; // () [] .

    /**
     * @param list<LipiToken> $tokens
     */
    public function __construct(array $tokens)
    {
        $this->tokens = $tokens;
        $this->count = count($tokens);
    }

    /**
     * Parses the token stream into a Program AST node.
     */
    public function parse(): ProgramNode
    {
        $statements = [];
        $this->skipNewlines();

        while (!$this->isAtEnd()) {
            $stmt = $this->parseStatement();
            if ($stmt !== null) {
                $statements[] = $stmt;
            }
            $this->skipNewlinesAndSemicolons();
        }

        return new ProgramNode($statements);
    }

    private function parseStatement(): ?LipiStmt
    {
        $this->skipNewlines();
        if ($this->isAtEnd()) {
            return null;
        }

        // Variable declaration: ধরি x = 10 or let x = 10
        if ($this->match(LipiToken::TYPE_LET)) {
            return $this->parseVarDecl(isConst: false);
        }
        if ($this->match(LipiToken::TYPE_CONST)) {
            return $this->parseVarDecl(isConst: true);
        }

        // Function declaration: কাজ যোগ(ক, খ) { ... } or fn add(a, b) { ... }
        if ($this->match(LipiToken::TYPE_FN)) {
            return $this->parseFnDecl();
        }

        // If statement: যদি শর্ত { ... }
        if ($this->match(LipiToken::TYPE_IF)) {
            return $this->parseIfStmt();
        }

        // While loop: যতক্ষণ শর্ত { ... }
        if ($this->match(LipiToken::TYPE_WHILE)) {
            return $this->parseWhileStmt();
        }

        // For loop: প্রতিটি উপাদান ভেতরে তালিকা { ... }
        if ($this->match(LipiToken::TYPE_FOR)) {
            return $this->parseForStmt();
        }

        // Return statement: ফেরত মান
        if ($this->match(LipiToken::TYPE_RETURN)) {
            return $this->parseReturnStmt();
        }

        // Loop controls: থামো / চালিয়ে_যাও
        if ($this->match(LipiToken::TYPE_BREAK)) {
            $prev = $this->previous();
            return new BreakStmt($prev->line, $prev->column);
        }
        if ($this->match(LipiToken::TYPE_CONTINUE)) {
            $prev = $this->previous();
            return new ContinueStmt($prev->line, $prev->column);
        }

        // Show/print: দেখাও "হ্যালো"
        if ($this->match(LipiToken::TYPE_SHOW)) {
            return $this->parseShowStmt();
        }

        // Block statement: { ... }
        if ($this->check(LipiToken::TYPE_LBRACE)) {
            return $this->parseBlock();
        }

        // Built-in server statement: সার্ভার.চালু(পোর্ট: ৮০৮০) { ... }
        if ($this->check(LipiToken::TYPE_SERVER) && $this->peekNextToken()->type === LipiToken::TYPE_DOT) {
            return $this->parseServerStmt();
        }

        // Expression statement
        return $this->parseExpressionStatement();
    }

    private function parseVarDecl(bool $isConst): VarDeclStmt
    {
        $keyword = $this->previous();
        $nameToken = $this->consume(LipiToken::TYPE_IDENTIFIER, "Expected variable name after '" . $keyword->rawText . "'");
        $name = (string)$nameToken->value;

        $initializer = null;
        if ($this->match(LipiToken::TYPE_ASSIGN)) {
            $initializer = $this->parseExpression();
        }

        return new VarDeclStmt($name, $initializer, $isConst, $keyword->line, $keyword->column);
    }

    private function parseFnDecl(): FnDeclStmt
    {
        $keyword = $this->previous();
        $nameToken = $this->consume(LipiToken::TYPE_IDENTIFIER, "Expected function name after '" . $keyword->rawText . "'");
        $name = (string)$nameToken->value;

        $params = [];
        if ($this->match(LipiToken::TYPE_LPAREN)) {
            if (!$this->check(LipiToken::TYPE_RPAREN)) {
                do {
                    $this->skipNewlines();
                    $pTok = $this->consume(LipiToken::TYPE_IDENTIFIER, "Expected parameter name in function declaration");
                    $params[] = (string)$pTok->value;
                    $this->skipNewlines();
                } while ($this->match(LipiToken::TYPE_COMMA));
            }
            $this->consume(LipiToken::TYPE_RPAREN, "Expected ')' after parameters");
        }

        $this->skipNewlines();
        $body = $this->parseBlock();

        return new FnDeclStmt($name, $params, $body, $keyword->line, $keyword->column);
    }

    private function parseIfStmt(): IfStmt
    {
        $keyword = $this->previous();
        $condition = $this->parseExpression();

        // Optional 'তবে' or 'then'
        $this->match(LipiToken::TYPE_THEN);
        $this->skipNewlines();

        $thenBranch = $this->parseBlock();
        $elifBranches = [];
        $elseBranch = null;

        while ($this->match(LipiToken::TYPE_ELIF)) {
            $elifCond = $this->parseExpression();
            $this->match(LipiToken::TYPE_THEN);
            $this->skipNewlines();
            $elifBranch = $this->parseBlock();
            $elifBranches[] = ['condition' => $elifCond, 'branch' => $elifBranch];
        }

        if ($this->match(LipiToken::TYPE_ELSE)) {
            $this->skipNewlines();
            $elseBranch = $this->parseBlock();
        }

        return new IfStmt($condition, $thenBranch, $elifBranches, $elseBranch, $keyword->line, $keyword->column);
    }

    private function parseWhileStmt(): WhileStmt
    {
        $keyword = $this->previous();
        $condition = $this->parseExpression();
        $this->skipNewlines();
        $body = $this->parseBlock();

        return new WhileStmt($condition, $body, $keyword->line, $keyword->column);
    }

    private function parseForStmt(): ForStmt
    {
        $keyword = $this->previous();
        $varTok = $this->consume(LipiToken::TYPE_IDENTIFIER, "Expected variable name in for loop");
        $varName = (string)$varTok->value;

        $this->consume(LipiToken::TYPE_IN, "Expected 'in' or 'ভেতরে' after loop variable");
        $iterable = $this->parseExpression();
        $this->skipNewlines();
        $body = $this->parseBlock();

        return new ForStmt($varName, $iterable, $body, $keyword->line, $keyword->column);
    }

    private function parseReturnStmt(): ReturnStmt
    {
        $keyword = $this->previous();
        $value = null;

        if (!$this->check(LipiToken::TYPE_NEWLINE) && !$this->check(LipiToken::TYPE_SEMICOLON) && !$this->check(LipiToken::TYPE_EOF) && !$this->check(LipiToken::TYPE_RBRACE)) {
            $value = $this->parseExpression();
        }

        return new ReturnStmt($value, $keyword->line, $keyword->column);
    }

    private function parseShowStmt(): ShowStmt
    {
        $keyword = $this->previous();
        $expressions = [];

        do {
            $expressions[] = $this->parseExpression();
        } while ($this->match(LipiToken::TYPE_COMMA));

        return new ShowStmt($expressions, $keyword->line, $keyword->column);
    }

    private function parseBlock(): BlockStmt
    {
        $startTok = $this->consume(LipiToken::TYPE_LBRACE, "Expected '{' to begin block");
        $statements = [];
        $this->skipNewlinesAndSemicolons();

        while (!$this->check(LipiToken::TYPE_RBRACE) && !$this->isAtEnd()) {
            $stmt = $this->parseStatement();
            if ($stmt !== null) {
                $statements[] = $stmt;
            }
            $this->skipNewlinesAndSemicolons();
        }

        $this->consume(LipiToken::TYPE_RBRACE, "Expected '}' to close block");
        return new BlockStmt($statements, $startTok->line, $startTok->column);
    }

    private function parseServerStmt(): ServerStmt
    {
        $serverTok = $this->advance(); // SERVER
        $this->advance(); // .
        $actionTok = $this->consume(LipiToken::TYPE_IDENTIFIER, "Expected server action (e.g. চালু / listen)");

        $this->consume(LipiToken::TYPE_LPAREN, "Expected '(' after server action");
        // Optional 'পোর্ট:' label
        if ($this->check(LipiToken::TYPE_IDENTIFIER) && $this->peekNextToken()->type === LipiToken::TYPE_COLON) {
            $this->advance(); // label
            $this->advance(); // :
        }
        $portExpr = $this->parseExpression();
        $this->consume(LipiToken::TYPE_RPAREN, "Expected ')' after server port");

        $this->skipNewlines();
        // Handler closure
        $this->consume(LipiToken::TYPE_LBRACE, "Expected '{' for server handler");
        $params = [];
        // Optional req, res ->
        if ($this->check(LipiToken::TYPE_IDENTIFIER)) {
            $params[] = (string)$this->advance()->value;
            if ($this->match(LipiToken::TYPE_COMMA)) {
                $params[] = (string)$this->consume(LipiToken::TYPE_IDENTIFIER, "Expected response parameter")->value;
            }
            $this->consume(LipiToken::TYPE_ARROW, "Expected '->' after handler parameters");
        }

        $statements = [];
        $this->skipNewlinesAndSemicolons();
        while (!$this->check(LipiToken::TYPE_RBRACE) && !$this->isAtEnd()) {
            $stmt = $this->parseStatement();
            if ($stmt !== null) {
                $statements[] = $stmt;
            }
            $this->skipNewlinesAndSemicolons();
        }
        $this->consume(LipiToken::TYPE_RBRACE, "Expected '}' to close server handler");

        $handler = new FnExpr($params, new BlockStmt($statements, $serverTok->line, $serverTok->column), $serverTok->line, $serverTok->column);
        return new ServerStmt($portExpr, $handler, $serverTok->line, $serverTok->column);
    }

    private function parseExpressionStatement(): ExprStmt
    {
        $expr = $this->parseExpression();
        return new ExprStmt($expr, $expr->line, $expr->column);
    }

    // =========================================================================
    // PRATT EXPRESSION PARSING
    // =========================================================================

    public function parseExpression(int $precedence = self::PREC_NONE): LipiExpr
    {
        $this->skipNewlines();
        $token = $this->advance();

        // 1. Prefix parser
        $left = $this->parsePrefix($token);

        // 2. Infix parser loop based on operator precedence
        while (!$this->isAtEnd() && $precedence < $this->getInfixPrecedence($this->peek()->type)) {
            $opToken = $this->advance();
            $left = $this->parseInfix($left, $opToken);
        }

        return $left;
    }

    private function parsePrefix(LipiToken $token): LipiExpr
    {
        return match ($token->type) {
            LipiToken::TYPE_NUMBER,
            LipiToken::TYPE_STRING,
            LipiToken::TYPE_TRUE,
            LipiToken::TYPE_FALSE,
            LipiToken::TYPE_NULL
                => new LiteralExpr($token->value, $token->line, $token->column),

            LipiToken::TYPE_IDENTIFIER,
            LipiToken::TYPE_MEMORY,
            LipiToken::TYPE_UI,
            LipiToken::TYPE_SERVER
                => new VariableExpr((string)($token->rawText ?: $token->value), $token->line, $token->column),

            LipiToken::TYPE_MINUS,
            LipiToken::TYPE_NOT
                => new UnaryExpr($token->type, $this->parseExpression(self::PREC_UNARY), $token->line, $token->column),

            LipiToken::TYPE_LPAREN => $this->parseGroupingOrLambda($token),

            LipiToken::TYPE_LBRACKET => $this->parseArrayLiteral($token),

            LipiToken::TYPE_LBRACE => $this->parseMapLiteral($token),

            LipiToken::TYPE_FN => $this->parseAnonymousFn($token),

            default => throw new RuntimeException(sprintf(
                "Unexpected expression token '%s' (type: %s) at line %d, column %d",
                (string)$token->value,
                $token->type,
                $token->line,
                $token->column
            )),
        };
    }

    private function parseInfix(LipiExpr $left, LipiToken $opToken): LipiExpr
    {
        $type = $opToken->type;

        // Assignments: =, +=, -=, *=, /=
        if (in_array($type, [
            LipiToken::TYPE_ASSIGN,
            LipiToken::TYPE_PLUS_EQ,
            LipiToken::TYPE_MINUS_EQ,
            LipiToken::TYPE_STAR_EQ,
            LipiToken::TYPE_SLASH_EQ,
        ], true)) {
            $right = $this->parseExpression(self::PREC_ASSIGNMENT - 1); // right-associative
            return new AssignExpr($left, $type, $right, $opToken->line, $opToken->column);
        }

        // Function call: callee(...)
        if ($type === LipiToken::TYPE_LPAREN) {
            return $this->parseCallArguments($left, $opToken);
        }

        // Index access: obj[...]
        if ($type === LipiToken::TYPE_LBRACKET) {
            $index = $this->parseExpression();
            $this->consume(LipiToken::TYPE_RBRACKET, "Expected ']' after array index");
            return new IndexExpr($left, $index, $opToken->line, $opToken->column);
        }

        // Property access: obj.prop (supports identifiers, built-in subsystem keywords, and literals)
        if ($type === LipiToken::TYPE_DOT) {
            $this->skipNewlines();
            $tok = $this->peek();
            if ($tok->type === LipiToken::TYPE_IDENTIFIER
                || $tok->type === LipiToken::TYPE_MEMORY
                || $tok->type === LipiToken::TYPE_UI
                || $tok->type === LipiToken::TYPE_SERVER
                || $tok->type === LipiToken::TYPE_COMPUTE
                || $tok->type === LipiToken::TYPE_SHOW
                || $tok->type === LipiToken::TYPE_NUMBER
            ) {
                $propTok = $this->advance();
                $propName = (string)($propTok->rawText ?: $propTok->value);
            } else {
                $propTok = $this->consume(LipiToken::TYPE_IDENTIFIER, "Expected property name after '.'");
                $propName = (string)$propTok->value;
            }
            return new MemberExpr($left, $propName, $opToken->line, $opToken->column);
        }

        // Standard binary operations
        $precedence = $this->getInfixPrecedence($type);
        // Exponentiation (^) is right-associative
        $right = $this->parseExpression($type === LipiToken::TYPE_CARET ? $precedence - 1 : $precedence);

        return new BinaryExpr($left, $type, $right, $opToken->line, $opToken->column);
    }

    private function parseGroupingOrLambda(LipiToken $lparen): LipiExpr
    {
        $this->skipNewlines();
        if ($this->match(LipiToken::TYPE_RPAREN)) {
            // Empty parens () -> lambda check
            if ($this->match(LipiToken::TYPE_ARROW)) {
                $body = $this->parseBlock();
                return new FnExpr([], $body, $lparen->line, $lparen->column);
            }
            return new LiteralExpr(null, $lparen->line, $lparen->column);
        }

        $expr = $this->parseExpression();
        $this->skipNewlines();
        $this->consume(LipiToken::TYPE_RPAREN, "Expected ')' after expression");
        return $expr;
    }

    private function parseCallArguments(LipiExpr $callee, LipiToken $lparen): CallExpr
    {
        $args = [];
        $this->skipNewlines();

        if (!$this->check(LipiToken::TYPE_RPAREN)) {
            do {
                $this->skipNewlines();
                // Optional keyword argument label: (পোর্ট: ৮০৮০)
                if ($this->check(LipiToken::TYPE_IDENTIFIER) && $this->peekNextToken()->type === LipiToken::TYPE_COLON) {
                    $this->advance(); // label
                    $this->advance(); // :
                }
                $args[] = $this->parseExpression();
                $this->skipNewlines();
            } while ($this->match(LipiToken::TYPE_COMMA));
        }

        $this->consume(LipiToken::TYPE_RPAREN, "Expected ')' after function arguments");
        return new CallExpr($callee, $args, $lparen->line, $lparen->column);
    }

    private function parseArrayLiteral(LipiToken $lbracket): ArrayExpr
    {
        $elements = [];
        $this->skipNewlines();

        if (!$this->check(LipiToken::TYPE_RBRACKET)) {
            do {
                $this->skipNewlines();
                $elements[] = $this->parseExpression();
                $this->skipNewlines();
            } while ($this->match(LipiToken::TYPE_COMMA));
        }

        $this->consume(LipiToken::TYPE_RBRACKET, "Expected ']' after array elements");
        return new ArrayExpr($elements, $lbracket->line, $lbracket->column);
    }

    private function parseMapLiteral(LipiToken $lbrace): MapExpr
    {
        $entries = [];
        $this->skipNewlines();

        if (!$this->check(LipiToken::TYPE_RBRACE)) {
            do {
                $this->skipNewlines();
                // Key can be string, number, or identifier
                if ($this->check(LipiToken::TYPE_IDENTIFIER)) {
                    $idTok = $this->advance();
                    $key = new LiteralExpr((string)$idTok->value, $idTok->line, $idTok->column);
                } else {
                    $key = $this->parseExpression();
                }

                $this->consume(LipiToken::TYPE_COLON, "Expected ':' after map key");
                $val = $this->parseExpression();
                $entries[] = ['key' => $key, 'value' => $val];
                $this->skipNewlines();
            } while ($this->match(LipiToken::TYPE_COMMA));
        }

        $this->consume(LipiToken::TYPE_RBRACE, "Expected '}' after map entries");
        return new MapExpr($entries, $lbrace->line, $lbrace->column);
    }

    private function parseAnonymousFn(LipiToken $fnTok): FnExpr
    {
        $params = [];
        if ($this->match(LipiToken::TYPE_LPAREN)) {
            if (!$this->check(LipiToken::TYPE_RPAREN)) {
                do {
                    $this->skipNewlines();
                    $params[] = (string)$this->consume(LipiToken::TYPE_IDENTIFIER, "Expected parameter name")->value;
                    $this->skipNewlines();
                } while ($this->match(LipiToken::TYPE_COMMA));
            }
            $this->consume(LipiToken::TYPE_RPAREN, "Expected ')' after parameters");
        }

        $this->skipNewlines();
        $body = $this->parseBlock();
        return new FnExpr($params, $body, $fnTok->line, $fnTok->column);
    }

    private function getInfixPrecedence(string $type): int
    {
        return match ($type) {
            LipiToken::TYPE_ASSIGN,
            LipiToken::TYPE_PLUS_EQ,
            LipiToken::TYPE_MINUS_EQ,
            LipiToken::TYPE_STAR_EQ,
            LipiToken::TYPE_SLASH_EQ
                => self::PREC_ASSIGNMENT,

            LipiToken::TYPE_OR  => self::PREC_OR,
            LipiToken::TYPE_AND => self::PREC_AND,

            LipiToken::TYPE_EQ,
            LipiToken::TYPE_NOT_EQ
                => self::PREC_EQUALITY,

            LipiToken::TYPE_LT,
            LipiToken::TYPE_LT_EQ,
            LipiToken::TYPE_GT,
            LipiToken::TYPE_GT_EQ
                => self::PREC_COMPARISON,

            LipiToken::TYPE_PLUS,
            LipiToken::TYPE_MINUS
                => self::PREC_TERM,

            LipiToken::TYPE_STAR,
            LipiToken::TYPE_SLASH,
            LipiToken::TYPE_PERCENT
                => self::PREC_FACTOR,

            LipiToken::TYPE_CARET => self::PREC_EXPONENT,

            LipiToken::TYPE_LPAREN,
            LipiToken::TYPE_LBRACKET,
            LipiToken::TYPE_DOT
                => self::PREC_CALL,

            default => self::PREC_NONE,
        };
    }

    // =========================================================================
    // HELPER METHODS
    // =========================================================================

    private function peek(): LipiToken
    {
        return $this->tokens[$this->pos] ?? new LipiToken(LipiToken::TYPE_EOF, null, -1, -1);
    }

    private function peekNextToken(): LipiToken
    {
        return $this->tokens[$this->pos + 1] ?? new LipiToken(LipiToken::TYPE_EOF, null, -1, -1);
    }

    private function previous(): LipiToken
    {
        return $this->tokens[$this->pos - 1];
    }

    private function advance(): LipiToken
    {
        if (!$this->isAtEnd()) {
            $this->pos++;
        }
        return $this->previous();
    }

    private function check(string $type): bool
    {
        if ($this->isAtEnd()) {
            return false;
        }
        return $this->peek()->type === $type;
    }

    private function match(string ...$types): bool
    {
        foreach ($types as $type) {
            if ($this->check($type)) {
                $this->advance();
                return true;
            }
        }
        return false;
    }

    private function consume(string $type, string $message): LipiToken
    {
        if ($this->check($type)) {
            return $this->advance();
        }
        $current = $this->peek();
        throw new RuntimeException(sprintf(
            "%s. Found '%s' (type: %s) at line %d, column %d",
            $message,
            (string)$current->value,
            $current->type,
            $current->line,
            $current->column
        ));
    }

    private function skipNewlines(): void
    {
        while ($this->check(LipiToken::TYPE_NEWLINE)) {
            $this->advance();
        }
    }

    private function skipNewlinesAndSemicolons(): void
    {
        while ($this->check(LipiToken::TYPE_NEWLINE) || $this->check(LipiToken::TYPE_SEMICOLON)) {
            $this->advance();
        }
    }

    private function isAtEnd(): bool
    {
        return $this->pos >= $this->count || $this->peek()->type === LipiToken::TYPE_EOF;
    }
}
