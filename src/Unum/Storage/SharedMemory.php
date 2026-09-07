<?php

declare(strict_types=1);

namespace Unum\Storage;

use FFI;
use InvalidArgumentException;
use RuntimeException;
use Unum\HardwareExecutor;

/**
 * 👑 Sovereign POSIX Shared Memory Allocator
 * 
 * WHY: Redis and Memcached require TCP sockets, Unix domain sockets, network stack traversal,
 * and data serialization (JSON, igbinary, msgpack), introducing hundreds of microseconds of latency.
 * SharedMemory maps raw RAM directly into the virtual address space of multiple OS processes
 * (mmap MAP_SHARED), allowing concurrent processes to read and write binary state in nanoseconds.
 */
final class SharedMemory
{
    private string $name;
    private int $size;
    private FFI\CData $addr;
    private HardwareExecutor $executor;
    private bool $isOwner;

    public function __construct(
        string $name,
        int $size = 1048576, // Default: 1 Megabyte
        bool $create = true,
        ?HardwareExecutor $executor = null
    ) {
        $this->name = str_starts_with($name, '/') ? $name : '/' . $name;
        $this->size = $size;
        $this->executor = $executor ?? new HardwareExecutor();
        $this->isOwner = $create;

        if ($create) {
            $shm = $this->executor->shmCreate($this->name, $this->size);
        } else {
            $shm = $this->executor->shmOpen($this->name, $this->size);
        }

        $this->addr = $shm['addr'];
    }

    public function getName(): string
    {
        return $this->name;
    }

    public function getSize(): int
    {
        return $this->size;
    }

    public function getAddress(): FFI\CData
    {
        return $this->addr;
    }

    /**
     * Writes raw binary string data into shared memory at specified offset.
     */
    public function write(int $offset, string $data): void
    {
        $len = strlen($data);
        if ($offset < 0 || $offset + $len > $this->size) {
            throw new InvalidArgumentException("Shared memory write out of bounds: offset {$offset} + length {$len} > size {$this->size}");
        }

        $ptr = FFI::cast("char*", $this->addr);
        FFI::memcpy(FFI::addr($ptr[$offset]), $data, $len);
    }

    /**
     * Reads raw binary data from shared memory at specified offset.
     */
    public function read(int $offset, int $length): string
    {
        if ($offset < 0 || $offset + $length > $this->size) {
            throw new InvalidArgumentException("Shared memory read out of bounds: offset {$offset} + length {$length} > size {$this->size}");
        }

        $ptr = FFI::cast("char*", $this->addr);
        return FFI::string(FFI::addr($ptr[$offset]), $length);
    }

    /**
     * Writes a 64-bit integer into shared memory at specified offset.
     */
    public function writeInt64(int $offset, int $value): void
    {
        if ($offset < 0 || $offset + 8 > $this->size) {
            throw new InvalidArgumentException("Shared memory int64 write out of bounds at offset {$offset}");
        }

        $ptr = FFI::cast("int64_t*", FFI::addr(FFI::cast("char*", $this->addr)[$offset]));
        $ptr[0] = $value;
    }

    /**
     * Reads a 64-bit integer from shared memory at specified offset.
     */
    public function readInt64(int $offset): int
    {
        if ($offset < 0 || $offset + 8 > $this->size) {
            throw new InvalidArgumentException("Shared memory int64 read out of bounds at offset {$offset}");
        }

        $ptr = FFI::cast("int64_t*", FFI::addr(FFI::cast("char*", $this->addr)[$offset]));
        return (int)$ptr[0];
    }

    /**
     * Performs a hardware-atomic 64-bit fetch and add (XADD) directly on shared memory.
     */
    public function atomicIncrement(int $offset, int $delta = 1): int
    {
        if ($offset < 0 || $offset + 8 > $this->size) {
            throw new InvalidArgumentException("Shared memory atomic increment out of bounds at offset {$offset}");
        }

        $ptr = FFI::cast("uint64_t*", FFI::addr(FFI::cast("char*", $this->addr)[$offset]));
        return $this->executor->atomicFetchAdd64($ptr, $delta) + $delta;
    }

    /**
     * Performs a hardware-atomic 64-bit compare and swap (CMPXCHG).
     */
    public function atomicCompareAndSwap(int $offset, int $oldVal, int $newVal): int
    {
        if ($offset < 0 || $offset + 8 > $this->size) {
            throw new InvalidArgumentException("Shared memory atomic CAS out of bounds at offset {$offset}");
        }

        $ptr = FFI::cast("uint64_t*", FFI::addr(FFI::cast("char*", $this->addr)[$offset]));
        return $this->executor->atomicCas64($ptr, $oldVal, $newVal);
    }

    /**
     * Closes and unmaps the shared memory segment.
     */
    public function close(): void
    {
        $this->executor->shmClose($this->addr, $this->size);
    }

    /**
     * Unlinks the shared memory segment name from the OS kernel (/dev/shm).
     */
    public function unlink(): void
    {
        $this->executor->shmUnlink($this->name);
    }

    public function __destruct()
    {
        $this->close();
        if ($this->isOwner) {
            $this->unlink();
        }
    }
}
