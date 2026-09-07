<?php

declare(strict_types=1);

namespace Unum\CrossIsa;

/**
 * UniversalTarget: Silicon Architecture Detection & Cross-ISA Specification.
 *
 * Provides hardware platform introspection and defines execution targets for
 * the Universal Number bare-metal compiler across x86_64, AArch64 (ARM64), and WASM.
 *
 * @author Shafiullah (Gyani Supreme Core)
 */
final class UniversalTarget
{
    public const TARGET_X86_64  = 'x86_64';
    public const TARGET_ARM64   = 'aarch64';
    public const TARGET_WASM    = 'wasm32';
    public const TARGET_RISCV64 = 'riscv64';

    /**
     * Detects the host machine CPU architecture.
     *
     * WHY: Universal Numbers are ISA-agnostic invariants. By auto-detecting
     * the host CPU, the engine selects the native machine code emitter without
     * requiring manual flags or complex compiler configure scripts.
     */
    public static function detectHost(): string
    {
        $arch = strtolower(php_uname('m'));

        if ($arch === 'x86_64' || $arch === 'amd64') {
            return self::TARGET_X86_64;
        }

        if ($arch === 'aarch64' || $arch === 'arm64') {
            return self::TARGET_ARM64;
        }

        if (str_starts_with($arch, 'riscv64')) {
            return self::TARGET_RISCV64;
        }

        // Fallback default: x86_64
        return self::TARGET_X86_64;
    }

    /**
     * Returns true if the target is natively executable on the current host.
     */
    public static function isHostNative(string $target): bool
    {
        return $target === self::detectHost();
    }

    /**
     * Returns the register count available for the target architecture.
     */
    public static function getGeneralRegisterCount(string $target): int
    {
        return match ($target) {
            self::TARGET_X86_64  => 16, // RAX, RBX, RCX, RDX, RSI, RDI, RBP, RSP, R8-R15
            self::TARGET_ARM64   => 31, // X0-X30
            self::TARGET_RISCV64 => 32, // X0-X31
            self::TARGET_WASM    => 64, // Local variable slots
            default              => 16,
        };
    }

    /**
     * Returns target word size in bits.
     */
    public static function getWordSizeBits(string $target): int
    {
        return match ($target) {
            self::TARGET_WASM => 32,
            default           => 64,
        };
    }
}
