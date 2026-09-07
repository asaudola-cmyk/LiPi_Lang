<?php

declare(strict_types=1);

namespace Unum\CrossIsa;

use Unum\UniversalNumber;

/**
 * WasmEmitter: Single-Pass WebAssembly (WASM) Binary Module Emitter.
 *
 * Translates 64-bit Universal Numbers (U ∈ GF(2^64)) directly into standard
 * binary WebAssembly (WASM v1.0 MVP) bytecode executable in any modern web browser,
 * Node.js, Cloudflare Workers, or serverless edge runtime.
 *
 * Conforms to W3C WebAssembly Core Binary Specification (Magic: \0asm, Version 1).
 *
 * @author Shafiullah (Gyani Supreme Core)
 */
final class WasmEmitter
{
    private const WASM_MAGIC = "\x00\x61\x73\x6D"; // \0asm
    private const WASM_VERSION = "\x01\x00\x00\x00"; // version 1

    // Section IDs
    private const SEC_TYPE     = 1;
    private const SEC_FUNCTION = 3;
    private const SEC_EXPORT   = 7;
    private const SEC_CODE     = 10;

    // Type tags
    public const TYPE_I32  = 0x7F;
    public const TYPE_I64  = 0x7E;
    public const TYPE_F32  = 0x7D;
    public const TYPE_F64  = 0x7C;
    public const TYPE_V128 = 0x7B; // SIMD

    // Opcodes
    public const OP_BLOCK     = 0x02;
    public const OP_LOOP      = 0x03;
    public const OP_BR        = 0x0C;
    public const OP_BR_IF     = 0x0D;
    public const OP_RETURN    = 0x0F;
    public const OP_END       = 0x0B;
    public const OP_LOCAL_GET = 0x20;
    public const OP_LOCAL_SET = 0x21;
    public const OP_I64_CONST = 0x42;
    public const OP_I64_ADD   = 0x7C;
    public const OP_I64_SUB   = 0x7D;
    public const OP_I64_MUL   = 0x7E;
    public const OP_I64_DIV_S = 0x7F;

    /** @var string Instruction bytecode buffer */
    private string $codeBuffer = '';

    public function __construct()
    {
        $this->codeBuffer = '';
    }

    /**
     * Translates an array of Universal Numbers into a complete, valid WASM binary module.
     *
     * @param UniversalNumber[] $unums
     * @param string $functionName The name exported to the host runtime
     */
    public function emitModule(array $unums, string $functionName = 'unum_exec'): string
    {
        $this->codeBuffer = '';

        // Initial setup: accumulate in local 0 (representing RAX/X0)
        $this->codeBuffer .= chr(self::OP_I64_CONST) . self::encodeSignedLeb128(0);
        $this->codeBuffer .= chr(self::OP_LOCAL_SET) . self::encodeUnsignedLeb128(0);

        foreach ($unums as $unum) {
            $opcode = $unum->getOpcode();
            $payload= $unum->getPayload();

            match ($opcode) {
                UniversalNumber::OP_MOV_IMM => $this->emitConst($payload),
                UniversalNumber::OP_ADD_IMM => $this->emitBinaryOp(self::OP_I64_ADD, $payload),
                UniversalNumber::OP_SUB_IMM => $this->emitBinaryOp(self::OP_I64_SUB, $payload),
                UniversalNumber::OP_RET     => $this->emitReturn(),
                default                     => null,
            };
        }

        // Push local 0 onto the stack as the function return value
        $this->codeBuffer .= chr(self::OP_LOCAL_GET) . self::encodeUnsignedLeb128(0);
        $this->codeBuffer .= chr(self::OP_END); // Function body end

        return $this->packModule($functionName);
    }

    private function emitConst(int $val): void
    {
        $this->codeBuffer .= chr(self::OP_I64_CONST) . self::encodeSignedLeb128($val);
        $this->codeBuffer .= chr(self::OP_LOCAL_SET) . self::encodeUnsignedLeb128(0);
    }

    private function emitBinaryOp(int $wasmOp, int $payload): void
    {
        // Stack: [local0, payload] -> op -> local0
        $this->codeBuffer .= chr(self::OP_LOCAL_GET) . self::encodeUnsignedLeb128(0);
        $this->codeBuffer .= chr(self::OP_I64_CONST) . self::encodeSignedLeb128($payload);
        $this->codeBuffer .= chr($wasmOp);
        $this->codeBuffer .= chr(self::OP_LOCAL_SET) . self::encodeUnsignedLeb128(0);
    }

    private function emitReturn(): void
    {
        $this->codeBuffer .= chr(self::OP_LOCAL_GET) . self::encodeUnsignedLeb128(0);
        $this->codeBuffer .= chr(self::OP_RETURN);
    }

    /**
     * Packs sections into standard W3C WebAssembly binary container.
     */
    private function packModule(string $exportName): string
    {
        // 1. Type Section: 1 signature () -> i64
        // 0x60, param_count=0, return_count=1, return_type=i64 (0x7E)
        $typeContent = self::encodeUnsignedLeb128(1) // 1 type
            . chr(0x60)                              // func form
            . chr(0x00)                              // 0 params
            . chr(0x01)                              // 1 return
            . chr(self::TYPE_I64);                   // i64
        $typeSection = chr(self::SEC_TYPE) . self::encodeUnsignedLeb128(strlen($typeContent)) . $typeContent;

        // 2. Function Section: func 0 uses type 0
        $funcContent = self::encodeUnsignedLeb128(1) . self::encodeUnsignedLeb128(0);
        $funcSection = chr(self::SEC_FUNCTION) . self::encodeUnsignedLeb128(strlen($funcContent)) . $funcContent;

        // 3. Export Section: export $exportName as func 0
        $nameBytes = $exportName;
        $exportContent = self::encodeUnsignedLeb128(1)                       // 1 export
            . self::encodeUnsignedLeb128(strlen($nameBytes)) . $nameBytes     // export name
            . chr(0x00)                                                      // export kind: function
            . self::encodeUnsignedLeb128(0);                                 // func index 0
        $exportSection = chr(self::SEC_EXPORT) . self::encodeUnsignedLeb128(strlen($exportContent)) . $exportContent;

        // 4. Code Section: 1 function body
        // Local declarations: 1 local entry with 1 local of type i64
        $locals = self::encodeUnsignedLeb128(1)   // 1 local group
            . self::encodeUnsignedLeb128(1)       // count = 1
            . chr(self::TYPE_I64);                // type = i64
        $funcBody = $locals . $this->codeBuffer;
        $codeContent = self::encodeUnsignedLeb128(1) // 1 function
            . self::encodeUnsignedLeb128(strlen($funcBody)) . $funcBody;
        $codeSection = chr(self::SEC_CODE) . self::encodeUnsignedLeb128(strlen($codeContent)) . $codeContent;

        return self::WASM_MAGIC . self::WASM_VERSION . $typeSection . $funcSection . $exportSection . $codeSection;
    }

    // -------------------------------------------------------------------------
    // LEB128 (Little-Endian Base 128) Variable-Length Integer Encoding
    // -------------------------------------------------------------------------

    public static function encodeUnsignedLeb128(int $value): string
    {
        $out = '';
        $val = $value;
        do {
            $byte = $val & 0x7F;
            $val >>= 7;
            if ($val !== 0) {
                $byte |= 0x80;
            }
            $out .= chr($byte);
        } while ($val !== 0);

        return $out;
    }

    public static function encodeSignedLeb128(int $value): string
    {
        $out = '';
        $val = $value;
        $more = true;

        while ($more) {
            $byte = $val & 0x7F;
            $val >>= 7;

            // Sign bit of byte is second high order bit (0x40)
            if (($val === 0 && ($byte & 0x40) === 0) || ($val === -1 && ($byte & 0x40) !== 0)) {
                $more = false;
            } else {
                $byte |= 0x80;
            }
            $out .= chr($byte);
        }

        return $out;
    }
}
