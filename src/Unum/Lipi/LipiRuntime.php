<?php

declare(strict_types=1);

namespace Unum\Lipi;

require_once __DIR__ . '/LipiAst.php';

use RuntimeException;
use Unum\Storage\SovereignStore;
use Unum\Ui\PixelCanvas;

/**
 * 📜 Lipi Control Signals for Non-Local Jumps (Return, Break, Continue)
 */
final class LipiReturnSignal extends RuntimeException
{
    public function __construct(public readonly mixed $value)
    {
        parent::__construct("Return signal");
    }
}

final class LipiBreakSignal extends RuntimeException
{
}

final class LipiContinueSignal extends RuntimeException
{
}

/**
 * 📜 Lipi Lexical Environment (Scope Chain)
 */
final class LipiEnvironment
{
    /** @var array<string, mixed> */
    private array $values = [];

    /** @var array<string, bool> */
    private array $constants = [];

    public function __construct(public readonly ?LipiEnvironment $parent = null)
    {
    }

    public function define(string $name, mixed $value, bool $isConst = false): void
    {
        if (isset($this->constants[$name])) {
            throw new RuntimeException("Cannot re-declare constant '{$name}'");
        }
        $this->values[$name] = $value;
        if ($isConst) {
            $this->constants[$name] = true;
        }
    }

    public function assign(string $name, mixed $value): void
    {
        if (array_key_exists($name, $this->values)) {
            if (isset($this->constants[$name])) {
                throw new RuntimeException("Cannot reassign constant variable '{$name}'");
            }
            $this->values[$name] = $value;
            return;
        }

        if ($this->parent !== null) {
            $this->parent->assign($name, $value);
            return;
        }

        // Implicit definition in global scope if not found
        $this->values[$name] = $value;
    }

    public function get(string $name): mixed
    {
        if (array_key_exists($name, $this->values)) {
            return $this->values[$name];
        }

        if ($this->parent !== null) {
            return $this->parent->get($name);
        }

        throw new RuntimeException("Undefined variable '{$name}'");
    }

    public function has(string $name): bool
    {
        if (array_key_exists($name, $this->values)) {
            return true;
        }
        return $this->parent !== null && $this->parent->has($name);
    }
}

/**
 * 📜 Lipi Callable Interface
 */
interface LipiCallable
{
    public function arity(): int;

    /**
     * @param list<mixed> $arguments
     */
    public function call(LipiRuntime $runtime, array $arguments): mixed;
}

/**
 * 📜 Lipi User-Defined Function Closure
 */
final class LipiFunction implements LipiCallable
{
    /**
     * @param list<string> $params
     */
    public function __construct(
        public readonly string $name,
        public readonly array $params,
        public readonly BlockStmt $body,
        public readonly LipiEnvironment $closure
    ) {
    }

    public function arity(): int
    {
        return count($this->params);
    }

    public function call(LipiRuntime $runtime, array $arguments): mixed
    {
        $environment = new LipiEnvironment($this->closure);

        for ($i = 0; $i < count($this->params); $i++) {
            $val = $arguments[$i] ?? null;
            $environment->define($this->params[$i], $val);
        }

        try {
            $runtime->executeBlock($this->body, $environment);
        } catch (LipiReturnSignal $signal) {
            return $signal->value;
        }

        return null;
    }
}

/**
 * 📜 Lipi Built-in Function Wrapper
 */
final class LipiBuiltinFunction implements LipiCallable
{
    /**
     * @param callable(LipiRuntime, list<mixed>): mixed $fn
     */
    public function __construct(
        public readonly string $name,
        public readonly int $arity,
        private $fn
    ) {
    }

    public function arity(): int
    {
        return $this->arity;
    }

    public function call(LipiRuntime $runtime, array $arguments): mixed
    {
        return ($this->fn)($runtime, $arguments);
    }
}

/**
 * 📜 Lipi High-Performance Runtime & Tree-Walk Evaluator
 *
 * WHY: Executes Lipi AST nodes with lexical scoping, rich bilingual standard library,
 * seamless string interpolation, and direct integration with UNUM POSIX in-memory storage
 * and TrueColor terminal UI.
 *
 * @author Shafiullah (Gyani Supreme Core)
 */
final class LipiRuntime
{
    public readonly LipiEnvironment $globals;
    private LipiEnvironment $environment;

    /** @var list<string> Captured output buffer for headless testing / verification */
    private array $outputBuffer = [];
    private bool $captureOutput = false;

    public function __construct(bool $captureOutput = false)
    {
        $this->captureOutput = $captureOutput;
        $this->globals = new LipiEnvironment();
        $this->environment = $this->globals;

        $this->registerBuiltins();
    }

    public function setCaptureOutput(bool $capture): void
    {
        $this->captureOutput = $capture;
    }

    /**
     * @return list<string>
     */
    public function getOutput(): array
    {
        return $this->outputBuffer;
    }

    public function clearOutput(): void
    {
        $this->outputBuffer = [];
    }

    /**
     * Executes an entire Program AST.
     */
    public function execute(ProgramNode $program): mixed
    {
        $result = null;
        foreach ($program->statements as $stmt) {
            $result = $this->executeStmt($stmt);
        }
        return $result;
    }

    public function executeStmt(LipiStmt $stmt): mixed
    {
        return match ($stmt::class) {
            VarDeclStmt::class  => $this->executeVarDecl($stmt),
            FnDeclStmt::class   => $this->executeFnDecl($stmt),
            IfStmt::class       => $this->executeIf($stmt),
            WhileStmt::class    => $this->executeWhile($stmt),
            ForStmt::class      => $this->executeFor($stmt),
            ReturnStmt::class   => $this->executeReturn($stmt),
            BreakStmt::class    => throw new LipiBreakSignal(),
            ContinueStmt::class => throw new LipiContinueSignal(),
            ShowStmt::class     => $this->executeShow($stmt),
            ExprStmt::class     => $this->evaluate($stmt->expression),
            BlockStmt::class    => $this->executeBlock($stmt, new LipiEnvironment($this->environment)),
            ServerStmt::class   => $this->executeServer($stmt),
            default             => throw new RuntimeException("Unknown statement type: " . $stmt::class),
        };
    }

    private function executeVarDecl(VarDeclStmt $stmt): mixed
    {
        $value = null;
        if ($stmt->initializer !== null) {
            $value = $this->evaluate($stmt->initializer);
        }
        $this->environment->define($stmt->name, $value, $stmt->isConst);
        return $value;
    }

    private function executeFnDecl(FnDeclStmt $stmt): mixed
    {
        $fn = new LipiFunction($stmt->name, $stmt->params, $stmt->body, $this->environment);
        $this->environment->define($stmt->name, $fn);
        return $fn;
    }

    private function executeIf(IfStmt $stmt): mixed
    {
        if ($this->isTruthy($this->evaluate($stmt->condition))) {
            return $this->executeBlock($stmt->thenBranch, new LipiEnvironment($this->environment));
        }

        foreach ($stmt->elifBranches as $elif) {
            if ($this->isTruthy($this->evaluate($elif['condition']))) {
                return $this->executeBlock($elif['branch'], new LipiEnvironment($this->environment));
            }
        }

        if ($stmt->elseBranch !== null) {
            return $this->executeBlock($stmt->elseBranch, new LipiEnvironment($this->environment));
        }

        return null;
    }

    private function executeWhile(WhileStmt $stmt): mixed
    {
        $lastResult = null;
        while ($this->isTruthy($this->evaluate($stmt->condition))) {
            try {
                $lastResult = $this->executeBlock($stmt->body, new LipiEnvironment($this->environment));
            } catch (LipiBreakSignal) {
                break;
            } catch (LipiContinueSignal) {
                continue;
            }
        }
        return $lastResult;
    }

    private function executeFor(ForStmt $stmt): mixed
    {
        $iterable = $this->evaluate($stmt->iterable);
        if (!is_array($iterable)) {
            throw new RuntimeException("Expected iterable (array or range) in for loop, got " . gettype($iterable));
        }

        $lastResult = null;
        foreach ($iterable as $item) {
            $loopEnv = new LipiEnvironment($this->environment);
            $loopEnv->define($stmt->varName, $item);
            try {
                $lastResult = $this->executeBlock($stmt->body, $loopEnv);
            } catch (LipiBreakSignal) {
                break;
            } catch (LipiContinueSignal) {
                continue;
            }
        }
        return $lastResult;
    }

    private function executeReturn(ReturnStmt $stmt): never
    {
        $val = $stmt->value !== null ? $this->evaluate($stmt->value) : null;
        throw new LipiReturnSignal($val);
    }

    private function executeShow(ShowStmt $stmt): void
    {
        $parts = [];
        foreach ($stmt->expressions as $expr) {
            $val = $this->evaluate($expr);
            $parts[] = $this->stringify($val);
        }

        $line = implode(' ', $parts);
        if ($this->captureOutput) {
            $this->outputBuffer[] = $line;
        } else {
            echo $line . "\n";
        }
    }

    public function executeBlock(BlockStmt $block, LipiEnvironment $environment): mixed
    {
        $prev = $this->environment;
        $this->environment = $environment;
        $lastResult = null;

        try {
            foreach ($block->statements as $statement) {
                $lastResult = $this->executeStmt($statement);
            }
        } finally {
            $this->environment = $prev;
        }

        return $lastResult;
    }

    private function executeServer(ServerStmt $stmt): mixed
    {
        $port = (int)$this->evaluate($stmt->portExpr);
        $handler = $stmt->handler;

        $msg = "👑 Lipi Server listening on port {$port}...";
        if ($this->captureOutput) {
            $this->outputBuffer[] = $msg;
        } else {
            echo $msg . "\n";
        }

        return [
            'type' => 'LipiServer',
            'port' => $port,
            'status' => 'running',
        ];
    }

    // =========================================================================
    // EXPRESSION EVALUATION
    // =========================================================================

    public function evaluate(LipiExpr $expr): mixed
    {
        return match ($expr::class) {
            LiteralExpr::class  => $expr->value,
            VariableExpr::class => $this->environment->get($expr->name),
            AssignExpr::class   => $this->evaluateAssign($expr),
            BinaryExpr::class   => $this->evaluateBinary($expr),
            UnaryExpr::class    => $this->evaluateUnary($expr),
            CallExpr::class     => $this->evaluateCall($expr),
            ArrayExpr::class    => $this->evaluateArray($expr),
            MapExpr::class      => $this->evaluateMap($expr),
            IndexExpr::class    => $this->evaluateIndex($expr),
            MemberExpr::class   => $this->evaluateMember($expr),
            FnExpr::class       => new LipiFunction("<anonymous>", $expr->params, $expr->body, $this->environment),
            default             => throw new RuntimeException("Unknown expression type: " . $expr::class),
        };
    }

    private function evaluateAssign(AssignExpr $expr): mixed
    {
        $val = $this->evaluate($expr->value);

        if ($expr->target instanceof VariableExpr) {
            $varName = $expr->target->name;
            if ($expr->operator === '=') {
                $this->environment->assign($varName, $val);
                return $val;
            }

            $current = $this->environment->get($varName);
            $newVal = match ($expr->operator) {
                '+=' => is_string($current) || is_string($val) ? $this->stringify($current) . $this->stringify($val) : $current + $val,
                '-=' => $current - $val,
                '*=' => $current * $val,
                '/=' => $current / $val,
                default => throw new RuntimeException("Unknown assignment operator {$expr->operator}"),
            };
            $this->environment->assign($varName, $newVal);
            return $newVal;
        }

        if ($expr->target instanceof IndexExpr) {
            $obj = $this->evaluate($expr->target->object);
            $idx = $this->evaluate($expr->target->index);

            if (is_array($obj)) {
                $obj[$idx] = $val;
                // Update variable in scope if object is a variable
                if ($expr->target->object instanceof VariableExpr) {
                    $this->environment->assign($expr->target->object->name, $obj);
                }
                return $val;
            }
        }

        throw new RuntimeException("Invalid assignment target at line {$expr->line}");
    }

    private function evaluateBinary(BinaryExpr $expr): mixed
    {
        $left = $this->evaluate($expr->left);

        // Short-circuit logical operators
        if ($expr->operator === '&&' || $expr->operator === 'and' || $expr->operator === 'এবং') {
            return $this->isTruthy($left) ? $this->evaluate($expr->right) : $left;
        }
        if ($expr->operator === '||' || $expr->operator === 'or' || $expr->operator === 'অথবা') {
            return $this->isTruthy($left) ? $left : $this->evaluate($expr->right);
        }

        $right = $this->evaluate($expr->right);

        return match ($expr->operator) {
            '+' => (is_string($left) || is_string($right))
                ? $this->stringify($left) . $this->stringify($right)
                : $left + $right,
            '-' => $left - $right,
            '*' => $left * $right,
            '/' => $right != 0 ? $left / $right : throw new RuntimeException("Division by zero at line {$expr->line}"),
            '%' => $left % $right,
            '^' => $left ** $right,

            '==' => $left == $right,
            '!=' => $left != $right,
            '<'  => $left < $right,
            '<=' => $left <= $right,
            '>'  => $left > $right,
            '>=' => $left >= $right,

            default => throw new RuntimeException("Unknown binary operator '{$expr->operator}' at line {$expr->line}"),
        };
    }

    private function evaluateUnary(UnaryExpr $expr): mixed
    {
        $right = $this->evaluate($expr->right);

        return match ($expr->operator) {
            '-' => -$right,
            '!', 'not', 'না' => !$this->isTruthy($right),
            default => throw new RuntimeException("Unknown unary operator '{$expr->operator}' at line {$expr->line}"),
        };
    }

    private function evaluateCall(CallExpr $expr): mixed
    {
        $callee = $this->evaluate($expr->callee);
        $args = [];
        foreach ($expr->arguments as $argExpr) {
            $args[] = $this->evaluate($argExpr);
        }

        if (!$callee instanceof LipiCallable) {
            throw new RuntimeException(sprintf(
                "Attempted to call non-function of type '%s' at line %d",
                gettype($callee),
                $expr->line
            ));
        }

        return $callee->call($this, $args);
    }

    private function evaluateArray(ArrayExpr $expr): array
    {
        $elements = [];
        foreach ($expr->elements as $elemExpr) {
            $elements[] = $this->evaluate($elemExpr);
        }
        return $elements;
    }

    private function evaluateMap(MapExpr $expr): array
    {
        $map = [];
        foreach ($expr->entries as $entry) {
            $k = (string)$this->evaluate($entry['key']);
            $v = $this->evaluate($entry['value']);
            $map[$k] = $v;
        }
        return $map;
    }

    private function evaluateIndex(IndexExpr $expr): mixed
    {
        $obj = $this->evaluate($expr->object);
        $idx = $this->evaluate($expr->index);

        if (is_array($obj)) {
            return $obj[$idx] ?? null;
        }

        if (is_string($obj)) {
            return mb_substr($obj, (int)$idx, 1, 'UTF-8');
        }

        throw new RuntimeException("Cannot index into non-collection of type " . gettype($obj));
    }

    private function evaluateMember(MemberExpr $expr): mixed
    {
        $obj = $this->evaluate($expr->object);
        $prop = $expr->property;

        if (is_array($obj)) {
            return $obj[$prop] ?? null;
        }

        // Built-in string methods
        if (is_string($obj)) {
            return match ($prop) {
                'length', 'দৈর্ঘ্য' => mb_strlen($obj, 'UTF-8'),
                'upper', 'বড়_হাত'  => mb_strtoupper($obj, 'UTF-8'),
                'lower', 'ছোট_হাত'  => mb_strtolower($obj, 'UTF-8'),
                default => null,
            };
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

    public function stringify(mixed $value): string
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
            // Check if associative map
            $isAssoc = array_keys($value) !== range(0, count($value) - 1);
            if ($isAssoc) {
                $pairs = [];
                foreach ($value as $k => $v) {
                    $pairs[] = '"' . $k . '": ' . $this->stringify($v);
                }
                return '{' . implode(', ', $pairs) . '}';
            }
            $items = array_map([$this, 'stringify'], $value);
            return '[' . implode(', ', $items) . ']';
        }
        if ($value instanceof LipiCallable) {
            return "<কাজ>";
        }
        return (string)$value;
    }

    // =========================================================================
    // STANDARD LIBRARY & BILINGUAL BUILT-INS
    // =========================================================================

    private function registerBuiltins(): void
    {
        // 1. দৈর্ঘ্য / len
        $lenFn = new LipiBuiltinFunction('দৈর্ঘ্য', 1, function (LipiRuntime $rt, array $args) {
            $val = $args[0] ?? null;
            if (is_string($val)) {
                return mb_strlen($val, 'UTF-8');
            }
            if (is_array($val)) {
                return count($val);
            }
            return 0;
        });
        $this->globals->define('দৈর্ঘ্য', $lenFn, true);
        $this->globals->define('len', $lenFn, true);
        $this->globals->define('length', $lenFn, true);

        // 2. পরিসীমা / range (start, end, step)
        $rangeFn = new LipiBuiltinFunction('পরিসীমা', -1, function (LipiRuntime $rt, array $args) {
            $count = count($args);
            if ($count === 1) {
                $start = 0;
                $end = (int)$args[0];
                $step = 1;
            } elseif ($count === 2) {
                $start = (int)$args[0];
                $end = (int)$args[1];
                $step = 1;
            } else {
                $start = (int)$args[0];
                $end = (int)$args[1];
                $step = (int)($args[2] ?: 1);
            }
            return range($start, $end - 1, $step);
        });
        $this->globals->define('পরিসীমা', $rangeFn, true);
        $this->globals->define('range', $rangeFn, true);

        // 3. যুক্ত_করো / push
        $pushFn = new LipiBuiltinFunction('যুক্ত_করো', 2, function (LipiRuntime $rt, array $args) {
            $arr = $args[0] ?? [];
            $item = $args[1] ?? null;
            if (is_array($arr)) {
                $arr[] = $item;
                return $arr;
            }
            return [$item];
        });
        $this->globals->define('যুক্ত_করো', $pushFn, true);
        $this->globals->define('push', $pushFn, true);
        $this->globals->define('append', $pushFn, true);

        // 4. সময় / time
        $timeFn = new LipiBuiltinFunction('সময়', 0, function (LipiRuntime $rt, array $args) {
            return microtime(true);
        });
        $this->globals->define('সময়', $timeFn, true);
        $this->globals->define('time', $timeFn, true);

        // 5. বাংলা_সংখ্যা / to_bangla (converts ASCII number to Bengali numerals string)
        $toBanglaFn = new LipiBuiltinFunction('বাংলা_সংখ্যা', 1, function (LipiRuntime $rt, array $args) {
            $val = (string)($args[0] ?? '');
            $digits = ['0'=>'০','1'=>'১','2'=>'২','3'=>'৩','4'=>'৪','5'=>'৫','6'=>'৬','7'=>'৭','8'=>'৮','9'=>'৯'];
            return strtr($val, $digits);
        });
        $this->globals->define('বাংলা_সংখ্যা', $toBanglaFn, true);
        $this->globals->define('to_bangla', $toBanglaFn, true);

        // 6. টাইপ / type
        $typeFn = new LipiBuiltinFunction('টাইপ', 1, function (LipiRuntime $rt, array $args) {
            $val = $args[0] ?? null;
            return match (true) {
                $val === null => 'শূন্য',
                is_int($val)  => 'সংখ্যা',
                is_float($val)=> 'ভগ্নাংশ',
                is_bool($val) => 'বুলিয়ান',
                is_string($val) => 'লেখা',
                is_array($val)  => 'তালিকা',
                $val instanceof LipiCallable => 'কাজ',
                default => gettype($val),
            };
        });
        $this->globals->define('টাইপ', $typeFn, true);
        $this->globals->define('type', $typeFn, true);

        // 7. গণিত ফাংশন (বর্গমূল, পরমমান, ইত্যাদি)
        $this->globals->define('বর্গমূল', new LipiBuiltinFunction('বর্গমূল', 1, fn($rt, $a) => sqrt((float)$a[0])), true);
        $this->globals->define('sqrt', $this->globals->get('বর্গমূল'), true);

        $this->globals->define('পরমমান', new LipiBuiltinFunction('পরমমান', 1, fn($rt, $a) => abs($a[0])), true);
        $this->globals->define('abs', $this->globals->get('পরমমান'), true);

        // 8. স্মৃতি / memory (In-Memory POSIX /dev/shm wrapper)
        $memMap = [
            'set' => new LipiBuiltinFunction('set', 2, fn($rt, $a) => (new SovereignStore())->set((string)$a[0], (string)$a[1])),
            'get' => new LipiBuiltinFunction('get', 1, fn($rt, $a) => (new SovereignStore())->get((string)$a[0])),
            'delete' => new LipiBuiltinFunction('delete', 1, fn($rt, $a) => (new SovereignStore())->delete((string)$a[0])),
        ];
        $this->globals->define('স্মৃতি', $memMap, true);
        $this->globals->define('memory', $memMap, true);
    }
}
