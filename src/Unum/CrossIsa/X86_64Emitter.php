<?php

declare(strict_types=1);

namespace Unum\CrossIsa;

use Unum\UniversalNumber;

/**
 * 👑 X86_64Emitter: Pure-PHP Single-Pass x86_64 Machine Code Binary Emitter.
 *
 * Translates 64-bit Universal Numbers (U ∈ GF(2^64)) directly into native
 * Intel / AMD x86_64 machine code instructions (opcodes, REX prefixes, ModR/M bytes).
 *
 * WHY: Eliminates GCC, Clang, and external C compilers entirely.
 * Emits raw machine instructions directly into memory pages (POSIX mmap PROT_EXEC)
 * or standalone ELF shared objects with ZERO external dependencies.
 *
 * Calling Convention: System V AMD64 ABI
 * - Arguments: RDI (arg1), RSI (arg2), RDX (arg3), RCX (arg4), R8 (arg5), R9 (arg6)
 * - Return Value: RAX
 * - Callee-saved registers: RBX, RBP, R12, R13, R14, R15
 *
 * @author Shafiullah (Gyani Supreme Core)
 */
final class X86_64Emitter
{
    /** @var int[] Raw emitted byte stream */
    private array $bytes = [];

    /** @var string[] Human-readable disassembly instructions */
    private array $disassembly = [];

    /** @var int Byte offset of the last loop start instruction */
    private int $loopStartOffset = 0;

    /**
     * Standard register names in System V AMD64 ABI (indices 0..15).
     */
    private const REG_NAMES = [
        0  => 'RAX', 1  => 'RCX', 2  => 'RDX', 3  => 'RBX',
        4  => 'RSP', 5  => 'RBP', 6  => 'RSI', 7  => 'RDI',
        8  => 'R8',  9  => 'R9',  10 => 'R10', 11 => 'R11',
        12 => 'R12', 13 => 'R13', 14 => 'R14', 15 => 'R15',
    ];

    public function __construct()
    {
        $this->reset();
    }

    /**
     * Resets internal emitter state.
     */
    public function reset(): self
    {
        $this->bytes = [];
        $this->disassembly = [];
        $this->loopStartOffset = 0;
        return $this;
    }

    /**
     * Translates an array of Universal Numbers into raw binary x86_64 machine code.
     *
     * @param UniversalNumber[] $unums
     * @return string Raw machine code binary bytes
     */
    public function emitUnums(array $unums): string
    {
        $this->reset();

        // 1. Emit System V AMD64 ABI Function Prologue
        $this->emitPrologue();

        // 2. Translate Universal Numbers directly into x86_64 instructions
        foreach ($unums as $unum) {
            $opcode = $unum->getOpcode();
            $dstReg = $unum->getRegDest();
            $srcReg = $unum->getRegSrc();
            $payload = $unum->getPayload();

            switch ($opcode) {
                case UniversalNumber::OP_NOP:
                    $this->emitByte(0x90);
                    $this->disassembly[] = "NOP";
                    break;

                case UniversalNumber::OP_MOV_IMM:
                    // mov r_dest, imm32 (sign-extended 64-bit)
                    $rex = $this->makeRex(true, 0, $dstReg);
                    $this->emitByte($rex);
                    $this->emitByte(0xC7);
                    $this->emitByte(0xC0 | ($dstReg & 7));
                    $this->emitInt32($payload);
                    $this->disassembly[] = sprintf("MOV %s, #%d", self::REG_NAMES[$dstReg] ?? "R{$dstReg}", $payload);
                    break;

                case UniversalNumber::OP_MOV_REG:
                    // mov r_dest, r_src
                    $rex = $this->makeRex(true, $srcReg, $dstReg);
                    $this->emitByte($rex);
                    $this->emitByte(0x89);
                    $this->emitByte($this->makeModRm($srcReg, $dstReg));
                    $this->disassembly[] = sprintf("MOV %s, %s", self::REG_NAMES[$dstReg] ?? "R{$dstReg}", self::REG_NAMES[$srcReg] ?? "R{$srcReg}");
                    break;

                case UniversalNumber::OP_ADD_IMM:
                    // add r_dest, imm32
                    $rex = $this->makeRex(true, 0, $dstReg);
                    $this->emitByte($rex);
                    $this->emitByte(0x81);
                    $this->emitByte(0xC0 | ($dstReg & 7));
                    $this->emitInt32($payload);
                    $this->disassembly[] = sprintf("ADD %s, #%d", self::REG_NAMES[$dstReg] ?? "R{$dstReg}", $payload);
                    break;

                case UniversalNumber::OP_ADD_REG:
                    // add r_dest, r_src
                    $rex = $this->makeRex(true, $srcReg, $dstReg);
                    $this->emitByte($rex);
                    $this->emitByte(0x01);
                    $this->emitByte($this->makeModRm($srcReg, $dstReg));
                    $this->disassembly[] = sprintf("ADD %s, %s", self::REG_NAMES[$dstReg] ?? "R{$dstReg}", self::REG_NAMES[$srcReg] ?? "R{$srcReg}");
                    break;

                case UniversalNumber::OP_SUB_IMM:
                    // sub r_dest, imm32
                    $rex = $this->makeRex(true, 5, $dstReg);
                    $this->emitByte($rex);
                    $this->emitByte(0x81);
                    $this->emitByte(0xE8 | ($dstReg & 7));
                    $this->emitInt32($payload);
                    $this->disassembly[] = sprintf("SUB %s, #%d", self::REG_NAMES[$dstReg] ?? "R{$dstReg}", $payload);
                    break;

                case UniversalNumber::OP_SUB_REG:
                    // sub r_dest, r_src
                    $rex = $this->makeRex(true, $srcReg, $dstReg);
                    $this->emitByte($rex);
                    $this->emitByte(0x29);
                    $this->emitByte($this->makeModRm($srcReg, $dstReg));
                    $this->disassembly[] = sprintf("SUB %s, %s", self::REG_NAMES[$dstReg] ?? "R{$dstReg}", self::REG_NAMES[$srcReg] ?? "R{$srcReg}");
                    break;

                case UniversalNumber::OP_MUL_REG:
                    // imul r_dest, r_src
                    $rex = $this->makeRex(true, $dstReg, $srcReg);
                    $this->emitByte($rex);
                    $this->emitByte(0x0F);
                    $this->emitByte(0xAF);
                    $this->emitByte($this->makeModRm($dstReg, $srcReg));
                    $this->disassembly[] = sprintf("IMUL %s, %s", self::REG_NAMES[$dstReg] ?? "R{$dstReg}", self::REG_NAMES[$srcReg] ?? "R{$srcReg}");
                    break;

                case UniversalNumber::OP_XOR_REG:
                    // xor r_dest, r_src
                    $rex = $this->makeRex(true, $srcReg, $dstReg);
                    $this->emitByte($rex);
                    $this->emitByte(0x31);
                    $this->emitByte($this->makeModRm($srcReg, $dstReg));
                    $this->disassembly[] = sprintf("XOR %s, %s", self::REG_NAMES[$dstReg] ?? "R{$dstReg}", self::REG_NAMES[$srcReg] ?? "R{$srcReg}");
                    break;

                case UniversalNumber::OP_LOOP_START:
                    // Mark beginning of loop body for hardware backward jump
                    $this->loopStartOffset = count($this->bytes);
                    $this->disassembly[] = "LOOP_START:";
                    break;

                case UniversalNumber::OP_LOOP_DEC:
                    // dec r_dest (counter)
                    $rex = $this->makeRex(true, 0, $dstReg);
                    $this->emitByte($rex);
                    $this->emitByte(0xFF);
                    $this->emitByte(0xC8 | ($dstReg & 7));

                    // jnz loop_start
                    $currPos = count($this->bytes);
                    $relJump = $this->loopStartOffset - ($currPos + 2);

                    if ($relJump >= -128 && $relJump <= 127) {
                        $this->emitByte(0x75); // JNZ rel8
                        $this->emitByte($relJump & 0xFF);
                        $this->disassembly[] = sprintf("DEC %s; JNZ rel8 (%d)", self::REG_NAMES[$dstReg] ?? "R{$dstReg}", $relJump);
                    } else {
                        $relJump = $this->loopStartOffset - ($currPos + 6);
                        $this->emitByte(0x0F);
                        $this->emitByte(0x85); // JNZ rel32
                        $this->emitInt32($relJump);
                        $this->disassembly[] = sprintf("DEC %s; JNZ rel32 (%d)", self::REG_NAMES[$dstReg] ?? "R{$dstReg}", $relJump);
                    }
                    break;

                case UniversalNumber::OP_RET:
                case UniversalNumber::OP_HALT:
                    $this->emitEpilogue();
                    return $this->getBinary();

                default:
                    // Pass-through unrecognized opcodes as NOP
                    $this->emitByte(0x90);
                    break;
            }
        }

        // 3. Emit Function Epilogue
        $this->emitEpilogue();

        return $this->getBinary();
    }

    /**
     * Emits System V AMD64 ABI function prologue.
     * Preserves RBP and callee-saved registers: RBX, R12, R13, R14, R15.
     */
    private function emitPrologue(): void
    {
        $this->emitByte(0x55);                         // push rbp
        $this->emitByte(0x48); $this->emitByte(0x89); $this->emitByte(0xE5); // mov rbp, rsp
        $this->emitByte(0x53);                         // push rbx
        $this->emitByte(0x41); $this->emitByte(0x54); // push r12
        $this->emitByte(0x41); $this->emitByte(0x55); // push r13
        $this->emitByte(0x41); $this->emitByte(0x56); // push r14
        $this->emitByte(0x41); $this->emitByte(0x57); // push r15

        $this->disassembly[] = "PUSH RBP; MOV RBP, RSP; PUSH RBX; PUSH R12-R15";
    }

    /**
     * Emits System V AMD64 ABI function epilogue.
     * Restores callee-saved registers in reverse order and returns RAX.
     */
    private function emitEpilogue(): void
    {
        $this->emitByte(0x41); $this->emitByte(0x5F); // pop r15
        $this->emitByte(0x41); $this->emitByte(0x5E); // pop r14
        $this->emitByte(0x41); $this->emitByte(0x5D); // pop r13
        $this->emitByte(0x41); $this->emitByte(0x5C); // pop r12
        $this->emitByte(0x5B);                         // pop rbx
        $this->emitByte(0x5D);                         // pop rbp
        $this->emitByte(0xC3);                         // ret

        $this->disassembly[] = "POP R15-R12; POP RBX; POP RBP; RET";
    }

    /**
     * Helper to compute x86_64 REX prefix byte.
     */
    private function makeRex(bool $is64bit, int $reg, int $rm): int
    {
        $rex = 0x40;
        if ($is64bit)   $rex |= 0x08; // REX.W (64-bit operand)
        if ($reg >= 8)   $rex |= 0x04; // REX.R (extension of ModR/M reg field)
        if ($rm >= 8)    $rex |= 0x01; // REX.B (extension of ModR/M r/m field)
        return ($rex === 0x40 && !$is64bit) ? 0 : $rex;
    }

    /**
     * Helper to compute ModR/M byte for register-to-register operation.
     */
    private function makeModRm(int $reg, int $rm): int
    {
        return 0xC0 | (($reg & 7) << 3) | ($rm & 7);
    }

    private function emitByte(int $byte): void
    {
        $this->bytes[] = $byte & 0xFF;
    }

    private function emitInt32(int $val): void
    {
        $this->bytes[] = $val & 0xFF;
        $this->bytes[] = ($val >> 8) & 0xFF;
        $this->bytes[] = ($val >> 16) & 0xFF;
        $this->bytes[] = ($val >> 24) & 0xFF;
    }

    /**
     * Returns raw machine code binary string.
     */
    public function getBinary(): string
    {
        return pack('C*', ...$this->bytes);
    }

    /**
     * Returns human-readable disassembly instruction list.
     *
     * @return string[]
     */
    public function disassemble(): array
    {
        return $this->disassembly;
    }

    /**
     * Returns total emitted bytes count.
     */
    public function getByteCount(): int
    {
        return count($this->bytes);
    }
}
