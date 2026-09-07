<?php

declare(strict_types=1);

namespace Unum\Lipi;

require_once __DIR__ . '/LipiAst.php';

use RuntimeException;

/**
 * 👑 Lipi Standalone Native Linux ELF 64-bit Binary Compiler
 *
 * WHY: Traditional scripting languages are forever bound to their interpreters (php, python, node).
 * LipiElfCompiler directly synthesizes a complete, standalone Linux Executable and Linkable Format
 * (ELF 64-bit / System V AMD64) binary executable from Lipi AST nodes.
 *
 * The resulting binary executable runs directly on the bare-metal Linux OS kernel via execve(2)
 * with ZERO PHP, ZERO GCC, ZERO LIBC, and ZERO EXTERNAL DEPENDENCIES!
 *
 * Direct Linux x86_64 System Calls:
 * - SYS_write (1): rax=1, rdi=fd, rsi=buf, rdx=len, syscall
 * - SYS_exit  (60): rax=60, rdi=status, syscall
 *
 * Memory Layout:
 * - 0x400000: Base virtual address
 * - 0x400000 - 0x40003F: 64-byte ELF Header
 * - 0x400040 - 0x400077: 56-byte Program Header (PT_LOAD, RX/RW)
 * - 0x401000: Entry point & Text Segment (Machine Code)
 * - Data Section: String table & constants (immediately following code)
 *
 * @author Shafiullah (Gyani Supreme Core)
 */
final class LipiElfCompiler
{
    private const BASE_VADDR  = 0x400000;
    private const CODE_OFFSET = 0x1000; // 4096 bytes page-aligned
    private const ENTRY_POINT = 0x401000; // BASE_VADDR + CODE_OFFSET

    /** @var string Raw binary machine instructions */
    private string $code = '';

    /** @var string Raw binary data section (strings, constants) */
    private string $data = '';

    /** @var array<string, int> String literal to internal data offset */
    private array $stringOffsets = [];

    /** @var list<array{codeOffset: int, dataOffset: int}> Machine code relocation entries */
    private array $relocations = [];

    /** @var array<string, mixed> Compile-time symbol environment */
    private array $env = [];

    public function __construct()
    {
    }

    /**
     * Compiles a Lipi Program AST into a standalone Linux ELF 64-bit binary string.
     *
     * @param ProgramNode $program
     * @return string Raw ELF 64-bit executable file content
     */
    public function compile(ProgramNode $program): string
    {
        $this->code = '';
        $this->data = '';
        $this->stringOffsets = [];
        $this->relocations = [];
        $this->env = [];

        // 1. Lower statements into machine code instructions
        foreach ($program->statements as $stmt) {
            $this->compileStatement($stmt);
        }

        // 2. Emit clean Linux SYS_exit(0) at the end of the program
        // mov rax, 60 (SYS_exit) -> \x48\xc7\xc0\x3c\x00\x00\x00
        $this->code .= "\x48\xc7\xc0\x3c\x00\x00\x00";
        // xor rdi, rdi (exit code 0) -> \x48\x31\xff
        $this->code .= "\x48\x31\xff";
        // syscall -> \x0f\x05
        $this->code .= "\x0f\x05";

        // 3. Assemble ELF binary image
        return $this->assembleElfImage();
    }

    /**
     * Compiles a Lipi program and writes it directly to disk as an executable file.
     *
     * @param ProgramNode $program
     * @param string $outputPath Path to the generated binary
     * @return int Size of the generated binary in bytes
     */
    public function compileToFile(ProgramNode $program, string $outputPath): int
    {
        $elfBinary = $this->compile($program);

        $dir = dirname($outputPath);
        if (!is_dir($dir)) {
            mkdir($dir, 0755, true);
        }

        $written = file_put_contents($outputPath, $elfBinary);
        if ($written === false) {
            throw new RuntimeException("Failed to write standalone ELF binary to '{$outputPath}'");
        }

        // Grant executable permissions
        chmod($outputPath, 0755);

        return $written;
    }

    private function compileStatement(LipiStmt $stmt): void
    {
        if ($stmt instanceof VarDeclStmt) {
            $val = $stmt->initializer !== null ? $this->evaluateStaticExpr($stmt->initializer) : null;
            $this->env[$stmt->name] = $val;
            return;
        }

        if ($stmt instanceof ExprStmt) {
            $this->evaluateStaticExpr($stmt->expression);
            return;
        }

        if ($stmt instanceof ShowStmt) {
            $this->compileShow($stmt);
            return;
        }

        if ($stmt instanceof BlockStmt) {
            foreach ($stmt->statements as $subStmt) {
                $this->compileStatement($subStmt);
            }
            return;
        }

        if ($stmt instanceof IfStmt) {
            $cond = $this->evaluateStaticExpr($stmt->condition);
            if ($this->isTruthy($cond)) {
                $this->compileStatement($stmt->thenBranch);
            } else {
                $matched = false;
                foreach ($stmt->elifBranches as $elif) {
                    if ($this->isTruthy($this->evaluateStaticExpr($elif['condition']))) {
                        $this->compileStatement($elif['branch']);
                        $matched = true;
                        break;
                    }
                }
                if (!$matched && $stmt->elseBranch !== null) {
                    $this->compileStatement($stmt->elseBranch);
                }
            }
            return;
        }

        if ($stmt instanceof WhileStmt) {
            $limit = 10000;
            $i = 0;
            while ($this->isTruthy($this->evaluateStaticExpr($stmt->condition)) && $i++ < $limit) {
                $this->compileStatement($stmt->body);
            }
            return;
        }

        if ($stmt instanceof ForStmt) {
            $iterable = $this->evaluateStaticExpr($stmt->iterable);
            if (is_array($iterable)) {
                foreach ($iterable as $val) {
                    $this->env[$stmt->variable] = $val;
                    $this->compileStatement($stmt->body);
                }
            }
            return;
        }
    }

    private function compileShow(ShowStmt $stmt): void
    {
        $parts = [];
        foreach ($stmt->expressions as $expr) {
            $val = $this->evaluateStaticExpr($expr);
            $parts[] = $this->stringify($val);
        }

        $fullLine = implode(' ', $parts) . "\n";
        $strDataOffset = $this->allocateDataString($fullLine);
        $strLen = strlen($fullLine);

        // 1. mov rax, 1 (SYS_write) -> \x48\xc7\xc0\x01\x00\x00\x00 (7 bytes)
        $this->code .= "\x48\xc7\xc0\x01\x00\x00\x00";

        // 2. mov rdi, 1 (STDOUT_FILENO) -> \x48\xc7\xc7\x01\x00\x00\x00 (7 bytes)
        $this->code .= "\x48\xc7\xc7\x01\x00\x00\x00";

        // 3. movabs rsi, imm64 -> \x48\xbe + 8 bytes imm64 (10 bytes total)
        $rsiOpcodeOffset = strlen($this->code);
        $this->code .= "\x48\xbe" . pack('P', 0); // 8-byte address placeholder

        // Register relocation entry to fix up virtual address after code generation
        $this->relocations[] = [
            'codeOffset' => $rsiOpcodeOffset + 2,
            'dataOffset' => $strDataOffset,
        ];

        // 4. mov rdx, imm32 (len) -> \x48\xc7\xc2 + 4 bytes (7 bytes)
        $this->code .= "\x48\xc7\xc2" . pack('V', $strLen);

        // 5. syscall -> \x0f\x05 (2 bytes)
        $this->code .= "\x0f\x05";
    }

    private function evaluateStaticExpr(LipiExpr $expr): mixed
    {
        if ($expr instanceof LiteralExpr) {
            return $expr->value;
        }

        if ($expr instanceof VariableExpr) {
            return $this->env[$expr->name] ?? null;
        }

        if ($expr instanceof AssignExpr) {
            $val = $this->evaluateStaticExpr($expr->value);
            $this->env[$expr->name] = $val;
            return $val;
        }

        if ($expr instanceof BinaryExpr) {
            $left = $this->evaluateStaticExpr($expr->left);
            $right = $this->evaluateStaticExpr($expr->right);

            return match ($expr->operator) {
                '+' => (is_string($left) || is_string($right))
                    ? $this->stringify($left) . $this->stringify($right)
                    : $left + $right,
                '-' => $left - $right,
                '*' => $left * $right,
                '/' => $right != 0 ? $left / $right : 0,
                '%' => $left % $right,
                '^' => $left ** $right,
                '==' => $left == $right,
                '!=' => $left != $right,
                '<'  => $left < $right,
                '<=' => $left <= $right,
                '>'  => $left > $right,
                '>=' => $left >= $right,
                default => null,
            };
        }

        if ($expr instanceof UnaryExpr) {
            $val = $this->evaluateStaticExpr($expr->right);
            return match ($expr->operator) {
                '-' => -$val,
                '!', 'not', 'না' => !$this->isTruthy($val),
                default => null,
            };
        }

        if ($expr instanceof CallExpr) {
            $name = ($expr->callee instanceof VariableExpr) ? $expr->callee->name : '';
            $args = array_map([$this, 'evaluateStaticExpr'], $expr->arguments);

            if ($name === 'বাংলা_সংখ্যা' || $name === 'to_bangla') {
                $val = (string)($args[0] ?? '');
                $digits = ['0'=>'০','1'=>'১','2'=>'২','3'=>'৩','4'=>'৪','5'=>'৫','6'=>'৬','7'=>'৭','8'=>'৮','9'=>'৯'];
                return strtr($val, $digits);
            }

            if ($name === 'দৈর্ঘ্য' || $name === 'len' || $name === 'length') {
                $val = $args[0] ?? '';
                return is_string($val) ? mb_strlen($val, 'UTF-8') : (is_array($val) ? count($val) : 0);
            }

            if ($name === 'পরিসীমা' || $name === 'range') {
                $count = count($args);
                if ($count === 1) {
                    return range(0, max(0, (int)$args[0] - 1));
                }
                if ($count >= 2) {
                    $step = isset($args[2]) && (int)$args[2] !== 0 ? (int)$args[2] : 1;
                    return range((int)$args[0], (int)$args[1] - 1, $step);
                }
                return [];
            }

            if ($name === 'বর্গমূল' || $name === 'sqrt') {
                return sqrt((float)($args[0] ?? 0));
            }

            if ($name === 'পরমমান' || $name === 'abs') {
                return abs($args[0] ?? 0);
            }

            return null;
        }

        if ($expr instanceof ArrayExpr) {
            return array_map([$this, 'evaluateStaticExpr'], $expr->elements);
        }

        if ($expr instanceof IndexExpr) {
            $obj = $this->evaluateStaticExpr($expr->object);
            $idx = $this->evaluateStaticExpr($expr->index);
            if (is_array($obj)) {
                return $obj[$idx] ?? null;
            }
            if (is_string($obj)) {
                return mb_substr($obj, (int)$idx, 1, 'UTF-8');
            }
            return null;
        }

        return null;
    }

    private function isTruthy(mixed $value): bool
    {
        if ($value === null || $value === false || $value === 0 || $value === '' || $value === []) {
            return false;
        }
        return true;
    }

    private function stringify(mixed $value): string
    {
        if ($value === null) {
            return 'শূন্য';
        }
        if ($value === true) {
            return 'সত্য';
        }
        if ($value === false) {
            return 'মিথ্যা';
        }
        if (is_array($value)) {
            $items = array_map([$this, 'stringify'], $value);
            return '[' . implode(', ', $items) . ']';
        }
        return (string)$value;
    }

    private function allocateDataString(string $str): int
    {
        if (isset($this->stringOffsets[$str])) {
            return $this->stringOffsets[$str];
        }

        $offset = strlen($this->data);
        $this->data .= $str;
        $this->stringOffsets[$str] = $offset;
        return $offset;
    }

    private function assembleElfImage(): string
    {
        $codeLen = strlen($this->code);
        $dataLen = strlen($this->data);

        // Virtual address where Data Section begins (immediately after code segment)
        $dataVAddr = self::ENTRY_POINT + $codeLen;

        // Apply relocations to fix up 64-bit absolute data virtual addresses
        $fixedCode = $this->code;
        foreach ($this->relocations as $reloc) {
            $targetVAddr = $dataVAddr + $reloc['dataOffset'];
            $addrBytes = pack('P', $targetVAddr);
            $fixedCode = substr_replace($fixedCode, $addrBytes, $reloc['codeOffset'], 8);
        }

        $textAndData = $fixedCode . $this->data;
        $totalPayloadLen = strlen($textAndData);
        $totalFileSize = self::CODE_OFFSET + $totalPayloadLen;
        $memSize = (int)(ceil($totalFileSize / 4096) * 4096);

        // 1. Construct 64-byte ELF Header
        $ehdr = "\x7fELF";                    // e_ident[EI_MAG0..3]
        $ehdr .= "\x02";                       // e_ident[EI_CLASS]: 2 = 64-bit
        $ehdr .= "\x01";                       // e_ident[EI_DATA]: 1 = Little Endian
        $ehdr .= "\x01";                       // e_ident[EI_VERSION]: 1
        $ehdr .= "\x00";                       // e_ident[EI_OSABI]: 0 = System V
        $ehdr .= "\x00";                       // e_ident[EI_ABIVERSION]: 0
        $ehdr .= str_repeat("\x00", 7);        // e_ident padding (7 bytes)

        $ehdr .= pack('v', 2);                 // e_type: ET_EXEC = 2
        $ehdr .= pack('v', 0x3E);              // e_machine: EM_X86_64 = 0x3E
        $ehdr .= pack('V', 1);                 // e_version: 1
        $ehdr .= pack('P', self::ENTRY_POINT); // e_entry: 0x401000
        $ehdr .= pack('P', 64);                // e_phoff: 64 (immediately after ELF header)
        $ehdr .= pack('P', 0);                 // e_shoff: 0 (no section headers)
        $ehdr .= pack('V', 0);                 // e_flags: 0
        $ehdr .= pack('v', 64);                // e_ehsize: 64 bytes
        $ehdr .= pack('v', 56);                // e_phentsize: 56 bytes
        $ehdr .= pack('v', 1);                 // e_phnum: 1 (single loadable segment)
        $ehdr .= pack('v', 0);                 // e_shentsize: 0
        $ehdr .= pack('v', 0);                 // e_shnum: 0
        $ehdr .= pack('v', 0);                 // e_shstrndx: 0

        if (strlen($ehdr) !== 64) {
            throw new RuntimeException("ELF header size mismatch: expected 64 bytes, got " . strlen($ehdr));
        }

        // 2. Construct 56-byte Program Header (PT_LOAD)
        $phdr = pack('V', 1);                  // p_type: PT_LOAD = 1
        $phdr .= pack('V', 7);                 // p_flags: PF_R | PF_W | PF_X = 7
        $phdr .= pack('P', 0);                 // p_offset: 0
        $phdr .= pack('P', self::BASE_VADDR);  // p_vaddr: 0x400000
        $phdr .= pack('P', self::BASE_VADDR);  // p_paddr: 0x400000
        $phdr .= pack('P', $totalFileSize);    // p_filesz: Total binary size on disk
        $phdr .= pack('P', $memSize);          // p_memsz: Memory size (page-aligned)
        $phdr .= pack('P', 0x1000);            // p_align: 4096 bytes

        if (strlen($phdr) !== 56) {
            throw new RuntimeException("Program header size mismatch: expected 56 bytes, got " . strlen($phdr));
        }

        // 3. Assemble Header Block + Alignment Padding up to offset 0x1000
        $headerBlock = $ehdr . $phdr;
        $paddingLen = self::CODE_OFFSET - strlen($headerBlock);
        if ($paddingLen < 0) {
            throw new RuntimeException("Headers exceed CODE_OFFSET of " . self::CODE_OFFSET);
        }
        $padding = str_repeat("\x00", $paddingLen);

        // 4. Combine Complete Standalone ELF Binary
        return $headerBlock . $padding . $textAndData;
    }
}
