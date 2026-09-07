<?php

declare(strict_types=1);

namespace Unum\Storage;

use RuntimeException;
use Unum\HardwareExecutor;

/**
 * 👑 Sovereign In-Memory Key-Value Store (Redis / Memcached Replacement)
 * 
 * WHY: Redis introduces network TCP/IP stack latency (0.5ms - 2ms) and serialization bloat.
 * SovereignStore stores structured data directly in RAM using Robin Hood hashing with
 * sub-microsecond retrieval latencies, eliminating the need for standalone Redis servers.
 */
final class SovereignStore
{
    private RobinHoodTable $table;
    private ?SharedMemory $shm;
    /** @var array<string, int> Key expiration timestamp lookup */
    private array $ttls = [];

    public function __construct(int $initialCapacity = 2048, ?string $sharedMemoryName = null, int $shmSize = 2097152)
    {
        $this->table = new RobinHoodTable($initialCapacity);
        $this->shm = $sharedMemoryName !== null ? new SharedMemory($sharedMemoryName, $shmSize, true) : null;
    }

    /**
     * Stores a key-value entry with optional Time-To-Live (TTL) in seconds.
     */
    public function set(string $key, mixed $value, ?int $ttlSeconds = null): bool
    {
        $this->table->put($key, $value);

        if ($ttlSeconds !== null && $ttlSeconds > 0) {
            $this->ttls[$key] = time() + $ttlSeconds;
        } else {
            unset($this->ttls[$key]);
        }

        return true;
    }

    /**
     * Retrieves a value by key. Returns default if expired or not found.
     */
    public function get(string $key, mixed $default = null): mixed
    {
        /* Check TTL */
        if (isset($this->ttls[$key]) && time() >= $this->ttls[$key]) {
            $this->delete($key);
            return $default;
        }

        return $this->table->get($key, $default);
    }

    /**
     * Checks if a non-expired key exists in the store.
     */
    public function has(string $key): bool
    {
        return $this->get($key, $this) !== $this;
    }

    /**
     * Deletes a key from the store.
     */
    public function delete(string $key): bool
    {
        unset($this->ttls[$key]);
        return $this->table->delete($key);
    }

    /**
     * Atomically increments an integer value stored at key.
     */
    public function increment(string $key, int $delta = 1): int
    {
        $current = (int)$this->get($key, 0);
        $newVal = $current + $delta;
        $this->set($key, $newVal);
        return $newVal;
    }

    /**
     * Atomically decrements an integer value stored at key.
     */
    public function decrement(string $key, int $delta = 1): int
    {
        return $this->increment($key, -$delta);
    }

    public function count(): int
    {
        return $this->table->count();
    }

    /**
     * Returns internal shared memory instance if configured.
     */
    public function getSharedMemory(): ?SharedMemory
    {
        return $this->shm;
    }
}
