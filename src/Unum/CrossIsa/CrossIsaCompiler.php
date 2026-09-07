<?php

declare(strict_types=1);

namespace Unum\CrossIsa;

use Unum\Compiler;
use Unum\UniversalNumber;

/**
 * CrossIsaCompiler: Universal Multi-Target Silicon Compiler Pipeline.
 *
 * Emits identical mathematical logic from Universal Numbers into:
 * 1. x86_64 machine code (Intel / AMD / PC)
 * 2. AArch64 / ARM64 machine code (Apple Silicon M1-M4, AWS Graviton, Raspberry Pi)
 * 3. WebAssembly WASM binary module (Browsers, Node.js, Cloudflare Workers)
 *
 * @author Shafiullah (Gyani Supreme Core)
 */
final class CrossIsaCompiler
{
    private X86_64Emitter $x86_64Emitter;
    private Arm64Emitter $arm64Emitter;
    private WasmEmitter $wasmEmitter;

    public function __construct()
    {
        $this->x86_64Emitter = new X86_64Emitter();
        $this->arm64Emitter  = new Arm64Emitter();
        $this->wasmEmitter   = new WasmEmitter();
    }

    /**
     * Compiles Universal Numbers to the requested ISA target.
     *
     * @param UniversalNumber[] $unums
     * @return array{target: string, bytes: int, binary: string, disassembly?: string[]}
     */
    public function compileToTarget(array $unums, string $target): array
    {
        return match ($target) {
            UniversalTarget::TARGET_X86_64 => $this->compileX86_64($unums),
            UniversalTarget::TARGET_ARM64  => $this->compileArm64($unums),
            UniversalTarget::TARGET_WASM   => $this->compileWasm($unums),
            default => throw new \InvalidArgumentException("Unsupported Cross-ISA target: '{$target}'"),
        };
    }

    /**
     * Compiles to ARM64 / AArch64.
     *
     * @param UniversalNumber[] $unums
     * @return array{target: string, bytes: int, binary: string, disassembly: string[]}
     */
    public function compileArm64(array $unums): array
    {
        $binary = $this->arm64Emitter->emitUnums($unums);
        $disasm = $this->arm64Emitter->disassemble();

        return [
            'target'      => UniversalTarget::TARGET_ARM64,
            'bytes'       => strlen($binary),
            'binary'      => $binary,
            'disassembly' => $disasm,
        ];
    }

    /**
     * Compiles to WebAssembly WASM.
     *
     * @param UniversalNumber[] $unums
     * @return array{target: string, bytes: int, binary: string}
     */
    public function compileWasm(array $unums, string $funcName = 'unum_exec'): array
    {
        $binary = $this->wasmEmitter->emitModule($unums, $funcName);

        return [
            'target' => UniversalTarget::TARGET_WASM,
            'bytes'  => strlen($binary),
            'binary' => $binary,
        ];
    }

    /**
     * Compiles to x86_64.
     *
     * @param UniversalNumber[] $unums
     * @return array{target: string, bytes: int, binary: string, disassembly: string[]}
     */
    public function compileX86_64(array $unums): array
    {
        $binary = $this->x86_64Emitter->emitUnums($unums);
        $disasm = $this->x86_64Emitter->disassemble();

        return [
            'target'      => UniversalTarget::TARGET_X86_64,
            'bytes'       => strlen($binary),
            'binary'      => $binary,
            'disassembly' => $disasm,
        ];
    }

    /**
     * Compiles across ALL three architectures simultaneously to verify cross-ISA invariance.
     *
     * @param UniversalNumber[] $unums
     * @return array<string, array{target: string, bytes: int, binary: string}>
     */
    public function compileAllTargets(array $unums): array
    {
        return [
            UniversalTarget::TARGET_X86_64 => $this->compileX86_64($unums),
            UniversalTarget::TARGET_ARM64  => $this->compileArm64($unums),
            UniversalTarget::TARGET_WASM   => $this->compileWasm($unums),
        ];
    }
}
