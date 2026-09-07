<?php

declare(strict_types=1);

namespace Unum\Lipi;

require_once __DIR__ . '/LipiToken.php';
require_once __DIR__ . '/LipiLexer.php';
require_once __DIR__ . '/LipiAst.php';
require_once __DIR__ . '/LipiParser.php';
require_once __DIR__ . '/LipiRuntime.php';

use RuntimeException;
use Throwable;

/**
 * 👑 Lipi Programming Language Master Engine Facade
 *
 * WHY: Provides the primary developer-facing interface to tokenize, parse,
 * analyze, and execute Lipi (.lp / .lipi) programs. Includes high-fidelity
 * visual diagnostic error formatting with source-line excerpts and column pointers.
 *
 * @author Shafiullah (Gyani Supreme Core)
 */
final class LipiEngine
{
    private LipiRuntime $runtime;

    public function __construct(bool $captureOutput = false)
    {
        $this->runtime = new LipiRuntime($captureOutput);
    }

    public function getRuntime(): LipiRuntime
    {
        return $this->runtime;
    }

    /**
     * Executes a Lipi source file (.lp or .lipi).
     */
    public function runFile(string $filePath): mixed
    {
        if (!file_exists($filePath)) {
            throw new RuntimeException("Lipi source file not found: {$filePath}");
        }

        $source = file_get_contents($filePath);
        if ($source === false) {
            throw new RuntimeException("Failed to read Lipi source file: {$filePath}");
        }

        return $this->runString($source, $filePath);
    }

    /**
     * Executes a Lipi source string with full error trapping.
     */
    public function runString(string $source, ?string $filename = '<inline>'): mixed
    {
        try {
            // 1. Lexical Analysis
            $lexer = new LipiLexer($source);
            $tokens = $lexer->tokenize();

            // 2. Syntax Parsing (Pratt)
            $parser = new LipiParser($tokens);
            $program = $parser->parse();

            // 3. Runtime Execution
            return $this->runtime->execute($program);
        } catch (Throwable $e) {
            $formattedError = $this->formatDiagnosticError($e, $source, $filename);
            throw new RuntimeException($formattedError, 0, $e);
        }
    }

    /**
     * Formats an error with line and column highlighting pointer.
     */
    private function formatDiagnosticError(Throwable $e, string $source, ?string $filename): string
    {
        $msg = $e->getMessage();
        $line = 1;
        $column = 1;

        // Extract line and column from error message if available
        if (preg_match('/line (\d+)(?:, column (\d+))?/', $msg, $matches)) {
            $line = (int)$matches[1];
            $column = isset($matches[2]) ? (int)$matches[2] : 1;
        }

        $lines = explode("\n", $source);
        $errorLineContent = $lines[$line - 1] ?? '';
        $pointer = str_repeat(' ', max(0, $column - 1)) . '▲';

        return sprintf(
            "\n❌ [লিপি সিনট্যাক্স এরর / Lipi Syntax Error] in %s:\n" .
            "   %s\n\n" .
            "   %4d | %s\n" .
            "        | %s\n",
            $filename,
            $msg,
            $line,
            $errorLineContent,
            $pointer
        );
    }

    /**
     * Tokenizes a source string and returns list of LipiTokens.
     *
     * @return list<LipiToken>
     */
    public function tokenize(string $source): array
    {
        $lexer = new LipiLexer($source);
        return $lexer->tokenize();
    }

    /**
     * Parses a source string and returns the Program AST.
     */
    public function parse(string $source): ProgramNode
    {
        $tokens = $this->tokenize($source);
        $parser = new LipiParser($tokens);
        return $parser->parse();
    }
}
