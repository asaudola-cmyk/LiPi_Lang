<?php

declare(strict_types=1);

namespace Unum\Lipi;

require_once __DIR__ . '/LipiAst.php';
require_once __DIR__ . '/LipiStdLib.php';
require_once __DIR__ . '/../Storage/SovereignStore.php';

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

    /**
     * @return array<string, mixed>
     */
    public function getLocalValues(): array
    {
        return $this->values;
    }
}

/**
 * 📜 Lipi User Exception Container
 */
final class LipiUserException extends RuntimeException
{
    public function __construct(public readonly mixed $errorValue)
    {
        parent::__construct(is_string($errorValue) ? $errorValue : json_encode($errorValue));
    }
}

/**
 * 📜 Lipi Struct Blueprint
 */
final class LipiStructBlueprint
{
    /**
     * @param list<string> $fields
     * @param list<FnDeclStmt> $methods
     */
    public function __construct(
        public readonly string $name,
        public readonly array $fields,
        public readonly array $methods,
        public readonly LipiEnvironment $closure
    ) {
    }

    /**
     * @param list<mixed> $arguments
     * @param array<string, mixed> $namedArguments
     */
    public function instantiate(LipiRuntime $runtime, array $arguments = [], array $namedArguments = []): LipiStructInstance
    {
        $fieldMap = [];
        for ($i = 0; $i < count($this->fields); $i++) {
            $fieldName = $this->fields[$i];
            if (array_key_exists($fieldName, $namedArguments)) {
                $fieldMap[$fieldName] = $namedArguments[$fieldName];
            } else {
                $fieldMap[$fieldName] = $arguments[$i] ?? null;
            }
        }
        // Also capture any extra named arguments
        foreach ($namedArguments as $k => $v) {
            if (!array_key_exists($k, $fieldMap)) {
                $fieldMap[$k] = $v;
            }
        }
        return new LipiStructInstance($this, $fieldMap, $runtime);
    }
}

/**
 * 📜 Lipi Struct / Object Instance
 */
final class LipiStructInstance
{
    /**
     * @param array<string, mixed> $fields
     */
    public function __construct(
        public readonly LipiStructBlueprint $blueprint,
        private array $fields,
        private LipiRuntime $runtime
    ) {
    }

    public function get(string $name): mixed
    {
        if (array_key_exists($name, $this->fields)) {
            return $this->fields[$name];
        }

        // Method lookup
        foreach ($this->blueprint->methods as $m) {
            if ($m->name === $name) {
                $env = new LipiEnvironment($this->blueprint->closure);
                $env->define('এই', $this); // এই = this in Bengali
                $env->define('this', $this);
                return new LipiFunction($m->name, $m->params, $m->body, $env);
            }
        }

        return null;
    }

    public function set(string $name, mixed $value): void
    {
        $this->fields[$name] = $value;
    }

    /**
     * @return array<string, mixed>
     */
    public function toArray(): array
    {
        return $this->fields;
    }
}

/**
 * 📜 Lipi Go-Style Async Channel
 *
 * Supports buffered and unbuffered message passing across fibers.
 * Coordinates cooperative fiber suspension and resumption without blocking OS threads.
 */
final class LipiChannel
{
    /** @var array<int, mixed> Internal circular FIFO buffer */
    private array $buffer = [];

    /** @var list<\Fiber> Queue of fibers suspended waiting to receive */
    private array $waitingReceivers = [];

    /** @var list<array{fiber: \Fiber, value: mixed}> Queue of fibers suspended waiting to send */
    private array $waitingSenders = [];

    private bool $closed = false;

    public function __construct(public readonly int $capacity = 0)
    {
    }

    /**
     * Sends a value into the channel.
     * Suspends fiber if buffer is full or unbuffered until a receiver arrives.
     */
    public function send(mixed $value, ?LipiRuntime $runtime = null): void
    {
        if ($this->closed) {
            throw new \RuntimeException("Cannot send on closed Lipi channel");
        }

        // 1. If a receiver is already waiting, hand over value directly
        if (!empty($this->waitingReceivers)) {
            $receiver = array_shift($this->waitingReceivers);
            if ($receiver->isSuspended()) {
                $receiver->resume($value);
                return;
            }
        }

        // 2. If channel has capacity and buffer has room
        if ($this->capacity > 0 && count($this->buffer) < $this->capacity) {
            $this->buffer[] = $value;
            return;
        }

        // 3. Otherwise, suspend current fiber if running inside one
        $curFiber = \Fiber::getCurrent();
        if ($curFiber !== null) {
            $this->waitingSenders[] = ['fiber' => $curFiber, 'value' => $value];
            \Fiber::suspend();
        } else {
            // Main thread unbuffered fallback: buffer directly
            $this->buffer[] = $value;
        }
    }

    /**
     * Receives a value from the channel.
     * Suspends fiber if channel is empty until a sender delivers data.
     */
    public function receive(?LipiRuntime $runtime = null): mixed
    {
        // 1. If buffer has items, pop the oldest
        if (!empty($this->buffer)) {
            $val = array_shift($this->buffer);

            // If a sender was waiting to push into buffer, dequeue it
            if (!empty($this->waitingSenders)) {
                $senderItem = array_shift($this->waitingSenders);
                $this->buffer[] = $senderItem['value'];
                if ($senderItem['fiber']->isSuspended()) {
                    $senderItem['fiber']->resume();
                }
            }
            return $val;
        }

        // 2. If unbuffered and a sender is waiting, receive directly
        if (!empty($this->waitingSenders)) {
            $senderItem = array_shift($this->waitingSenders);
            if ($senderItem['fiber']->isSuspended()) {
                $senderItem['fiber']->resume();
            }
            return $senderItem['value'];
        }

        if ($this->closed) {
            return null;
        }

        // 3. Channel is empty: suspend current fiber
        $curFiber = \Fiber::getCurrent();
        if ($curFiber !== null) {
            $this->waitingReceivers[] = $curFiber;
            return \Fiber::suspend();
        }

        return null;
    }

    public function close(): void
    {
        $this->closed = true;
        // Wake up all waiting receivers with null
        while (!empty($this->waitingReceivers)) {
            $receiver = array_shift($this->waitingReceivers);
            if ($receiver->isSuspended()) {
                $receiver->resume(null);
            }
        }
    }

    public function isClosed(): bool
    {
        return $this->closed;
    }

    public function count(): int
    {
        return count($this->buffer);
    }
}

/**
 * 📜 Lipi Fiber Handle
 *
 * Represents an asynchronous fiber task spawned via `সহযোগ { ... }` or `spawn fn()`.
 */
final class LipiFiberHandle
{
    public mixed $result = null;
    public bool $completed = false;
    public ?\Throwable $error = null;

    public function __construct(
        public readonly int $id,
        public readonly \Fiber $fiber
    ) {
    }

    public function await(LipiRuntime $runtime): mixed
    {
        if ($this->completed) {
            if ($this->error !== null) {
                throw $this->error;
            }
            return $this->result;
        }

        // Drive runtime scheduler until this fiber completes
        $runtime->runSchedulerUntil(fn() => $this->completed);

        if ($this->error !== null) {
            throw $this->error;
        }
        return $this->result;
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

    /** @var string Base directory for resolving relative imports */
    private string $currentFileDir = '.';

    /** @var array<string, array<string, mixed>> Module exports cache to avoid circular imports */
    private array $moduleCache = [];

    /** @var array<int, LipiFiberHandle> Active asynchronous fibers managed by the runtime */
    private array $activeFibers = [];
    private int $nextFiberId = 1;

    /** @var list<string>|null Command-line arguments passed to the running Lipi program */
    private ?array $cliArguments = null;

    public function __construct(bool $captureOutput = false)
    {
        $this->captureOutput = $captureOutput;
        $this->globals = new LipiEnvironment();
        $this->environment = $this->globals;

        $this->registerBuiltins();
    }

    public function setCurrentFileDir(string $dir): void
    {
        $this->currentFileDir = $dir;
    }

    public function getCurrentFileDir(): string
    {
        return $this->currentFileDir;
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
     * Sets command-line arguments passed to the Lipi script.
     *
     * @param list<string> $args
     */
    public function setArguments(array $args): void
    {
        $this->cliArguments = array_values($args);
    }

    /**
     * Gets command-line arguments passed to the Lipi script.
     * WHY: Sovereign programming languages require first-class access to system CLI arguments
     * for building standalone compilers, package managers, and command-line tools in Lipi itself.
     *
     * @return list<string>
     */
    public function getArguments(): array
    {
        if ($this->cliArguments !== null) {
            return $this->cliArguments;
        }
        if (isset($GLOBALS['argv']) && is_array($GLOBALS['argv'])) {
            return array_values(array_slice($GLOBALS['argv'], 2));
        }
        return [];
    }

    /**
     * Spawns an asynchronous fiber task.
     * WHY: Implements lightweight cooperative concurrency without thread overhead.
     */
    public function spawnFiber(callable $callback): LipiFiberHandle
    {
        $id = $this->nextFiberId++;
        $fiber = new \Fiber($callback);
        $handle = new LipiFiberHandle($id, $fiber);
        $this->activeFibers[$id] = $handle;

        // Eagerly start the fiber up to its first suspension point
        try {
            $fiber->start();
            if ($fiber->isTerminated()) {
                $handle->result = $fiber->getReturn();
                $handle->completed = true;
                unset($this->activeFibers[$id]);
            }
        } catch (\Throwable $e) {
            $handle->error = $e;
            $handle->completed = true;
            unset($this->activeFibers[$id]);
        }

        return $handle;
    }

    /**
     * Drives the cooperative scheduler until all active fibers complete
     * or an optional predicate condition is satisfied.
     */
    public function runSchedulerUntil(?callable $predicate = null): void
    {
        $maxRounds = 50000;
        $round = 0;

        while (!empty($this->activeFibers) && $round++ < $maxRounds) {
            if ($predicate !== null && $predicate()) {
                return;
            }

            $progress = false;
            foreach ($this->activeFibers as $id => $handle) {
                $fiber = $handle->fiber;
                if (!$fiber->isStarted()) {
                    try {
                        $fiber->start();
                        $progress = true;
                    } catch (\Throwable $e) {
                        $handle->error = $e;
                        $handle->completed = true;
                        unset($this->activeFibers[$id]);
                        continue;
                    }
                }

                if ($fiber->isTerminated()) {
                    $handle->result = $fiber->getReturn();
                    $handle->completed = true;
                    unset($this->activeFibers[$id]);
                    $progress = true;
                }
            }

            if ($predicate !== null && $predicate()) {
                return;
            }

            if (!$progress && empty($this->activeFibers)) {
                break;
            }

            // Yield microscopic slice to allow I/O and channels to settle
            usleep(50);
        }
    }

    public function runScheduler(): void
    {
        $this->runSchedulerUntil(null);
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
        // Drain any remaining active fibers before finishing
        $this->runScheduler();
        return $result;
    }

    public function executeStmt(LipiStmt $stmt): mixed
    {
        return match ($stmt::class) {
            VarDeclStmt::class    => $this->executeVarDecl($stmt),
            FnDeclStmt::class     => $this->executeFnDecl($stmt),
            IfStmt::class         => $this->executeIf($stmt),
            WhileStmt::class      => $this->executeWhile($stmt),
            ForStmt::class        => $this->executeFor($stmt),
            ReturnStmt::class     => $this->executeReturn($stmt),
            BreakStmt::class      => throw new LipiBreakSignal(),
            ContinueStmt::class   => throw new LipiContinueSignal(),
            ImportStmt::class     => $this->executeImport($stmt),
            StructDeclStmt::class => $this->executeStructDecl($stmt),
            TryCatchStmt::class   => $this->executeTryCatch($stmt),
            ThrowStmt::class      => $this->executeThrow($stmt),
            ShowStmt::class       => $this->executeShow($stmt),
            ExprStmt::class       => $this->evaluate($stmt->expression),
            BlockStmt::class      => $this->executeBlock($stmt, new LipiEnvironment($this->environment)),
            ServerStmt::class     => $this->executeServer($stmt),
            default               => throw new RuntimeException("Unknown statement type: " . $stmt::class),
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

    private function executeImport(ImportStmt $stmt): void
    {
        $rawPath = $stmt->path;
        $resolvedPath = null;

        // Project root reference for global package lookup
        $projectRoot = dirname(__DIR__, 3);

        // Candidate search paths in hierarchical order
        $candidates = [
            $this->currentFileDir . '/' . $rawPath,
            $this->currentFileDir . '/' . $rawPath . '.lp',
            $this->currentFileDir . '/lipi_modules/' . $rawPath . '/main.lp',
            $this->currentFileDir . '/lipi_modules/' . $rawPath . '/index.lp',
            $this->currentFileDir . '/lipi_modules/' . $rawPath . '.lp',
            $projectRoot . '/lipi_modules/' . $rawPath . '/main.lp',
            $projectRoot . '/lipi_modules/' . $rawPath . '/index.lp',
            $projectRoot . '/lipi_modules/' . $rawPath . '.lp',
            $rawPath,
            $rawPath . '.lp',
        ];

        foreach ($candidates as $candidate) {
            if (file_exists($candidate) && !is_dir($candidate)) {
                $resolvedPath = $candidate;
                break;
            }
        }

        if ($resolvedPath === null) {
            throw new RuntimeException("মডিউল ফাইল পাওয়া যায়নি (Module not found): '{$rawPath}' at line {$stmt->line}");
        }

        $canonical = realpath($resolvedPath) ?: $resolvedPath;

        if (isset($this->moduleCache[$canonical])) {
            $exports = $this->moduleCache[$canonical];
        } else {
            $content = file_get_contents($canonical);
            if ($content === false) {
                throw new RuntimeException("মডিউল পড়া যায়নি (Failed to read module): '{$canonical}' at line {$stmt->line}");
            }

            $lexer = new LipiLexer($content);
            $tokens = $lexer->tokenize();
            $parser = new LipiParser($tokens);
            $ast = $parser->parse();

            $modRuntime = new LipiRuntime($this->captureOutput);
            $modRuntime->setCurrentFileDir(dirname($canonical));
            $modRuntime->execute($ast);

            $exports = $modRuntime->globals->getLocalValues();
            $this->moduleCache[$canonical] = $exports;
        }

        $alias = $stmt->alias;
        if ($alias === null) {
            $alias = pathinfo($canonical, PATHINFO_FILENAME);
        }

        $this->environment->define($alias, $exports);
    }

    private function executeStructDecl(StructDeclStmt $stmt): void
    {
        $blueprint = new LipiStructBlueprint($stmt->name, $stmt->fields, $stmt->methods, $this->environment);
        $this->environment->define($stmt->name, $blueprint);
    }

    private function executeTryCatch(TryCatchStmt $stmt): mixed
    {
        try {
            return $this->executeBlock($stmt->tryBranch, new LipiEnvironment($this->environment));
        } catch (LipiReturnSignal | LipiBreakSignal | LipiContinueSignal $signal) {
            throw $signal;
        } catch (\Throwable $e) {
            $catchEnv = new LipiEnvironment($this->environment);
            $errVal = ($e instanceof LipiUserException) ? $e->errorValue : $e->getMessage();
            $catchEnv->define($stmt->errorVar, $errVal);
            return $this->executeBlock($stmt->catchBranch, $catchEnv);
        }
    }

    private function executeThrow(ThrowStmt $stmt): never
    {
        $val = $this->evaluate($stmt->expression);
        throw new LipiUserException($val);
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
            NewExpr::class      => $this->evaluateNew($expr),
            SpawnExpr::class    => $this->evaluateSpawn($expr),
            AwaitExpr::class    => $this->evaluateAwait($expr),
            ChannelExpr::class  => $this->evaluateChannel($expr),
            FnExpr::class       => new LipiFunction("<anonymous>", $expr->params, $expr->body, $this->environment),
            default             => throw new RuntimeException("Unknown expression type: " . $expr::class),
        };
    }

    private function evaluateNew(NewExpr $expr): mixed
    {
        // Support built-in Channel creation: নতুন চ্যানেল() or new Channel(10)
        if ($expr->structName === 'চ্যানেল' || $expr->structName === 'channel') {
            $cap = 0;
            if (!empty($expr->arguments)) {
                $cap = (int)$this->evaluate($expr->arguments[0]);
            } elseif (isset($expr->namedArguments['ধারণক্ষমতা'])) {
                $cap = (int)$this->evaluate($expr->namedArguments['ধারণক্ষমতা']);
            } elseif (isset($expr->namedArguments['capacity'])) {
                $cap = (int)$this->evaluate($expr->namedArguments['capacity']);
            }
            return new LipiChannel($cap);
        }

        // Resolve struct blueprint from current scope or imported module (e.g. ওয়েব.রিকোয়েস্ট)
        if (str_contains($expr->structName, '.')) {
            $parts = explode('.', $expr->structName);
            $target = $this->environment->get($parts[0]);
            for ($i = 1; $i < count($parts); $i++) {
                if (is_array($target)) {
                    $target = $target[$parts[$i]] ?? null;
                } elseif ($target instanceof LipiStructInstance) {
                    $target = $target->get($parts[$i]);
                } else {
                    $target = null;
                }
            }
            $blueprint = $target;
        } else {
            $blueprint = $this->environment->get($expr->structName);
        }

        if (!$blueprint instanceof LipiStructBlueprint) {
            throw new RuntimeException("'{$expr->structName}' কোনো গঠন (struct) নয় at line {$expr->line}");
        }
        $args = [];
        foreach ($expr->arguments as $argExpr) {
            $args[] = $this->evaluate($argExpr);
        }
        $namedArgs = [];
        foreach ($expr->namedArguments as $key => $argExpr) {
            $namedArgs[$key] = $this->evaluate($argExpr);
        }
        return $blueprint->instantiate($this, $args, $namedArgs);
    }

    private function evaluateSpawn(SpawnExpr $expr): LipiFiberHandle
    {
        $targetExpr = $expr->expression;

        if ($targetExpr instanceof FnExpr) {
            $fn = new LipiFunction("<async>", $targetExpr->params, $targetExpr->body, $this->environment);
            return $this->spawnFiber(function () use ($fn) {
                return $fn->call($this, []);
            });
        }

        if ($targetExpr instanceof CallExpr) {
            return $this->spawnFiber(function () use ($targetExpr) {
                return $this->evaluateCall($targetExpr);
            });
        }

        return $this->spawnFiber(function () use ($targetExpr) {
            return $this->evaluate($targetExpr);
        });
    }

    private function evaluateAwait(AwaitExpr $expr): mixed
    {
        $target = $this->evaluate($expr->expression);
        if ($target instanceof LipiFiberHandle) {
            return $target->await($this);
        }
        return $target;
    }

    private function evaluateChannel(ChannelExpr $expr): LipiChannel
    {
        $cap = $expr->capacity !== null ? (int)$this->evaluate($expr->capacity) : 0;
        return new LipiChannel($cap);
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

        if ($expr->target instanceof MemberExpr) {
            $obj = $this->evaluate($expr->target->object);
            $prop = $expr->target->property;
            if ($obj instanceof LipiStructInstance) {
                $obj->set($prop, $val);
                return $val;
            }
            if (is_array($obj)) {
                $obj[$prop] = $val;
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
        if ($expr->operator === '&&' || $expr->operator === 'and' || $expr->operator === 'এবং' || $expr->operator === LipiToken::TYPE_AND) {
            return $this->isTruthy($left) ? $this->evaluate($expr->right) : $left;
        }
        if ($expr->operator === '||' || $expr->operator === 'or' || $expr->operator === 'অথবা' || $expr->operator === LipiToken::TYPE_OR) {
            return $this->isTruthy($left) ? $left : $this->evaluate($expr->right);
        }

        $right = $this->evaluate($expr->right);

        return match ($expr->operator) {
            '+' => match (true) {
                is_array($left) && is_array($right) => array_merge($left, $right),
                is_string($left) || is_string($right) => $this->stringify($left) . $this->stringify($right),
                default => $left + $right,
            },
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

        if ($obj instanceof LipiStructInstance) {
            return $obj->get($prop);
        }

        if ($obj instanceof LipiChannel) {
            return match ($prop) {
                'পাঠাও', 'send', 'push' => new class($obj, $this) implements LipiCallable {
                    public function __construct(private LipiChannel $chan, private LipiRuntime $rt) {}
                    public function arity(): int { return 1; }
                    public function call(LipiRuntime $runtime, array $arguments): mixed {
                        $this->chan->send($arguments[0] ?? null, $this->rt);
                        return null;
                    }
                },
                'গ্রহণ', 'receive', 'pop' => new class($obj, $this) implements LipiCallable {
                    public function __construct(private LipiChannel $chan, private LipiRuntime $rt) {}
                    public function arity(): int { return 0; }
                    public function call(LipiRuntime $runtime, array $arguments): mixed {
                        return $this->chan->receive($this->rt);
                    }
                },
                'বন্ধ', 'close' => new class($obj) implements LipiCallable {
                    public function __construct(private LipiChannel $chan) {}
                    public function arity(): int { return 0; }
                    public function call(LipiRuntime $runtime, array $arguments): mixed {
                        $this->chan->close();
                        return null;
                    }
                },
                'আকার', 'size', 'length', 'count' => $obj->count(),
                'বন্ধ_কিনা', 'is_closed' => $obj->isClosed(),
                default => null,
            };
        }

        if ($obj instanceof LipiFiberHandle) {
            return match ($prop) {
                'অপেক্ষা', 'await' => new class($obj, $this) implements LipiCallable {
                    public function __construct(private LipiFiberHandle $handle, private LipiRuntime $rt) {}
                    public function arity(): int { return 0; }
                    public function call(LipiRuntime $runtime, array $arguments): mixed {
                        return $this->handle->await($this->rt);
                    }
                },
                'ফলাফল', 'result' => $obj->result,
                'সম্পন্ন', 'is_done' => $obj->completed,
                default => null,
            };
        }

        if (is_array($obj)) {
            return $obj[$prop] ?? null;
        }

        // Built-in string methods & properties
        if (is_string($obj)) {
            return match ($prop) {
                'length', 'দৈর্ঘ্য' => mb_strlen($obj, 'UTF-8'),
                'byte_length', 'বাইট_দৈর্ঘ্য', 'bytes', 'আকার' => strlen($obj),
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
        if ($value instanceof LipiChannel) {
            return 'চ্যানেল(ধারণক্ষমতা: ' . $value->capacity . ', উপাদান: ' . $value->count() . ')';
        }
        if ($value instanceof LipiFiberHandle) {
            return 'ফাইবার(আইডি: ' . $value->id . ', সম্পন্ন: ' . ($value->completed ? 'সত্য' : 'মিথ্যা') . ')';
        }
        if ($value instanceof LipiStructInstance) {
            $pairs = [];
            foreach ($value->toArray() as $k => $v) {
                $pairs[] = $k . ': ' . $this->stringify($v);
            }
            return $value->blueprint->name . ' {' . implode(', ', $pairs) . '}';
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
        // 1. দৈর্ঘ্য / len (UTF-8 character count)
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

        // 1.1 বাইট_দৈর্ঘ্য / byte_length / strlen (Raw byte count for ELF binary synthesis and low-level I/O)
        $byteLenFn = new LipiBuiltinFunction('বাইট_দৈর্ঘ্য', 1, function (LipiRuntime $rt, array $args) {
            $val = $args[0] ?? null;
            if (is_string($val)) {
                return strlen($val);
            }
            if (is_array($val)) {
                return count($val);
            }
            return 0;
        });
        $this->globals->define('বাইট_দৈর্ঘ্য', $byteLenFn, true);
        $this->globals->define('byte_length', $byteLenFn, true);
        $this->globals->define('byte_len', $byteLenFn, true);
        $this->globals->define('strlen', $byteLenFn, true);

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

        // 5.1 আর্গুমেন্ট / args / argv (CLI Arguments passed to the Lipi script)
        // WHY: Essential for pure Lipi self-hosting compiler, CLI programs, and scripts
        $argsFn = new LipiBuiltinFunction('আর্গুমেন্ট', 0, function (LipiRuntime $rt, array $args): array {
            return $rt->getArguments();
        });
        $this->globals->define('আর্গুমেন্ট', $argsFn, true);
        $this->globals->define('args', $argsFn, true);
        $this->globals->define('argv', $argsFn, true);

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
        $store = new SovereignStore();
        $memMap = [
            'set' => new LipiBuiltinFunction('set', 2, fn($rt, $a) => $store->set((string)$a[0], (string)$a[1])),
            'get' => new LipiBuiltinFunction('get', 1, fn($rt, $a) => $store->get((string)$a[0])),
            'delete' => new LipiBuiltinFunction('delete', 1, fn($rt, $a) => $store->delete((string)$a[0])),
        ];
        $this->globals->define('স্মৃতি', $memMap, true);
        $this->globals->define('memory', $memMap, true);

        // 9. রেজিস্টার সম্পূর্ণ স্ট্যান্ডার্ড লাইব্রেরি (Lipi Standard Library Modules)
        LipiStdLib::register($this->globals);
    }
}
