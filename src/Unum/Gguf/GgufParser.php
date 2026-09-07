<?php

declare(strict_types=1);

namespace Unum\Gguf;

/**
 * GgufParser: Binary GGUF (v2 / v3) Model File & Metadata Parser.
 *
 * Implements the official binary file specification used by Meta LLaMA 3,
 * DeepSeek, Mistral, and Qwen. Parses model architectures, hyper-parameters,
 * tensor information headers, and memory-mapped binary offsets with zero runtime bloat.
 *
 * @author Shafiullah (Gyani Supreme Core)
 */
final class GgufParser
{
    public const GGUF_MAGIC = 0x46554747; // 'GGUF' in ASCII little-endian

    // GGUF Metadata Value Types
    public const TYPE_UINT8   = 0;
    public const TYPE_INT8    = 1;
    public const TYPE_UINT16  = 2;
    public const TYPE_INT16   = 3;
    public const TYPE_UINT32  = 4;
    public const TYPE_INT32   = 5;
    public const TYPE_FLOAT32 = 6;
    public const TYPE_BOOL    = 7;
    public const TYPE_STRING  = 8;
    public const TYPE_ARRAY   = 9;
    public const TYPE_UINT64  = 10;
    public const TYPE_INT64   = 11;
    public const TYPE_FLOAT64 = 12;

    // GGUF Quantization Tensor Types
    public const GGML_TYPE_F32  = 0;
    public const GGML_TYPE_F16  = 1;
    public const GGML_TYPE_Q4_0 = 2;
    public const GGML_TYPE_Q4_1 = 3;
    public const GGML_TYPE_Q8_0 = 8;
    public const GGML_TYPE_Q4_K = 12;

    private string $buffer;
    private int $offset = 0;

    private int $version = 0;
    private int $tensorCount = 0;
    private int $metadataCount = 0;
    private int $alignment = 32;
    private int $tensorDataOffset = 0;

    /** @var array<string, mixed> Key-Value Metadata store */
    private array $metadata = [];

    /** @var array<string, array{name: string, dims: int[], type: int, offset: int, size: int}> Tensor directory */
    private array $tensors = [];

    public function __construct(string $binaryData)
    {
        $this->buffer = $binaryData;
        $this->offset = 0;
        $this->parse();
    }

    public static function fromFile(string $filePath): self
    {
        if (!file_exists($filePath)) {
            throw new \InvalidArgumentException("GGUF file not found: '{$filePath}'");
        }
        $data = file_get_contents($filePath);
        if ($data === false) {
            throw new \RuntimeException("Failed to read GGUF file: '{$filePath}'");
        }
        return new self($data);
    }

    private function parse(): void
    {
        // 1. Magic check (4 bytes)
        $magic = $this->readUint32();
        if ($magic !== self::GGUF_MAGIC) {
            throw new \RuntimeException(sprintf("Invalid GGUF magic: 0x%08X (expected 0x%08X)", $magic, self::GGUF_MAGIC));
        }

        // 2. Version (uint32)
        $this->version = $this->readUint32();
        if ($this->version < 2 || $this->version > 3) {
            throw new \RuntimeException("Unsupported GGUF version: {$this->version}");
        }

        // 3. Tensor count (uint64) and Metadata count (uint64)
        $this->tensorCount   = $this->readUint64();
        $this->metadataCount = $this->readUint64();

        // 4. Parse Metadata Key-Value pairs
        for ($i = 0; $i < $this->metadataCount; $i++) {
            $key = $this->readString();
            $valType = $this->readUint32();
            $val = $this->readValue($valType);
            $this->metadata[$key] = $val;
        }

        // Extract alignment if specified
        if (isset($this->metadata['general.alignment'])) {
            $this->alignment = (int)$this->metadata['general.alignment'];
        }

        // 5. Parse Tensor Information Table
        for ($i = 0; $i < $this->tensorCount; $i++) {
            $tensorName = $this->readString();
            $nDims = $this->readUint32();

            $dims = [];
            for ($d = 0; $d < $nDims; $d++) {
                $dims[] = $this->readUint64();
            }

            $type = $this->readUint32();
            $tensorOffset = $this->readUint64();

            // Calculate approximate size in bytes based on quantization type
            $numElements = array_product($dims);
            $sizeInBytes = $this->calculateTensorByteSize($numElements, $type);

            $this->tensors[$tensorName] = [
                'name'   => $tensorName,
                'dims'   => $dims,
                'type'   => $type,
                'offset' => $tensorOffset,
                'size'   => $sizeInBytes,
            ];
        }

        // 6. Calculate aligned tensor data start offset
        $pad = $this->offset % $this->alignment;
        $this->tensorDataOffset = ($pad === 0) ? $this->offset : ($this->offset + ($this->alignment - $pad));
    }

    /**
     * Retrieves the raw binary slice of a tensor by name.
     */
    public function getTensorRawBytes(string $name): string
    {
        if (!isset($this->tensors[$name])) {
            throw new \InvalidArgumentException("Tensor '{$name}' not found in GGUF model");
        }

        $info = $this->tensors[$name];
        $start = $this->tensorDataOffset + $info['offset'];
        $len = $info['size'];

        if ($start + $len > strlen($this->buffer)) {
            throw new \RuntimeException("Tensor '{$name}' offset exceeds buffer bounds");
        }

        return substr($this->buffer, $start, $len);
    }

    private function calculateTensorByteSize(int $elements, int $type): int
    {
        return match ($type) {
            self::GGML_TYPE_F32  => $elements * 4,
            self::GGML_TYPE_F16  => $elements * 2,
            self::GGML_TYPE_Q4_0 => (int)(ceil($elements / 32.0) * 18), // 2 bytes scale + 16 bytes nibbles
            self::GGML_TYPE_Q8_0 => (int)(ceil($elements / 32.0) * 34), // 2 bytes scale + 32 bytes int8
            default              => $elements * 4,
        };
    }

    // -------------------------------------------------------------------------
    // Binary Value Readers
    // -------------------------------------------------------------------------

    private function readUint32(): int
    {
        $bytes = substr($this->buffer, $this->offset, 4);
        $this->offset += 4;
        $val = unpack('V', $bytes);
        return (int)$val[1];
    }

    private function readUint64(): int
    {
        $bytes = substr($this->buffer, $this->offset, 8);
        $this->offset += 8;
        $val = unpack('P', $bytes);
        return (int)$val[1];
    }

    private function readFloat32(): float
    {
        $bytes = substr($this->buffer, $this->offset, 4);
        $this->offset += 4;
        $val = unpack('g', $bytes); // little-endian single precision float
        return (float)$val[1];
    }

    private function readString(): string
    {
        $len = $this->readUint64();
        $str = substr($this->buffer, $this->offset, $len);
        $this->offset += $len;
        return $str;
    }

    private function readValue(int $type): mixed
    {
        return match ($type) {
            self::TYPE_UINT8   => ord($this->buffer[$this->offset++]),
            self::TYPE_INT8    => unpack('c', $this->buffer[$this->offset++])[1],
            self::TYPE_UINT16  => (function() { $v = unpack('v', substr($this->buffer, $this->offset, 2))[1]; $this->offset += 2; return $v; })(),
            self::TYPE_INT16   => (function() { $v = unpack('s', substr($this->buffer, $this->offset, 2))[1]; $this->offset += 2; return $v; })(),
            self::TYPE_UINT32  => $this->readUint32(),
            self::TYPE_INT32   => (function() { $v = unpack('l', substr($this->buffer, $this->offset, 4))[1]; $this->offset += 4; return $v; })(),
            self::TYPE_FLOAT32 => $this->readFloat32(),
            self::TYPE_BOOL    => ord($this->buffer[$this->offset++]) !== 0,
            self::TYPE_STRING  => $this->readString(),
            self::TYPE_UINT64, self::TYPE_INT64 => $this->readUint64(),
            self::TYPE_ARRAY   => $this->readArray(),
            default            => throw new \RuntimeException("Unknown GGUF metadata type: {$type}"),
        };
    }

    private function readArray(): array
    {
        $elemType = $this->readUint32();
        $count = $this->readUint64();
        $arr = [];
        for ($i = 0; $i < $count; $i++) {
            $arr[] = $this->readValue($elemType);
        }
        return $arr;
    }

    // -------------------------------------------------------------------------
    // Getters & Metadata Introspection
    // -------------------------------------------------------------------------

    public function getVersion(): int
    {
        return $this->version;
    }

    public function getTensorCount(): int
    {
        return $this->tensorCount;
    }

    public function getMetadataCount(): int
    {
        return $this->metadataCount;
    }

    /**
     * @return array<string, mixed>
     */
    public function getMetadata(): array
    {
        return $this->metadata;
    }

    /**
     * @return array<string, array{name: string, dims: int[], type: int, offset: int, size: int}>
     */
    public function getTensors(): array
    {
        return $this->tensors;
    }

    public function getTensorDataOffset(): int
    {
        return $this->tensorDataOffset;
    }
}
