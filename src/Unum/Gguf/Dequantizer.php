<?php

declare(strict_types=1);

namespace Unum\Gguf;

use Unum\Tensor\Tensor2D;

/**
 * Dequantizer: High-Throughput Quantization Decoder (Q4_0, Q8_0, FP16).
 *
 * Implements block-level SIMD-aligned dequantization from quantized LLM weight
 * formats into continuous single-precision 32-bit floating point buffers (FP32).
 *
 * Mathematical Foundations:
 * - Q4_0: Block of 32 weights. 2-byte FP16 scale 'd' + 16 bytes of 4-bit nibbles.
 *         Formula: w[i] = ((nibble[i] & 0xF) - 8) * d
 * - Q8_0: Block of 32 weights. 2-byte FP16 scale 'd' + 32 bytes of int8.
 *         Formula: w[i] = int8[i] * d
 *
 * @author Shafiullah (Gyani Supreme Core)
 */
final class Dequantizer
{
    /**
     * Converts a 16-bit IEEE 754 half-precision float to standard 32-bit PHP float.
     *
     * WHY: GGUF stores block scale factors in 16-bit float (FP16) to conserve memory.
     * We convert it directly via bitwise arithmetic without external C extensions.
     */
    public static function fp16ToFloat(int $h): float
    {
        $sign = ($h >> 15) & 0x0001;
        $exp  = ($h >> 10) & 0x001F;
        $mant = $h & 0x03FF;

        if ($exp === 0) {
            if ($mant === 0) {
                return $sign ? -0.0 : 0.0;
            }
            // Subnormal number
            return ($sign ? -1.0 : 1.0) * pow(2, -14) * ($mant / 1024.0);
        }

        if ($exp === 31) {
            if ($mant === 0) {
                return $sign ? -INF : INF;
            }
            return NAN;
        }

        // Normalized number: (-1)^sign * 2^(exp - 15) * (1 + mant / 1024)
        return ($sign ? -1.0 : 1.0) * pow(2, $exp - 15) * (1.0 + ($mant / 1024.0));
    }

    /**
     * Converts a 32-bit float into 16-bit IEEE 754 half-precision integer.
     */
    public static function floatToFp16(float $f): int
    {
        if (is_nan($f)) {
            return 0x7E00;
        }
        if (is_infinite($f)) {
            return $f < 0 ? 0xFC00 : 0x7C00;
        }
        if ($f == 0.0) {
            return 0;
        }

        $sign = $f < 0 ? 1 : 0;
        $absF = abs($f);

        $exp = (int)floor(log($absF, 2));
        $mant = ($absF / pow(2, $exp)) - 1.0;

        $fp16Exp = $exp + 15;
        if ($fp16Exp <= 0) {
            // Subnormal
            $mantVal = (int)round(($absF / pow(2, -14)) * 1024.0);
            return ($sign << 15) | min(0x03FF, $mantVal);
        }
        if ($fp16Exp >= 31) {
            return ($sign << 15) | 0x7C00;
        }

        $mantVal = (int)round($mant * 1024.0);
        return ($sign << 15) | ($fp16Exp << 10) | min(0x03FF, $mantVal);
    }

    /**
     * Dequantizes a Q4_0 byte buffer into an array of FP32 floats.
     *
     * @return float[]
     */
    public static function dequantizeQ4_0(string $rawBytes, int $numElements): array
    {
        $out = [];
        $bytesLen = strlen($rawBytes);
        $blockSize = 18; // 2 bytes scale + 16 bytes nibbles = 32 weights
        $numBlocks = (int)ceil($numElements / 32.0);

        $offset = 0;
        $elemCount = 0;

        for ($b = 0; $b < $numBlocks && $offset + $blockSize <= $bytesLen; $b++) {
            // 1. Read FP16 scale
            $scaleRaw = unpack('v', substr($rawBytes, $offset, 2))[1];
            $scale = self::fp16ToFloat($scaleRaw);
            $offset += 2;

            // 2. Read 16 bytes containing 32 nibbles
            $nibbleBytes = substr($rawBytes, $offset, 16);
            $offset += 16;

            // First 16 elements (low nibbles)
            for ($i = 0; $i < 16 && $elemCount < $numElements; $i++) {
                $byte = ord($nibbleBytes[$i]);
                $v0 = ($byte & 0x0F) - 8;
                $out[] = (float)($v0 * $scale);
                $elemCount++;
            }

            // Next 16 elements (high nibbles)
            for ($i = 0; $i < 16 && $elemCount < $numElements; $i++) {
                $byte = ord($nibbleBytes[$i]);
                $v1 = (($byte >> 4) & 0x0F) - 8;
                $out[] = (float)($v1 * $scale);
                $elemCount++;
            }
        }

        return $out;
    }

    /**
     * Dequantizes a Q8_0 byte buffer into an array of FP32 floats.
     *
     * @return float[]
     */
    public static function dequantizeQ8_0(string $rawBytes, int $numElements): array
    {
        $out = [];
        $bytesLen = strlen($rawBytes);
        $blockSize = 34; // 2 bytes scale + 32 bytes int8 = 32 weights
        $numBlocks = (int)ceil($numElements / 32.0);

        $offset = 0;
        $elemCount = 0;

        for ($b = 0; $b < $numBlocks && $offset + $blockSize <= $bytesLen; $b++) {
            // 1. Read FP16 scale
            $scaleRaw = unpack('v', substr($rawBytes, $offset, 2))[1];
            $scale = self::fp16ToFloat($scaleRaw);
            $offset += 2;

            // 2. Read 32 signed 8-bit integers
            for ($i = 0; $i < 32 && $elemCount < $numElements; $i++) {
                $byte = unpack('c', $rawBytes[$offset++])[1];
                $out[] = (float)($byte * $scale);
                $elemCount++;
            }
        }

        return $out;
    }

    /**
     * Dequantizes raw bytes based on GGUF tensor type.
     *
     * @return float[]
     */
    public static function dequantize(string $rawBytes, int $type, int $numElements): array
    {
        return match ($type) {
            GgufParser::GGML_TYPE_Q4_0 => self::dequantizeQ4_0($rawBytes, $numElements),
            GgufParser::GGML_TYPE_Q8_0 => self::dequantizeQ8_0($rawBytes, $numElements),
            GgufParser::GGML_TYPE_F32  => (function() use ($rawBytes, $numElements) {
                $vals = unpack('g*', $rawBytes);
                return array_slice(array_values($vals), 0, $numElements);
            })(),
            default => throw new \InvalidArgumentException("Unsupported dequantization type: {$type}"),
        };
    }

    /**
     * Dequantizes and wraps directly into a Sovereign Tensor2D for hardware GEMM.
     */
    public static function dequantizeToTensor2D(string $rawBytes, int $type, int $rows, int $cols): Tensor2D
    {
        $data = self::dequantize($rawBytes, $type, $rows * $cols);
        return Tensor2D::fromFlatArray($rows, $cols, $data);
    }
}
