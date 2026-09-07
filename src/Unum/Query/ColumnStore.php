<?php

declare(strict_types=1);

namespace Unum\Query;

use FFI;
use InvalidArgumentException;
use RuntimeException;
use Unum\HardwareExecutor;

/**
 * 👑 Sovereign Bare-Metal Columnar Storage (ColumnStore)
 * 
 * WHY: Relational databases (PostgreSQL, MySQL, SQLite) store data in rows,
 * forcing the CPU to fetch unnecessary fields and thrashing L1/L2 cache lines during analytical queries.
 * ColumnStore stores each column contiguously in raw C binary arrays, enabling AVX-512 vector
 * registers to process millions of values simultaneously at full memory bus bandwidth.
 */
final class ColumnStore
{
    private HardwareExecutor $executor;
    private int $rowCount = 0;

    /** @var array<string, array{type: string, buffer: FFI\CData, size: int}> */
    private array $columns = [];

    public function __construct(?HardwareExecutor $executor = null)
    {
        $this->executor = $executor ?? new HardwareExecutor();
    }

    public function getRowCount(): int
    {
        return $this->rowCount;
    }

    public function hasColumn(string $name): bool
    {
        return isset($this->columns[$name]);
    }

    /**
     * Adds or replaces an Int64 column from an array of integers.
     * 
     * @param list<int> $values
     */
    public function addColumnInt64(string $name, array $values): self
    {
        $count = count($values);
        if ($this->rowCount === 0) {
            $this->rowCount = $count;
        } elseif ($count !== $this->rowCount) {
            throw new InvalidArgumentException("Row count mismatch: column '{$name}' has {$count} rows, expected {$this->rowCount}");
        }

        $buffer = $this->executor->newInt64Buffer($count);
        for ($i = 0; $i < $count; $i++) {
            $buffer[$i] = (int)$values[$i];
        }

        $this->columns[$name] = [
            'type'   => 'int64',
            'buffer' => $buffer,
            'size'   => $count,
        ];

        return $this;
    }

    /**
     * Adds or replaces a Float32 column from an array of floats.
     * 
     * @param list<float|int> $values
     */
    public function addColumnFloat32(string $name, array $values): self
    {
        $count = count($values);
        if ($this->rowCount === 0) {
            $this->rowCount = $count;
        } elseif ($count !== $this->rowCount) {
            throw new InvalidArgumentException("Row count mismatch: column '{$name}' has {$count} rows, expected {$this->rowCount}");
        }

        $buffer = $this->executor->newFloatBuffer($count);
        for ($i = 0; $i < $count; $i++) {
            $buffer[$i] = (float)$values[$i];
        }

        $this->columns[$name] = [
            'type'   => 'float32',
            'buffer' => $buffer,
            'size'   => $count,
        ];

        return $this;
    }

    /**
     * Retrieves column descriptor.
     * 
     * @return array{type: string, buffer: FFI\CData, size: int}
     */
    public function getColumn(string $name): array
    {
        if (!isset($this->columns[$name])) {
            throw new InvalidArgumentException("Column '{$name}' does not exist in ColumnStore.");
        }
        return $this->columns[$name];
    }

    public function getExecutor(): HardwareExecutor
    {
        return $this->executor;
    }
}
