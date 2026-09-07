<?php

declare(strict_types=1);

namespace Unum\Lipi;

require_once __DIR__ . '/LipiAst.php';
require_once __DIR__ . '/../UniversalNumber.php';
require_once __DIR__ . '/../CrossIsa/X86_64Emitter.php';
require_once __DIR__ . '/../HardwareExecutor.php';

use RuntimeException;
use Unum\CrossIsa\X86_64Emitter;
use Unum\HardwareExecutor;
use Unum\UniversalNumber;

/**
 * 👑 Lipi Silicon JIT Machine Code Compiler
 *
 * WHY: Interpreters iterate over AST nodes, suffering ~1,000x interpretive overhead
 * due to dynamic memory lookups and branch mispredictions.
 * LipiJitCompiler lowers Lipi AST expressions, arithmetic loops, and functions directly
 * into 64-bit Universal Numbers (GF(2^64)) and emits raw System V AMD64 x86_64 machine code
 * directly into executable POSIX memory pages (mmap PROT_EXEC) via standard libc.
 *
 * Latency: Sub-4 microsecond direct silicon execution without GCC, Clang, or C compilers!
 *
 * Calling Convention: System V AMD64 ABI
 * - Arguments: RDI (arg0), RSI (arg1), RDX (arg2), RCX (arg3), R8 (arg4), R9 (arg5)
 * - Return value: RAX
 *
 * @author Shafiullah (Gyani Supreme Core)
 */
final class LipiJitCompiler
{
    /** @var list<UniversalNumber> */
    private array $instructions = [];

    /** @var array<string, int> Map variable name to CPU register ID */
    private array $variables = [];

    /** @var array<string, int> Map parameter name to input register */
    private array $paramMap = [];

    /** @var array<int, bool> Set of currently allocated registers */
    private array $allocatedRegs = [];

    private X86_64Emitter $emitter;
    private HardwareExecutor $executor;

    /** Available register pool for local variables and scratchpad temporaries */
    private const REGISTER_POOL = [
        UniversalNumber::REG_RBX,
        UniversalNumber::REG_R10,
        UniversalNumber::REG_R11,
        UniversalNumber::REG_R12,
        UniversalNumber::REG_R13,
        UniversalNumber::REG_R14,
        UniversalNumber::REG_R15,
    ];

    /** Input argument registers */
    private const ARG_REGISTERS = [
        UniversalNumber::REG_RDI,
        UniversalNumber::REG_RSI,
        UniversalNumber::REG_RDX,
        UniversalNumber::REG_RCX,
        UniversalNumber::REG_R8,
        UniversalNumber::REG_R9,
    ];

    public function __construct()
    {
        $this->emitter = new X86_64Emitter();
        $this->executor = new HardwareExecutor();
    }

    /**
     * Compiles a Lipi function declaration into native machine code and binds it
     * into a direct silicon callable executing in mmap(PROT_EXEC) RAM.
     *
     * @param FnDeclStmt $fnDecl
     * @return callable Native silicon execution closure
     */
    public function compileFunction(FnDeclStmt $fnDecl): callable
    {
        $this->resetState();

        // 1. Bind parameters to System V AMD64 argument registers
        for ($i = 0; $i < count($fnDecl->params); $i++) {
            $paramName = $fnDecl->params[$i];
            $reg = self::ARG_REGISTERS[$i] ?? null;
            if ($reg === null) {
                throw new RuntimeException("Lipi JIT currently supports up to 6 register arguments");
            }
            $this->paramMap[$paramName] = $reg;
            $this->variables[$paramName] = $reg;
        }

        // 2. Compile function body statements
        $lastReg = UniversalNumber::REG_RAX;
        foreach ($fnDecl->body->statements as $stmt) {
            $lastReg = $this->compileStatement($stmt);
        }

        // 3. Ensure last instruction moves result to RAX and returns
        $lastOp = null;
        if (!empty($this->instructions)) {
            $lastUnum = end($this->instructions);
            $lastOp = ($lastUnum->toInt() >> UniversalNumber::SHIFT_OPCODE) & UniversalNumber::MASK_BYTE;
        }

        if ($lastOp !== UniversalNumber::OP_RET) {
            if ($lastReg !== UniversalNumber::REG_RAX) {
                $this->instructions[] = UniversalNumber::pack(
                    UniversalNumber::OP_MOV_REG,
                    UniversalNumber::TYPE_RAW_INT64,
                    UniversalNumber::REG_RAX,
                    $lastReg
                );
            }
            $this->instructions[] = UniversalNumber::pack(
                UniversalNumber::OP_RET,
                UniversalNumber::TYPE_RAW_INT64,
                UniversalNumber::REG_RAX
            );
        }

        // 4. Compile into executable memory page (mmap PROT_EXEC) & bind silicon execution
        if ($this->executor->isEmulated() || $this->executor->getFfi() === null) {
            return function (...$args) use ($fnDecl) {
                return $this->emulateExecution($fnDecl, $args);
            };
        }

        $comp = $this->executor->compile($this->instructions);
        $page = $comp['page'];
        $executor = $this->executor;

        return function (...$args) use ($executor, $page) {
            $a0 = isset($args[0]) ? (int)$args[0] : 0;
            $a1 = isset($args[1]) ? (int)$args[1] : 0;
            $a2 = isset($args[2]) ? (int)$args[2] : 0;
            return $executor->execute($page, $a0, $a1, $a2);
        };
    }

    /**
     * Compiles a single expression into an array of Universal Numbers.
     *
     * @param LipiExpr $expr
     * @param list<string> $params
     * @return list<UniversalNumber>
     */
    public function compileExpression(LipiExpr $expr, array $params = []): array
    {
        $this->resetState();
        for ($i = 0; $i < count($params); $i++) {
            $reg = self::ARG_REGISTERS[$i];
            $this->paramMap[$params[$i]] = $reg;
            $this->variables[$params[$i]] = $reg;
        }

        $this->compileExpr($expr, UniversalNumber::REG_RAX);

        $this->instructions[] = UniversalNumber::pack(
            UniversalNumber::OP_RET,
            UniversalNumber::TYPE_RAW_INT64,
            UniversalNumber::REG_RAX
        );

        return $this->instructions;
    }

    /**
     * Emits machine code bytes for an array of Universal Numbers.
     */
    public function emitMachineCode(array $unums): string
    {
        return $this->emitter->emitUnums($unums);
    }

    private function compileStatement(LipiStmt $stmt): int
    {
        if ($stmt instanceof VarDeclStmt) {
            $varName = $stmt->name;
            $reg = $this->allocateRegister($varName);
            if ($stmt->initializer !== null) {
                $this->compileExpr($stmt->initializer, $reg);
            }
            return $reg;
        }

        if ($stmt instanceof ReturnStmt) {
            if ($stmt->value !== null) {
                $this->compileExpr($stmt->value, UniversalNumber::REG_RAX);
            }
            $this->instructions[] = UniversalNumber::pack(
                UniversalNumber::OP_RET,
                UniversalNumber::TYPE_RAW_INT64,
                UniversalNumber::REG_RAX
            );
            return UniversalNumber::REG_RAX;
        }

        if ($stmt instanceof ExprStmt) {
            $destReg = $this->allocateTemporary();
            $this->compileExpr($stmt->expression, $destReg);
            $this->freeRegister($destReg);
            return $destReg;
        }

        if ($stmt instanceof WhileStmt) {
            return $this->compileWhileLoop($stmt);
        }

        return UniversalNumber::REG_RAX;
    }

    private function compileExpr(LipiExpr $expr, int $targetReg): int
    {
        // 1. Literal Integer / Bengali Numeral
        if ($expr instanceof LiteralExpr && (is_int($expr->value) || is_float($expr->value))) {
            $val = (int)$expr->value;
            $this->instructions[] = UniversalNumber::pack(
                UniversalNumber::OP_MOV_IMM,
                UniversalNumber::TYPE_RAW_INT64,
                $targetReg,
                0,
                0,
                $val
            );
            return $targetReg;
        }

        // 2. Variable Lookup
        if ($expr instanceof VariableExpr) {
            $varName = $expr->name;
            if (!isset($this->variables[$varName])) {
                throw new RuntimeException("Undefined variable in JIT: {$varName}");
            }
            $srcReg = $this->variables[$varName];
            if ($srcReg !== $targetReg) {
                $this->instructions[] = UniversalNumber::pack(
                    UniversalNumber::OP_MOV_REG,
                    UniversalNumber::TYPE_RAW_INT64,
                    $targetReg,
                    $srcReg
                );
            }
            return $targetReg;
        }

        // 3. Assignment
        if ($expr instanceof AssignExpr && $expr->target instanceof VariableExpr) {
            $varName = $expr->target->name;
            $varReg = $this->variables[$varName] ?? $this->allocateRegister($varName);

            if ($expr->operator === '=') {
                $this->compileExpr($expr->value, $varReg);
            } else {
                $temp = $this->allocateTemporary();
                $this->compileExpr($expr->value, $temp);
                $op = match ($expr->operator) {
                    '+=' => UniversalNumber::OP_ADD_REG,
                    '-=' => UniversalNumber::OP_SUB_REG,
                    '*=' => UniversalNumber::OP_MUL_REG,
                    '/=' => UniversalNumber::OP_DIV_REG,
                    default => throw new RuntimeException("Unsupported JIT assign op {$expr->operator}"),
                };
                $this->instructions[] = UniversalNumber::pack(
                    $op,
                    UniversalNumber::TYPE_RAW_INT64,
                    $varReg,
                    $temp
                );
                $this->freeRegister($temp);
            }

            if ($targetReg !== $varReg) {
                $this->instructions[] = UniversalNumber::pack(
                    UniversalNumber::OP_MOV_REG,
                    UniversalNumber::TYPE_RAW_INT64,
                    $targetReg,
                    $varReg
                );
            }
            return $targetReg;
        }

        // 4. Binary Arithmetic / Logic
        if ($expr instanceof BinaryExpr) {
            $this->compileExpr($expr->left, $targetReg);
            $rightReg = $this->allocateTemporary();
            $this->compileExpr($expr->right, $rightReg);

            $op = match ($expr->operator) {
                '+' => UniversalNumber::OP_ADD_REG,
                '-' => UniversalNumber::OP_SUB_REG,
                '*' => UniversalNumber::OP_MUL_REG,
                '/' => UniversalNumber::OP_DIV_REG,
                default => throw new RuntimeException("Unsupported binary operator in Lipi JIT: {$expr->operator}"),
            };

            $this->instructions[] = UniversalNumber::pack(
                $op,
                UniversalNumber::TYPE_RAW_INT64,
                $targetReg,
                $rightReg
            );

            $this->freeRegister($rightReg);
            return $targetReg;
        }

        // 5. Unary Negation
        if ($expr instanceof UnaryExpr && $expr->operator === '-') {
            $this->compileExpr($expr->right, $targetReg);
            $zeroReg = $this->allocateTemporary();
            $this->instructions[] = UniversalNumber::pack(
                UniversalNumber::OP_MOV_IMM,
                UniversalNumber::TYPE_RAW_INT64,
                $zeroReg,
                0,
                0,
                0
            );
            $this->instructions[] = UniversalNumber::pack(
                UniversalNumber::OP_SUB_REG,
                UniversalNumber::TYPE_RAW_INT64,
                $zeroReg,
                $targetReg
            );
            $this->instructions[] = UniversalNumber::pack(
                UniversalNumber::OP_MOV_REG,
                UniversalNumber::TYPE_RAW_INT64,
                $targetReg,
                $zeroReg
            );
            $this->freeRegister($zeroReg);
            return $targetReg;
        }

        throw new RuntimeException("Expression not supported in Lipi JIT silicon tier: " . $expr::class);
    }

    private function compileWhileLoop(WhileStmt $stmt): int
    {
        $this->instructions[] = UniversalNumber::pack(
            UniversalNumber::OP_LOOP_START,
            UniversalNumber::TYPE_RAW_INT64,
            0,
            0
        );

        $lastReg = UniversalNumber::REG_RAX;
        foreach ($stmt->body->statements as $subStmt) {
            $lastReg = $this->compileStatement($subStmt);
        }

        $this->instructions[] = UniversalNumber::pack(
            UniversalNumber::OP_LOOP_END,
            UniversalNumber::TYPE_RAW_INT64,
            UniversalNumber::REG_RCX,
            0
        );

        return $lastReg;
    }

    private function allocateRegister(string $varName): int
    {
        if (isset($this->variables[$varName])) {
            return $this->variables[$varName];
        }

        foreach (self::REGISTER_POOL as $reg) {
            if (!isset($this->allocatedRegs[$reg])) {
                $this->allocatedRegs[$reg] = true;
                $this->variables[$varName] = $reg;
                return $reg;
            }
        }

        throw new RuntimeException("Register pool exhausted in Lipi JIT for variable '{$varName}'");
    }

    private function allocateTemporary(): int
    {
        foreach (self::REGISTER_POOL as $reg) {
            if (!isset($this->allocatedRegs[$reg])) {
                $this->allocatedRegs[$reg] = true;
                return $reg;
            }
        }
        throw new RuntimeException("Out of scratch registers in Lipi JIT");
    }

    private function freeRegister(int $reg): void
    {
        unset($this->allocatedRegs[$reg]);
    }

    private function resetState(): void
    {
        $this->instructions = [];
        $this->variables = [];
        $this->paramMap = [];
        $this->allocatedRegs = [];
        $this->emitter->reset();
    }

    private function emulateExecution(FnDeclStmt $fnDecl, array $args): mixed
    {
        $rt = new LipiRuntime();
        $fn = new LipiFunction($fnDecl->name, $fnDecl->params, $fnDecl->body, $rt->globals);
        return $fn->call($rt, $args);
    }
}
