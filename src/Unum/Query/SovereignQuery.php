<?php

declare(strict_types=1);

namespace Unum\Query;

use FFI;
use InvalidArgumentException;
use RuntimeException;
use Unum\HardwareExecutor;

/**
 * 👑 Sovereign SIMD Columnar Query Engine (SQL Replacement)
 * 
 * WHY: Traditional relational databases (Postgres, MySQL, SQLite) parse SQL strings,
 * plan execution trees, and iterate row-by-row with dynamic dispatch.
 * SovereignQuery executes vectorized filtering and aggregation directly on contiguous
 * binary memory using AVX2 and AVX-512 vector instructions at raw silicon memory bandwidth.
 */
final class SovereignQuery
{
    private ColumnStore $store;
    private HardwareExecutor $executor;
    private ?FFI\CData $currentBitmap = null;
    private int $matchCount = 0;

    public function __construct(ColumnStore $store)
    {
        $this->store = $store;
        $this->executor = $store->getExecutor();
        $this->matchCount = $store->getRowCount();
    }

    public static function from(ColumnStore $store): self
    {
        return new self($store);
    }

    /**
     * Applies a vectorized filter condition (e.g. where('age', '>', 30)).
     */
    public function where(string $colName, string $op, int|float $threshold): self
    {
        $col = $this->store->getColumn($colName);
        $size = $col['size'];
        $type = $col['type'];

        /* Allocate new filter bitmap */
        $newBitmap = $this->executor->newUint8Buffer($size);

        if ($type === 'int64') {
            $thresh = (int)$threshold;
            if ($op === '>') {
                $this->executor->columnFilterGtI64($col['buffer'], $size, $thresh, $newBitmap);
            } elseif ($op === '>=') {
                $this->executor->columnFilterGtI64($col['buffer'], $size, $thresh - 1, $newBitmap);
            } elseif ($op === '<') {
                for ($i = 0; $i < $size; $i++) {
                    $newBitmap[$i] = ($col['buffer'][$i] < $thresh) ? 1 : 0;
                }
            } elseif ($op === '<=') {
                for ($i = 0; $i < $size; $i++) {
                    $newBitmap[$i] = ($col['buffer'][$i] <= $thresh) ? 1 : 0;
                }
            } elseif ($op === '==' || $op === '=') {
                for ($i = 0; $i < $size; $i++) {
                    $newBitmap[$i] = ($col['buffer'][$i] === $thresh) ? 1 : 0;
                }
            } else {
                throw new InvalidArgumentException("Unsupported comparison operator: {$op}");
            }
        } elseif ($type === 'float32') {
            $thresh = (float)$threshold;
            if ($op === '>') {
                $this->executor->columnFilterGtF32($col['buffer'], $size, $thresh, $newBitmap);
            } elseif ($op === '>=') {
                for ($i = 0; $i < $size; $i++) {
                    $newBitmap[$i] = ($col['buffer'][$i] >= $thresh) ? 1 : 0;
                }
            } elseif ($op === '<') {
                for ($i = 0; $i < $size; $i++) {
                    $newBitmap[$i] = ($col['buffer'][$i] < $thresh) ? 1 : 0;
                }
            } elseif ($op === '<=') {
                for ($i = 0; $i < $size; $i++) {
                    $newBitmap[$i] = ($col['buffer'][$i] <= $thresh) ? 1 : 0;
                }
            } elseif ($op === '==' || $op === '=') {
                for ($i = 0; $i < $size; $i++) {
                    $newBitmap[$i] = (abs($col['buffer'][$i] - $thresh) < 1e-6) ? 1 : 0;
                }
            } else {
                throw new InvalidArgumentException("Unsupported comparison operator: {$op}");
            }
        }

        /* Combine with previous bitmap via bitwise AND */
        if ($this->currentBitmap === null) {
            $this->currentBitmap = $newBitmap;
        } else {
            for ($i = 0; $i < $size; $i++) {
                $this->currentBitmap[$i] = (uint8_t)($this->currentBitmap[$i] & $newBitmap[$i]);
            }
        }

        /* Recalculate match count */
        $count = 0;
        for ($i = 0; $i < $size; $i++) {
            $count += $this->currentBitmap[$i];
        }
        $this->matchCount = $count;

        return $this;
    }

    /**
     * Returns count of records matching all where conditions.
     */
    public function count(): int
    {
        return $this->matchCount;
    }

    /**
     * Calculates the sum of a column over matching records using AVX SIMD instructions.
     */
    public function sum(string $colName): int|float
    {
        $col = $this->store->getColumn($colName);
        $size = $col['size'];

        if ($col['type'] === 'int64') {
            return $this->executor->columnSumI64($col['buffer'], $this->currentBitmap, $size);
        }

        return $this->executor->columnSumF32($col['buffer'], $this->currentBitmap, $size);
    }

    /**
     * Calculates the arithmetic mean (average) of a column over matching records.
     */
    public function avg(string $colName): float
    {
        $cnt = $this->count();
        if ($cnt === 0) return 0.0;
        return (float)$this->sum($colName) / (float)$cnt;
    }

    /**
     * Calculates minimum value of a column over matching records.
     */
    public function min(string $colName): int|float
    {
        $col = $this->store->getColumn($colName);
        $size = $col['size'];
        $buf = $col['buffer'];

        $min = null;
        for ($i = 0; $i < $size; $i++) {
            if ($this->currentBitmap === null || $this->currentBitmap[$i] === 1) {
                $val = $buf[$i];
                if ($min === null || $val < $min) {
                    $min = $val;
                }
            }
        }

        return $min ?? 0;
    }

    /**
     * Calculates maximum value of a column over matching records.
     */
    public function max(string $colName): int|float
    {
        $col = $this->store->getColumn($colName);
        $size = $col['size'];
        $buf = $col['buffer'];

        $max = null;
        for ($i = 0; $i < $size; $i++) {
            if ($this->currentBitmap === null || $this->currentBitmap[$i] === 1) {
                $val = $buf[$i];
                if ($max === null || $val > $max) {
                    $max = $val;
                }
            }
        }

        return $max ?? 0;
    }

    /**
     * Selects matching rows up to specified limit.
     * 
     * @param list<string> $columns List of column names to retrieve (empty = all)
     * @return list<array<string, int|float>>
     */
    public function select(array $columns = [], int $limit = 50): array
    {
        $totalRows = $this->store->getRowCount();
        $colsToFetch = !empty($columns) ? $columns : ['*'];

        $results = [];
        for ($i = 0; $i < $totalRows; $i++) {
            if ($this->currentBitmap !== null && $this->currentBitmap[$i] === 0) {
                continue;
            }

            $row = [];
            foreach ($colsToFetch as $cName) {
                $c = $this->store->getColumn($cName);
                $row[$cName] = $c['buffer'][$i];
            }
            $results[] = $row;

            if (count($results) >= $limit) {
                break;
            }
        }

        return $results;
    }
}
