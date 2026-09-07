<?php

declare(strict_types=1);

namespace Unum;

use FFI\CData;

/**
 * 👑 Compiled Bare-Metal Machine Program
 * 
 * WHY: Encapsulates an executable memory page containing native x86_64 machine code.
 * Implements __invoke for zero-overhead direct function calls and automatically manages
 * virtual memory lifecycle (calls munmap on destruction to prevent memory leaks).
 */
final class CompiledProgram
{
    private HardwareExecutor $executor;
    private CData $page;
    private int $pageSize;
    private int $emittedBytes;
    private float $compilationTimeUs;

    public function __construct(
        HardwareExecutor $executor,
        CData $page,
        int $pageSize,
        int $emittedBytes,
        float $compilationTimeUs
    ) {
        $this->executor = $executor;
        $this->page = $page;
        $this->pageSize = $pageSize;
        $this->emittedBytes = $emittedBytes;
        $this->compilationTimeUs = $compilationTimeUs;
    }

    /**
     * Directly executes the compiled machine code via CPU hardware registers.
     */
    public function __invoke(int $arg1 = 0, int $arg2 = 0, int $arg3 = 0): int
    {
        return $this->executor->execute($this->page, $arg1, $arg2, $arg3);
    }

    /**
     * Alias for direct execution.
     */
    public function execute(int $arg1 = 0, int $arg2 = 0, int $arg3 = 0): int
    {
        return $this->__invoke($arg1, $arg2, $arg3);
    }

    /**
     * Executes machine code with dynamic variadic arguments.
     */
    public function executeWithArgs(int ...$args): int
    {
        $a1 = $args[0] ?? 0;
        $a2 = $args[1] ?? 0;
        $a3 = $args[2] ?? 0;
        return $this->__invoke($a1, $a2, $a3);
    }

    public function getEmittedBytes(): int
    {
        return $this->emittedBytes;
    }

    /**
     * Extracts the raw emitted machine code bytes from the executable memory page.
     *
     * WHY: Enables Cross-ISA emitters, disassemblers, and code analyzers to inspect
     * or persist the compiled silicon binary without touching uninitialized memory.
     */
    public function getMachineCode(): string
    {
        return \FFI::string($this->page, $this->emittedBytes);
    }

    public function getCompilationTimeUs(): float
    {
        return $this->compilationTimeUs;
    }

    public function __destruct()
    {
        $this->executor->freePage($this->page, $this->pageSize);
    }
}
