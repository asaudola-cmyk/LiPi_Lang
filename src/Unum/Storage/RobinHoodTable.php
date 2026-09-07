<?php

declare(strict_types=1);

namespace Unum\Storage;

use SplFixedArray;
use InvalidArgumentException;

/**
 * 👑 Sovereign High-Performance Robin Hood Hash Table
 * 
 * WHY: Flat parallel arrays eliminate PHP nested array copy-on-write overhead,
 * maintaining cache locality and O(1) guaranteed bound probe distance with zero GC pressure.
 */
final class RobinHoodTable
{
    private int $capacity;
    private int $count = 0;
    private int $mask;

    /** @var SplFixedArray<string|null> */
    private SplFixedArray $keys;
    /** @var SplFixedArray<mixed> */
    private SplFixedArray $vals;
    /** @var SplFixedArray<int> */
    private SplFixedArray $dists;
    /** @var SplFixedArray<bool> */
    private SplFixedArray $occupied;

    public function __construct(int $capacity = 65536)
    {
        if ($capacity < 16) {
            $capacity = 16;
        }

        /* Power-of-two capacity for fast bitwise masking */
        $this->capacity = 1 << (int)ceil(log($capacity, 2));
        $this->mask = $this->capacity - 1;

        $this->keys = new SplFixedArray($this->capacity);
        $this->vals = new SplFixedArray($this->capacity);
        $this->dists = new SplFixedArray($this->capacity);
        $this->occupied = new SplFixedArray($this->capacity);

        for ($i = 0; $i < $this->capacity; $i++) {
            $this->occupied[$i] = false;
            $this->dists[$i] = 0;
        }
    }

    public function capacity(): int
    {
        return $this->capacity;
    }

    public function count(): int
    {
        return $this->count;
    }

    public static function hashKey(string $key): int
    {
        /* WHY: Hardware-accelerated CRC32 generates uniform avalanche distribution without float overflow */
        return crc32($key) & 0x7FFFFFFF;
    }

    public function put(string $key, mixed $value): void
    {
        if ($this->count >= (int)($this->capacity * 0.90)) {
            $this->resize($this->capacity * 2);
        }

        $idx = self::hashKey($key) & $this->mask;
        $dist = 0;
        $currKey = $key;
        $currVal = $value;

        while (true) {
            if (!$this->occupied[$idx]) {
                $this->occupied[$idx] = true;
                $this->keys[$idx] = $currKey;
                $this->vals[$idx] = $currVal;
                $this->dists[$idx] = $dist;
                $this->count++;
                return;
            }

            /* Key match: update in-place */
            if ($this->keys[$idx] === $currKey) {
                $this->vals[$idx] = $currVal;
                return;
            }

            /* Robin Hood displacement: swap if current distance is greater than resident distance */
            if ($this->dists[$idx] < $dist) {
                $tmpKey = $this->keys[$idx];
                $tmpVal = $this->vals[$idx];
                $tmpDist = $this->dists[$idx];

                $this->keys[$idx] = $currKey;
                $this->vals[$idx] = $currVal;
                $this->dists[$idx] = $dist;

                $currKey = $tmpKey;
                $currVal = $tmpVal;
                $dist = $tmpDist;
            }

            $dist++;
            $idx = ($idx + 1) & $this->mask;
        }
    }

    public function get(string $key, mixed $default = null): mixed
    {
        $idx = self::hashKey($key) & $this->mask;
        $dist = 0;

        while (true) {
            if (!$this->occupied[$idx] || $this->dists[$idx] < $dist) {
                return $default;
            }

            if ($this->keys[$idx] === $key) {
                return $this->vals[$idx];
            }

            $dist++;
            $idx = ($idx + 1) & $this->mask;
        }
    }

    public function has(string $key): bool
    {
        return $this->get($key, $this) !== $this;
    }

    public function delete(string $key): bool
    {
        $idx = self::hashKey($key) & $this->mask;
        $dist = 0;

        while (true) {
            if (!$this->occupied[$idx] || $this->dists[$idx] < $dist) {
                return false;
            }

            if ($this->keys[$idx] === $key) {
                $this->count--;
                $curr = $idx;
                while (true) {
                    $next = ($curr + 1) & $this->mask;
                    if (!$this->occupied[$next] || $this->dists[$next] === 0) {
                        $this->occupied[$curr] = false;
                        $this->keys[$curr] = null;
                        $this->vals[$curr] = null;
                        $this->dists[$curr] = 0;
                        break;
                    }
                    $this->occupied[$curr] = true;
                    $this->keys[$curr] = $this->keys[$next];
                    $this->vals[$curr] = $this->vals[$next];
                    $this->dists[$curr] = $this->dists[$next] - 1;
                    $curr = $next;
                }
                return true;
            }

            $dist++;
            $idx = ($idx + 1) & $this->mask;
        }
    }

    private function resize(int $newCapacity): void
    {
        $oldKeys = $this->keys;
        $oldVals = $this->vals;
        $oldOccupied = $this->occupied;
        $oldCap = $this->capacity;

        $this->capacity = $newCapacity;
        $this->mask = $this->capacity - 1;
        $this->count = 0;

        $this->keys = new SplFixedArray($this->capacity);
        $this->vals = new SplFixedArray($this->capacity);
        $this->dists = new SplFixedArray($this->capacity);
        $this->occupied = new SplFixedArray($this->capacity);

        for ($i = 0; $i < $this->capacity; $i++) {
            $this->occupied[$i] = false;
            $this->dists[$i] = 0;
        }

        for ($i = 0; $i < $oldCap; $i++) {
            if ($oldOccupied[$i]) {
                $this->put((string)$oldKeys[$i], $oldVals[$i]);
            }
        }
    }
}
