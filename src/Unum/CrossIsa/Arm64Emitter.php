<?php

declare(strict_types=1);

namespace Unum\CrossIsa;

use Unum\UniversalNumber;

/**
 * Arm64Emitter: Single-Pass AArch64 (ARM64) Machine Code Binary Emitter.
 *
 * Translates 64-bit Universal Numbers (U ∈ GF(2^64)) directly into native
 * 32-bit AArch64 machine instructions for Apple Silicon (M1-M4), AWS Graviton,
 * and ARM Cortex-A servers.
 *
 * All instructions in AArch64 are exactly 32 bits wide, encoded in little-endian.
 *
 * @author Shafiullah (Gyani Supreme Core)
 */
final class Arm64Emitter
{
    /** @var array<int, int> Raw 32-bit instruction words */
    private array $words = [];

    /** @var array<string, int> Label name -> instruction index */
    private array $labels = [];

    /** @var array<int, array{label: string, is_cond: bool, cond: int}> Unresolved branch references */
    private array $fixups = [];

    public function __construct()
    {
        $this->words = [];
        $this->labels = [];
        $this->fixups = [];
    }

    /**
     * Resets the emitter state for a fresh function compilation.
     */
    public function reset(): self
    {
        $this->words = [];
        $this->labels = [];
        $this->fixups = [];
        return $this;
    }

    /**
     * Translates an array of Universal Numbers into AArch64 machine code.
     *
     * @param UniversalNumber[] $unums
     */
    public function emitUnums(array $unums): string
    {
        $this->reset();

        foreach ($unums as $unum) {
            $opcode = $unum->getOpcode();
            $dstReg = $unum->getRegDest();
            $srcReg = $unum->getRegSrc();
            $payload= $unum->getPayload();

            match ($opcode) {
                UniversalNumber::OP_MOV_IMM => $this->emitMov64($dstReg, $payload),
                UniversalNumber::OP_MOV_REG => $this->emitAdd($dstReg, $srcReg, 31), // ADD Xd, Xn, XZR -> MOV
                UniversalNumber::OP_ADD_IMM => (function() use ($dstReg, $payload) {
                    $this->emitMov64(9, $payload); // Scratch X9
                    $this->emitAdd($dstReg, $dstReg, 9);
                })(),
                UniversalNumber::OP_ADD_REG => $this->emitAdd($dstReg, $dstReg, $srcReg),
                UniversalNumber::OP_SUB_IMM => (function() use ($dstReg, $payload) {
                    $this->emitMov64(9, $payload);
                    $this->emitSub($dstReg, $dstReg, 9);
                })(),
                UniversalNumber::OP_SUB_REG => $this->emitSub($dstReg, $dstReg, $srcReg),
                UniversalNumber::OP_MUL_REG => $this->emitMul($dstReg, $dstReg, $srcReg),
                UniversalNumber::OP_RET => $this->emitRet(),
                UniversalNumber::OP_LOOP_START => $this->bindLabel("loop_start"),
                UniversalNumber::OP_LOOP_DEC => $this->emitLoopDecAndBranch($dstReg, "loop_start"),
                default => $this->emitNop(),
            };
        }

        return $this->buildBinary();
    }

    // -------------------------------------------------------------------------
    // AArch64 Standard Core Instructions
    // -------------------------------------------------------------------------

    /**
     * ADD Xd, Xn, Xm (64-bit Register-register addition)
     * Binary encoding: 0x8b000000 | (Rm << 16) | (Rn << 5) | Rd
     */
    public function emitAdd(int $rd, int $rn, int $rm): self
    {
        $this->emitWord(0x8b000000 | (($rm & 0x1F) << 16) | (($rn & 0x1F) << 5) | ($rd & 0x1F));
        return $this;
    }

    /**
     * SUB Xd, Xn, Xm (64-bit Register-register subtraction)
     * Binary encoding: 0xcb000000 | (Rm << 16) | (Rn << 5) | Rd
     */
    public function emitSub(int $rd, int $rn, int $rm): self
    {
        $this->emitWord(0xcb000000 | (($rm & 0x1F) << 16) | (($rn & 0x1F) << 5) | ($rd & 0x1F));
        return $this;
    }

    /**
     * MUL Xd, Xn, Xm (Alias for MADD Xd, Xn, Xm, XZR)
     * Binary encoding: 0x9b007c00 | (Rm << 16) | (Rn << 5) | Rd
     */
    public function emitMul(int $rd, int $rn, int $rm): self
    {
        $this->emitWord(0x9b007c00 | (($rm & 0x1F) << 16) | (($rn & 0x1F) << 5) | ($rd & 0x1F));
        return $this;
    }

    /**
     * SDIV Xd, Xn, Xm (64-bit Signed integer division)
     * Binary encoding: 0x9ac00c00 | (Rm << 16) | (Rn << 5) | Rd
     */
    public function emitSdiv(int $rd, int $rn, int $rm): self
    {
        $this->emitWord(0x9ac00c00 | (($rm & 0x1F) << 16) | (($rn & 0x1F) << 5) | ($rd & 0x1F));
        return $this;
    }

    /**
     * Emits a 64-bit immediate constant load using MOVZ + MOVK instructions.
     *
     * WHY: AArch64 cannot load an arbitrary 64-bit constant in a single instruction
     * due to the 32-bit fixed instruction width. We decompose the 64-bit value into
     * 16-bit chunks using MOVZ (Move with Zero) and MOVK (Move with Keep).
     */
    public function emitMov64(int $rd, int $val): self
    {
        $uval = $val;
        $chunk0 = $uval & 0xFFFF;
        $chunk1 = ($uval >> 16) & 0xFFFF;
        $chunk2 = ($uval >> 32) & 0xFFFF;
        $chunk3 = ($uval >> 48) & 0xFFFF;

        // First chunk with MOVZ
        // 0xd2800000 | (hw << 21) | (imm16 << 5) | Rd
        $this->emitWord(0xd2800000 | ($chunk0 << 5) | ($rd & 0x1F));

        if ($chunk1 !== 0) {
            // MOVK hw=1
            $this->emitWord(0xf2800000 | (1 << 21) | ($chunk1 << 5) | ($rd & 0x1F));
        }
        if ($chunk2 !== 0) {
            // MOVK hw=2
            $this->emitWord(0xf2800000 | (2 << 21) | ($chunk2 << 5) | ($rd & 0x1F));
        }
        if ($chunk3 !== 0) {
            // MOVK hw=3
            $this->emitWord(0xf2800000 | (3 << 21) | ($chunk3 << 5) | ($rd & 0x1F));
        }

        return $this;
    }

    /**
     * RET (Return from subroutine using link register X30)
     * Binary encoding: 0xd65f03c0
     */
    public function emitRet(int $rn = 30): self
    {
        $this->emitWord(0xd65f0000 | (($rn & 0x1F) << 5));
        return $this;
    }

    /**
     * NOP (No operation)
     * Binary encoding: 0xd503201f
     */
    public function emitNop(): self
    {
        $this->emitWord(0xd503201f);
        return $this;
    }

    // -------------------------------------------------------------------------
    // Control Flow & Branching
    // -------------------------------------------------------------------------

    public function bindLabel(string $name): self
    {
        $this->labels[$name] = count($this->words);
        return $this;
    }

    /**
     * Decrements a register and conditionally branches if Not Equal to Zero.
     * Implements SUBS Xd, Xd, #1 followed by B.NE target
     */
    public function emitLoopDecAndBranch(int $reg, string $targetLabel): self
    {
        // SUBS Xd, Xd, #1 (immediate=1)
        // 0xf1000000 | (imm12 << 10) | (Rn << 5) | Rd
        $this->emitWord(0xf1000400 | (($reg & 0x1F) << 5) | ($reg & 0x1F));

        // B.NE target
        // B.cond: 0x54000000 | (imm19 << 5) | cond (NE is 0x1)
        $idx = count($this->words);
        $this->fixups[$idx] = ['label' => $targetLabel, 'is_cond' => true, 'cond' => 0x1];
        $this->emitWord(0x54000001);

        return $this;
    }

    // -------------------------------------------------------------------------
    // ARM NEON Vector Instructions (Single Instruction Multiple Data)
    // -------------------------------------------------------------------------

    /**
     * FADD Vd.4S, Vn.4S, Vm.4S (4x 32-bit Float vector addition)
     * Binary encoding: 0x4e20d400 | (Vm << 16) | (Vn << 5) | Vd
     */
    public function emitNeonFadd4s(int $vd, int $vn, int $vm): self
    {
        $this->emitWord(0x4e20d400 | (($vm & 0x1F) << 16) | (($vn & 0x1F) << 5) | ($vd & 0x1F));
        return $this;
    }

    /**
     * FMUL Vd.4S, Vn.4S, Vm.4S (4x 32-bit Float vector multiplication)
     * Binary encoding: 0x4e20dc00 | (Vm << 16) | (Vn << 5) | Vd
     */
    public function emitNeonFmul4s(int $vd, int $vn, int $vm): self
    {
        $this->emitWord(0x4e20dc00 | (($vm & 0x1F) << 16) | (($vn & 0x1F) << 5) | ($vd & 0x1F));
        return $this;
    }

    /**
     * FMLA Vd.4S, Vn.4S, Vm.4S (Fused Multiply-Accumulate: Vd += Vn * Vm)
     * Binary encoding: 0x4e20cc00 | (Vm << 16) | (Vn << 5) | Vd
     */
    public function emitNeonFmla4s(int $vd, int $vn, int $vm): self
    {
        $this->emitWord(0x4e20cc00 | (($vm & 0x1F) << 16) | (($vn & 0x1F) << 5) | ($vd & 0x1F));
        return $this;
    }

    // -------------------------------------------------------------------------
    // Internal Binary Assembler & Linker
    // -------------------------------------------------------------------------

    private function emitWord(int $word): void
    {
        $this->words[] = $word & 0xFFFFFFFF;
    }

    /**
     * Resolves labels and packs instructions into little-endian binary stream.
     */
    public function buildBinary(): string
    {
        // Resolve branch targets
        foreach ($this->fixups as $idx => $fixup) {
            $labelName = $fixup['label'];
            if (!isset($this->labels[$labelName])) {
                throw new \RuntimeException("Undefined ARM64 branch label: '{$labelName}'");
            }

            $targetIdx = $this->labels[$labelName];
            $diff = $targetIdx - $idx; // PC-relative branch offset in instructions

            if ($fixup['is_cond']) {
                // 19-bit signed immediate
                $imm19 = $diff & 0x7FFFF;
                $this->words[$idx] = 0x54000000 | ($imm19 << 5) | ($fixup['cond'] & 0xF);
            } else {
                // 26-bit signed immediate
                $imm26 = $diff & 0x3FFFFFF;
                $this->words[$idx] = 0x14000000 | $imm26;
            }
        }

        $binary = '';
        foreach ($this->words as $w) {
            $binary .= pack('V', $w); // 32-bit unsigned little-endian
        }

        return $binary;
    }

    /**
     * Returns an array of formatted assembly strings for forensic verification.
     *
     * @return string[]
     */
    public function disassemble(): array
    {
        $asm = [];
        foreach ($this->words as $i => $w) {
            $hex = sprintf("%08X", $w);
            $mnemonic = match ($w) {
                0xd65f03c0 => "RET",
                0xd503201f => "NOP",
                default => (function(int $inst) {
                    if (($inst & 0xFFE00000) === 0x8B000000) {
                        $rd = $inst & 0x1F;
                        $rn = ($inst >> 5) & 0x1F;
                        $rm = ($inst >> 16) & 0x1F;
                        return "ADD X{$rd}, X{$rn}, X{$rm}";
                    }
                    if (($inst & 0xFFE00000) === 0xCB000000) {
                        $rd = $inst & 0x1F;
                        $rn = ($inst >> 5) & 0x1F;
                        $rm = ($inst >> 16) & 0x1F;
                        return "SUB X{$rd}, X{$rn}, X{$rm}";
                    }
                    if (($inst & 0xFFE07C00) === 0x9B007C00) {
                        $rd = $inst & 0x1F;
                        $rn = ($inst >> 5) & 0x1F;
                        $rm = ($inst >> 16) & 0x1F;
                        return "MUL X{$rd}, X{$rn}, X{$rm}";
                    }
                    if (($inst & 0xFF800000) === 0xD2800000) {
                        $rd = $inst & 0x1F;
                        $imm16 = ($inst >> 5) & 0xFFFF;
                        return "MOVZ X{$rd}, #{$imm16}";
                    }
                    if (($inst & 0xFFE00000) === 0x4E20CC00) {
                        $vd = $inst & 0x1F;
                        $vn = ($inst >> 5) & 0x1F;
                        $vm = ($inst >> 16) & 0x1F;
                        return "FMLA V{$vd}.4S, V{$vn}.4S, V{$vm}.4S";
                    }
                    return "WORD 0x" . sprintf("%08X", $inst);
                })($w),
            };

            $asm[] = sprintf("[%04X] %s  %s", $i * 4, $hex, $mnemonic);
        }

        return $asm;
    }
}
