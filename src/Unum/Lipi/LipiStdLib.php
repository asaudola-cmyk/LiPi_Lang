<?php

declare(strict_types=1);

namespace Unum\Lipi;

require_once __DIR__ . '/LipiAst.php';
require_once __DIR__ . '/LipiRuntime.php';

use RuntimeException;

/**
 * 👑 Lipi Comprehensive Native Standard Library (LipiStdLib)
 *
 * WHY: A programming language without a standard library is incomplete.
 * LipiStdLib provides rich, bilingual built-in standard modules for:
 * - File I/O: লিপি.ফাইল / fs (read, write, append, exists, size, list, delete)
 * - OS & Sys: লিপি.সিস্টেম / sys (env, exec, platform, arch, memory_usage, exit)
 * - Time: লিপি.সময় / time (now, sleep, date, micro)
 * - Advanced Math: লিপি.গণিত / math (sin, cos, tan, sqrt, pow, log, floor, ceil, round, PI, E, random)
 * - Serialization: লিপি.ডাটা / data (json_encode, json_decode, base64_encode, base64_decode, hash)
 *
 * All modules are accessible both under the master sovereign namespace `লিপি` / `lipi`
 * (e.g. `লিপি.ফাইল.পড়ো(...)` / `lipi.fs.read(...)`) and via direct bilingual globals
 * (e.g. `ফাইল.পড়ো(...)` / `fs.read(...)`).
 *
 * @author Shafiullah (Gyani Supreme Core)
 */
final class LipiStdLib
{
    /**
     * Registers all standard library modules into the runtime environment.
     */
    public static function register(LipiEnvironment $env): void
    {
        // 1. Module: File I/O (লিপি.ফাইল / fs)
        $fsModule = self::createFsModule();
        $env->define('ফাইল', $fsModule, true);
        $env->define('fs', $fsModule, true);
        $env->define('file', $fsModule, true);

        // 2. Module: OS & System (লিপি.সিস্টেম / sys)
        $sysModule = self::createSysModule();
        $env->define('সিস্টেম', $sysModule, true);
        $env->define('sys', $sysModule, true);
        $env->define('system', $sysModule, true);

        // 3. Module: High-Precision Time (লিপি.সময় / time)
        $timeModule = self::createTimeModule();
        $env->define('লিপি_সময়', $timeModule, true);
        $env->define('time_mod', $timeModule, true);

        // 4. Module: Advanced Math (লিপি.গণিত / math)
        $mathModule = self::createMathModule();
        $env->define('গণিত', $mathModule, true);
        $env->define('math', $mathModule, true);

        // 5. Module: Data & Serialization (লিপি.ডাটা / data)
        $dataModule = self::createDataModule();
        $env->define('ডাটা', $dataModule, true);
        $env->define('data', $dataModule, true);

        // 6. Master Sovereign Namespace (লিপি / lipi)
        // Bundles all subsystems including in-memory POSIX storage (লিপি.স্মৃতি)
        $memoryModule = $env->has('স্মৃতি') ? $env->get('স্মৃতি') : [];

        $lipiMaster = [
            'ফাইল'    => $fsModule,
            'fs'      => $fsModule,
            'file'    => $fsModule,

            'সিস্টেম' => $sysModule,
            'sys'     => $sysModule,
            'system'  => $sysModule,

            'সময়'     => $timeModule,
            'time'    => $timeModule,

            'গণিত'    => $mathModule,
            'math'    => $mathModule,

            'ডাটা'    => $dataModule,
            'data'    => $dataModule,

            'স্মৃতি'   => $memoryModule,
            'memory'  => $memoryModule,

            'সংস্করণ' => '2.0.0-sovereign',
            'version' => '2.0.0-sovereign',
        ];

        $env->define('লিপি', $lipiMaster, true);
        $env->define('lipi', $lipiMaster, true);
    }

    /**
     * Creates File I/O module (লিপি.ফাইল / fs).
     *
     * @return array<string, mixed>
     */
    private static function createFsModule(): array
    {
        $readFn = new LipiBuiltinFunction('read', 1, function (LipiRuntime $rt, array $args): string {
            $path = (string)($args[0] ?? '');
            if (!file_exists($path)) {
                throw new RuntimeException("ফাইল পাওয়া যায়নি (File not found): '{$path}'");
            }
            $content = file_get_contents($path);
            if ($content === false) {
                throw new RuntimeException("ফাইল পড়া যায়নি (Failed to read file): '{$path}'");
            }
            return $content;
        });

        $writeFn = new LipiBuiltinFunction('write', 2, function (LipiRuntime $rt, array $args): int {
            $path = (string)($args[0] ?? '');
            $data = (string)($args[1] ?? '');
            $dir = dirname($path);
            if (!is_dir($dir)) {
                mkdir($dir, 0755, true);
            }
            $written = file_put_contents($path, $data);
            if ($written === false) {
                throw new RuntimeException("ফাইলে লেখা যায়নি (Failed to write file): '{$path}'");
            }
            return $written;
        });

        $appendFn = new LipiBuiltinFunction('append', 2, function (LipiRuntime $rt, array $args): int {
            $path = (string)($args[0] ?? '');
            $data = (string)($args[1] ?? '');
            $dir = dirname($path);
            if (!is_dir($dir)) {
                mkdir($dir, 0755, true);
            }
            $written = file_put_contents($path, $data, FILE_APPEND);
            if ($written === false) {
                throw new RuntimeException("ফাইলে যুক্ত করা যায়নি (Failed to append file): '{$path}'");
            }
            return $written;
        });

        $existsFn = new LipiBuiltinFunction('exists', 1, function (LipiRuntime $rt, array $args): bool {
            $path = (string)($args[0] ?? '');
            return file_exists($path);
        });

        $sizeFn = new LipiBuiltinFunction('size', 1, function (LipiRuntime $rt, array $args): int {
            $path = (string)($args[0] ?? '');
            return file_exists($path) ? (int)filesize($path) : 0;
        });

        $deleteFn = new LipiBuiltinFunction('delete', 1, function (LipiRuntime $rt, array $args): bool {
            $path = (string)($args[0] ?? '');
            return file_exists($path) ? unlink($path) : false;
        });

        $listFn = new LipiBuiltinFunction('list', 1, function (LipiRuntime $rt, array $args): array {
            $dir = (string)($args[0] ?? '.');
            if (!is_dir($dir)) {
                return [];
            }
            $files = scandir($dir);
            if ($files === false) {
                return [];
            }
            return array_values(array_filter($files, fn($f) => $f !== '.' && $f !== '..'));
        });

        return [
            'পড়ো'       => $readFn,
            'read'       => $readFn,
            'লেখো'       => $writeFn,
            'write'      => $writeFn,
            'যুক্ত_করো'  => $appendFn,
            'append'     => $appendFn,
            'আছে_কিনা'   => $existsFn,
            'exists'     => $existsFn,
            'আকার'       => $sizeFn,
            'size'       => $sizeFn,
            'মুছো'       => $deleteFn,
            'delete'     => $deleteFn,
            'তালিকা'     => $listFn,
            'list'       => $listFn,
        ];
    }

    /**
     * Creates OS & System module (লিপি.সিস্টেম / sys).
     *
     * @return array<string, mixed>
     */
    private static function createSysModule(): array
    {
        $envFn = new LipiBuiltinFunction('env', 2, function (LipiRuntime $rt, array $args): ?string {
            $key = (string)($args[0] ?? '');
            $default = isset($args[1]) ? (string)$args[1] : null;
            $val = getenv($key);
            if ($val === false) {
                $val = $_ENV[$key] ?? $default;
            }
            return $val !== null ? (string)$val : $default;
        });

        $execFn = new LipiBuiltinFunction('exec', 1, function (LipiRuntime $rt, array $args): array {
            $cmd = (string)($args[0] ?? '');
            $output = [];
            $code = 0;
            exec($cmd, $output, $code);
            $outStr = implode("\n", $output);
            return [
                'আউটপুট' => $outStr,
                'output' => $outStr,
                'কোড'    => $code,
                'code'   => $code,
            ];
        });

        $exitFn = new LipiBuiltinFunction('exit', 1, function (LipiRuntime $rt, array $args): void {
            $code = isset($args[0]) ? (int)$args[0] : 0;
            exit($code);
        });

        $platformFn = new LipiBuiltinFunction('platform', 0, function (LipiRuntime $rt, array $args): string {
            return PHP_OS_FAMILY;
        });

        $archFn = new LipiBuiltinFunction('arch', 0, function (LipiRuntime $rt, array $args): string {
            return php_uname('m');
        });

        $memFn = new LipiBuiltinFunction('memory_usage', 0, function (LipiRuntime $rt, array $args): int {
            return memory_get_usage(true);
        });

        return [
            'পরিবেশ'       => $envFn,
            'env'           => $envFn,
            'কমান্ড'        => $execFn,
            'exec'          => $execFn,
            'বিদায়'         => $exitFn,
            'exit'          => $exitFn,
            'প্ল্যাটফর্ম'    => $platformFn,
            'platform'      => $platformFn,
            'প্রসেসর'       => $archFn,
            'arch'          => $archFn,
            'মেমোরি'        => $memFn,
            'memory_usage'  => $memFn,
        ];
    }

    /**
     * Creates High-Precision Time module (লিপি.সময় / time).
     *
     * @return array<string, mixed>
     */
    private static function createTimeModule(): array
    {
        $nowFn = new LipiBuiltinFunction('now', 0, function (LipiRuntime $rt, array $args): float {
            return microtime(true);
        });

        $sleepFn = new LipiBuiltinFunction('sleep', 1, function (LipiRuntime $rt, array $args): void {
            $seconds = (float)($args[0] ?? 0);
            if ($seconds > 0) {
                usleep((int)($seconds * 1_000_000));
            }
        });

        $dateFn = new LipiBuiltinFunction('date', 2, function (LipiRuntime $rt, array $args): string {
            $fmt = isset($args[0]) ? (string)$args[0] : 'Y-m-d H:i:s';
            $ts = isset($args[1]) ? (int)$args[1] : time();
            return date($fmt, $ts);
        });

        $microFn = new LipiBuiltinFunction('micro', 0, function (LipiRuntime $rt, array $args): int {
            return (int)(microtime(true) * 1_000_000);
        });

        return [
            'এখন'    => $nowFn,
            'now'    => $nowFn,
            'ঘুম'    => $sleepFn,
            'sleep'  => $sleepFn,
            'তারিখ'  => $dateFn,
            'date'   => $dateFn,
            'মাইক্রো' => $microFn,
            'micro'  => $microFn,
        ];
    }

    /**
     * Creates Advanced Math module (লিপি.গণিত / math).
     *
     * @return array<string, mixed>
     */
    private static function createMathModule(): array
    {
        return [
            // Constants
            'পাই'       => M_PI,
            'PI'        => M_PI,
            'pi'        => M_PI,
            'ই'         => M_E,
            'E'         => M_E,

            // Trigonometry
            'সাইন'      => new LipiBuiltinFunction('sin', 1, fn($rt, $a) => sin((float)$a[0])),
            'sin'       => new LipiBuiltinFunction('sin', 1, fn($rt, $a) => sin((float)$a[0])),
            'কস'        => new LipiBuiltinFunction('cos', 1, fn($rt, $a) => cos((float)$a[0])),
            'cos'       => new LipiBuiltinFunction('cos', 1, fn($rt, $a) => cos((float)$a[0])),
            'ট্যান'      => new LipiBuiltinFunction('tan', 1, fn($rt, $a) => tan((float)$a[0])),
            'tan'       => new LipiBuiltinFunction('tan', 1, fn($rt, $a) => tan((float)$a[0])),

            // Roots & Powers
            'বর্গমূল'   => new LipiBuiltinFunction('sqrt', 1, fn($rt, $a) => sqrt((float)$a[0])),
            'sqrt'      => new LipiBuiltinFunction('sqrt', 1, fn($rt, $a) => sqrt((float)$a[0])),
            'ঘাত'       => new LipiBuiltinFunction('pow', 2, fn($rt, $a) => ((float)$a[0]) ** ((float)$a[1])),
            'pow'       => new LipiBuiltinFunction('pow', 2, fn($rt, $a) => ((float)$a[0]) ** ((float)$a[1])),
            'লগ'        => new LipiBuiltinFunction('log', 2, function ($rt, $a) {
                $x = (float)$a[0];
                $base = isset($a[1]) ? (float)$a[1] : M_E;
                return $base === M_E ? log($x) : log($x, $base);
            }),
            'log'       => new LipiBuiltinFunction('log', 2, function ($rt, $a) {
                $x = (float)$a[0];
                $base = isset($a[1]) ? (float)$a[1] : M_E;
                return $base === M_E ? log($x) : log($x, $base);
            }),

            // Rounding & Abs
            'মেঝে'      => new LipiBuiltinFunction('floor', 1, fn($rt, $a) => (int)floor((float)$a[0])),
            'floor'     => new LipiBuiltinFunction('floor', 1, fn($rt, $a) => (int)floor((float)$a[0])),
            'ছাদ'       => new LipiBuiltinFunction('ceil', 1, fn($rt, $a) => (int)ceil((float)$a[0])),
            'ceil'      => new LipiBuiltinFunction('ceil', 1, fn($rt, $a) => (int)ceil((float)$a[0])),
            'নিকটবর্তী' => new LipiBuiltinFunction('round', 2, fn($rt, $a) => round((float)$a[0], isset($a[1]) ? (int)$a[1] : 0)),
            'round'     => new LipiBuiltinFunction('round', 2, fn($rt, $a) => round((float)$a[0], isset($a[1]) ? (int)$a[1] : 0)),
            'পরমমান'    => new LipiBuiltinFunction('abs', 1, fn($rt, $a) => abs($a[0])),
            'abs'       => new LipiBuiltinFunction('abs', 1, fn($rt, $a) => abs($a[0])),

            // Extremes
            'সর্বোচ্চ'   => new LipiBuiltinFunction('max', -1, fn($rt, $a) => is_array($a[0] ?? null) ? max($a[0]) : max($a)),
            'max'       => new LipiBuiltinFunction('max', -1, fn($rt, $a) => is_array($a[0] ?? null) ? max($a[0]) : max($a)),
            'সর্বনিম্ন'   => new LipiBuiltinFunction('min', -1, fn($rt, $a) => is_array($a[0] ?? null) ? min($a[0]) : min($a)),
            'min'       => new LipiBuiltinFunction('min', -1, fn($rt, $a) => is_array($a[0] ?? null) ? min($a[0]) : min($a)),

            // Random
            'যদৃচ্ছ'    => new LipiBuiltinFunction('random', 2, function ($rt, $a) {
                $min = isset($a[0]) ? $a[0] : 0;
                $max = isset($a[1]) ? $a[1] : 1;
                if (is_int($min) && is_int($max)) {
                    return mt_rand($min, $max);
                }
                return (float)$min + (mt_rand() / mt_getrandmax()) * ((float)$max - (float)$min);
            }),
            'random'    => new LipiBuiltinFunction('random', 2, function ($rt, $a) {
                $min = isset($a[0]) ? $a[0] : 0;
                $max = isset($a[1]) ? $a[1] : 1;
                if (is_int($min) && is_int($max)) {
                    return mt_rand($min, $max);
                }
                return (float)$min + (mt_rand() / mt_getrandmax()) * ((float)$max - (float)$min);
            }),
        ];
    }

    /**
     * Creates Serialization & Encoding module (লিপি.ডাটা / data).
     *
     * @return array<string, mixed>
     */
    private static function createDataModule(): array
    {
        $jsonEncodeFn = new LipiBuiltinFunction('json_encode', 1, function (LipiRuntime $rt, array $args): string {
            return json_encode($args[0] ?? null, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT) ?: '{}';
        });

        $jsonDecodeFn = new LipiBuiltinFunction('json_decode', 1, function (LipiRuntime $rt, array $args): mixed {
            $json = (string)($args[0] ?? '{}');
            return json_decode($json, true);
        });

        $b64EncodeFn = new LipiBuiltinFunction('base64_encode', 1, function (LipiRuntime $rt, array $args): string {
            return base64_encode((string)($args[0] ?? ''));
        });

        $b64DecodeFn = new LipiBuiltinFunction('base64_decode', 1, function (LipiRuntime $rt, array $args): string {
            return base64_decode((string)($args[0] ?? ''));
        });

        $hashFn = new LipiBuiltinFunction('hash', 2, function (LipiRuntime $rt, array $args): string {
            $algo = isset($args[0]) ? (string)$args[0] : 'sha256';
            $data = isset($args[1]) ? (string)$args[1] : '';
            return hash($algo, $data);
        });

        return [
            'জেসন_লিখ'      => $jsonEncodeFn,
            'json_encode'    => $jsonEncodeFn,
            'জেসন_পড়'       => $jsonDecodeFn,
            'json_decode'    => $jsonDecodeFn,
            'বেস৬৪_কোড'     => $b64EncodeFn,
            'base64_encode'  => $b64EncodeFn,
            'বেস৬৪_ডিকোড'    => $b64DecodeFn,
            'base64_decode'  => $b64DecodeFn,
            'হ্যাশ'          => $hashFn,
            'hash'           => $hashFn,
        ];
    }
}
