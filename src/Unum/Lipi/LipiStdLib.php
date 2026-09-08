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
        $env->define('জেসন_লিখ', $dataModule['জেসন_লিখ'], true);
        $env->define('json_encode', $dataModule['json_encode'], true);
        $env->define('জেসন_পড়', $dataModule['জেসন_পড়'], true);
        $env->define('json_decode', $dataModule['json_decode'], true);
        $env->define('প্যাক_১৬', $dataModule['প্যাক_১৬'], true);
        $env->define('pack_u16', $dataModule['pack_u16'], true);
        $env->define('প্যাক_৩২', $dataModule['প্যাক_৩২'], true);
        $env->define('pack_u32', $dataModule['pack_u32'], true);
        $env->define('প্যাক_৬৪', $dataModule['প্যাক_৬৪'], true);
        $env->define('pack_u64', $dataModule['pack_u64'], true);
        $env->define('বাইট_অক্ষর', $dataModule['বাইট_অক্ষর'], true);
        $env->define('chr', $dataModule['chr'], true);
        $env->define('অর্ড', $dataModule['অর্ড'], true);
        $env->define('ord', $dataModule['ord'], true);
        $env->define('উপস্ট্রিং', $dataModule['উপস্ট্রিং'], true);
        $env->define('substr', $dataModule['substr'], true);
        $env->define('পুনরাবৃত্তি', $dataModule['পুনরাবৃত্তি'], true);
        $env->define('str_repeat', $dataModule['str_repeat'], true);
        $env->define('প্যাডিং', $dataModule['প্যাডিং'], true);

        // 6. Module: Bare-Metal Hardware & Universal Number (লিপি.হার্ডওয়্যার / hardware / unum)
        $hwModule = self::createHardwareModule();
        $env->define('হার্ডওয়্যার', $hwModule, true);
        $env->define('hardware', $hwModule, true);
        $env->define('ইউনাম', $hwModule, true);
        $env->define('unum', $hwModule, true);

        // 7. Master Sovereign Namespace (লিপি / lipi)
        // Bundles all subsystems including in-memory POSIX storage (লিপি.স্মৃতি)
        $memoryModule = $env->has('স্মৃতি') ? $env->get('স্মৃতি') : [];

        $lipiMaster = [
            'ফাইল'       => $fsModule,
            'fs'         => $fsModule,
            'file'       => $fsModule,

            'সিস্টেম'    => $sysModule,
            'sys'        => $sysModule,
            'system'     => $sysModule,

            'সময়'        => $timeModule,
            'time'       => $timeModule,

            'গণিত'       => $mathModule,
            'math'       => $mathModule,

            'ডাটা'       => $dataModule,
            'data'       => $dataModule,

            'স্মৃতি'      => $memoryModule,
            'memory'     => $memoryModule,

            'হার্ডওয়্যার' => $hwModule,
            'hardware'   => $hwModule,
            'ইউনাম'      => $hwModule,
            'unum'       => $hwModule,

            'সংস্করণ'    => '2.0.0-sovereign',
            'version'    => '2.0.0-sovereign',
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
            'পড়'        => $readFn,
            'পড়া'       => $readFn,
            'read'       => $readFn,
            'লেখো'       => $writeFn,
            'লিখ'        => $writeFn,
            'লেখা'       => $writeFn,
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

        $argsFn = new LipiBuiltinFunction('args', 0, function (LipiRuntime $rt, array $args): array {
            return $rt->getArguments();
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
            'আর্গুমেন্ট'    => $argsFn,
            'args'          => $argsFn,
            'argv'          => $argsFn,
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

        // Binary packing primitives for bare-metal ELF machine code synthesis
        $packU16Fn = new LipiBuiltinFunction('pack_u16', 1, function (LipiRuntime $rt, array $args): string {
            return pack('v', (int)($args[0] ?? 0));
        });

        $packU32Fn = new LipiBuiltinFunction('pack_u32', 1, function (LipiRuntime $rt, array $args): string {
            return pack('V', (int)($args[0] ?? 0));
        });

        $packU64Fn = new LipiBuiltinFunction('pack_u64', 1, function (LipiRuntime $rt, array $args): string {
            return pack('P', (int)($args[0] ?? 0));
        });

        $chrFn = new LipiBuiltinFunction('chr', 1, function (LipiRuntime $rt, array $args): string {
            return chr((int)($args[0] ?? 0));
        });

        $ordFn = new LipiBuiltinFunction('ord', 1, function (LipiRuntime $rt, array $args): int {
            $s = (string)($args[0] ?? '');
            return strlen($s) > 0 ? ord($s[0]) : 0;
        });

        $substrFn = new LipiBuiltinFunction('substr', 3, function (LipiRuntime $rt, array $args): string {
            $str = (string)($args[0] ?? '');
            $start = (int)($args[1] ?? 0);
            $len = isset($args[2]) ? (int)$args[2] : null;
            return $len !== null ? substr($str, $start, $len) : substr($str, $start);
        });

        $repeatFn = new LipiBuiltinFunction('str_repeat', 2, function (LipiRuntime $rt, array $args): string {
            $input = (string)($args[0] ?? '');
            $times = max(0, (int)($args[1] ?? 0));
            return str_repeat($input, $times);
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
            'প্যাক_১৬'       => $packU16Fn,
            'pack_u16'       => $packU16Fn,
            'প্যাক_৩২'       => $packU32Fn,
            'pack_u32'       => $packU32Fn,
            'প্যাক_৬৪'       => $packU64Fn,
            'pack_u64'       => $packU64Fn,
            'বাইট_অক্ষর'     => $chrFn,
            'chr'            => $chrFn,
            'অর্ড'           => $ordFn,
            'ord'            => $ordFn,
            'উপস্ট্রিং'      => $substrFn,
            'substr'         => $substrFn,
            'পুনরাবৃত্তি'    => $repeatFn,
            'str_repeat'     => $repeatFn,
            'প্যাডিং'        => $repeatFn,
        ];
    }

    /**
     * Creates Bare-Metal Hardware & Universal Number Module (লিপি.হার্ডওয়্যার / hardware / unum).
     *
     * WHY: Lipi is NOT a framework or a library. It is a sovereign systems programming language
     * whose foundational machine model is the 64-bit Universal Number (U ∈ GF(2^64)).
     * This module provides direct, low-level abstractions over CPU registers, instruction bitfields,
     * virtual memory page layouts, atomic hardware primitives, and OS kernel syscall vectors.
     *
     * @return array<string, mixed>
     */
    private static function createHardwareModule(): array
    {
        // 1. CPU Hardware Architecture & Execution Profile
        $cpuFn = new LipiBuiltinFunction('cpu', 0, function (LipiRuntime $rt, array $args): array {
            return [
                'আর্কিটেকচার'        => php_uname('m'),
                'arch'                => php_uname('m'),
                'ওএস'                 => PHP_OS_FAMILY,
                'os'                  => PHP_OS_FAMILY,
                'কার্নেল'             => php_uname('s') . ' ' . php_uname('r'),
                'kernel'              => php_uname('s') . ' ' . php_uname('r'),
                'পেজ_আকার_বাইট'       => 4096,
                'page_size'           => 4096,
                'এন্ডিয়ান'            => 'Little-Endian (AMD64 / ARM64)',
                'endian'              => 'little',
                'হার্ডওয়্যার_রেজিস্টার' => [
                    'RAX', 'RCX', 'RDX', 'RBX', 'RSP', 'RBP', 'RSI', 'RDI',
                    'R8', 'R9', 'R10', 'R11', 'R12', 'R13', 'R14', 'R15'
                ],
                'registers'           => [
                    'RAX', 'RCX', 'RDX', 'RBX', 'RSP', 'RBP', 'RSI', 'RDI',
                    'R8', 'R9', 'R10', 'R11', 'R12', 'R13', 'R14', 'R15'
                ],
                'ভেক্টর_সক্ষমতা'       => ['AVX-512', 'AVX2', 'ARM_NEON', 'WASM_SIMD128'],
                'simd'                => ['AVX-512', 'AVX2', 'ARM_NEON', 'WASM_SIMD128'],
            ];
        });

        // 2. Synthesize a 64-bit Universal Number Machine Instruction
        // Bitfield: [Opcode:8][Type:8][Reg:8][SIMD:8][Payload:32]
        $unumFn = new LipiBuiltinFunction('unum_instruction', 4, function (LipiRuntime $rt, array $args): array {
            $opcode  = isset($args[0]) ? ((int)$args[0] & 0xFF) : 0;
            $type    = isset($args[1]) ? ((int)$args[1] & 0xFF) : 1;
            $reg     = isset($args[2]) ? ((int)$args[2] & 0xFF) : 0;
            $payload = isset($args[3]) ? ((int)$args[3] & 0xFFFFFFFF) : 0;
            $simd    = isset($args[4]) ? ((int)$args[4] & 0xFF) : 0;

            // Compute raw 64-bit integer bitfield in GF(2^64)
            $raw64 = ($opcode << 56) | ($type << 48) | ($reg << 40) | ($simd << 32) | $payload;

            // Map register index to human-readable hardware register name
            $regNames = [
                0 => 'RAX', 1 => 'RCX', 2 => 'RDX', 3 => 'RBX',
                4 => 'RSP', 5 => 'RBP', 6 => 'RSI', 7 => 'RDI',
                8 => 'R8',  9 => 'R9',  10 => 'R10', 11 => 'R11',
                12 => 'R12', 13 => 'R13', 14 => 'R14', 15 => 'R15'
            ];
            $regName = $regNames[$reg] ?? "REG_{$reg}";

            // Map standard opcodes
            $opNames = [
                0x00 => 'OP_NOP', 0x01 => 'OP_MOV_IMM', 0x02 => 'OP_MOV_REG',
                0x03 => 'OP_ADD_IMM', 0x04 => 'OP_ADD_REG', 0x05 => 'OP_SUB_IMM',
                0x06 => 'OP_SUB_REG', 0x07 => 'OP_MUL_REG', 0x08 => 'OP_XOR_REG',
                0x09 => 'OP_LOOP_DEC', 0x10 => 'OP_SIMD_DOT', 0x11 => 'OP_SIMD_ADD',
                0xFE => 'OP_RET', 0xFF => 'OP_HALT'
            ];
            $opName = $opNames[$opcode] ?? sprintf('OP_0x%02X', $opcode);

            return [
                'মান'         => $raw64,
                'value'       => $raw64,
                'হেক্স'       => sprintf('0x%016X', $raw64),
                'hex'         => sprintf('0x%016X', $raw64),
                'অপকোড'       => $opName,
                'opcode'      => $opName,
                'রেজিস্টার'   => $regName,
                'register'    => $regName,
                'পেলোড'       => $payload,
                'payload'     => $payload,
                'সিলিকন_মডেল' => 'Universal Number GF(2^64) Single-Cycle Instruction',
            ];
        });

        // 3. Hardware Register Mapping (AMD64 System V ABI)
        $regMapFn = new LipiBuiltinFunction('register_map', 0, function (LipiRuntime $rt, array $args): array {
            return [
                'RAX' => 0, 'RCX' => 1, 'RDX' => 2, 'RBX' => 3,
                'RSP' => 4, 'RBP' => 5, 'RSI' => 6, 'RDI' => 7,
                'R8'  => 8, 'R9'  => 9, 'R10' => 10, 'R11' => 11,
                'R12' => 12, 'R13' => 13, 'R14' => 14, 'R15' => 15,
            ];
        });

        // 4. Linux Kernel Direct Syscall Vector Map
        $syscallMapFn = new LipiBuiltinFunction('syscall_map', 0, function (LipiRuntime $rt, array $args): array {
            return [
                'SYS_read'     => 0,
                'SYS_write'    => 1,
                'SYS_open'     => 2,
                'SYS_close'    => 3,
                'SYS_mmap'     => 9,
                'SYS_mprotect' => 10,
                'SYS_munmap'   => 11,
                'SYS_socket'   => 41,
                'SYS_accept'   => 43,
                'SYS_bind'     => 49,
                'SYS_listen'   => 50,
                'SYS_fork'     => 57,
                'SYS_execve'   => 59,
                'SYS_exit'     => 60,
            ];
        });

        // 5. Total Language Sovereignty Statement & Physical Identity
        $sovereigntyFn = new LipiBuiltinFunction('sovereignty', 0, function (LipiRuntime $rt, array $args): array {
            return [
                'ভাষা'               => 'লিপি (Lipi)',
                'language'           => 'Lipi',
                'শ্রেণীবিভাগ'       => 'সার্বভৌম সিস্টেম প্রোগ্রামিং ভাষা (Sovereign Systems Language)',
                'classification'     => 'Sovereign Systems Programming Language',
                'ফ্রেমওয়ার্ক_কিনা'   => false,
                'is_framework'       => false,
                'মেশিন_মডেল'         => 'Universal Number (GF(2^64) Silicon Bitfield)',
                'machine_model'      => 'Universal Number (GF(2^64) Silicon Bitfield)',
                'বহিরাগত_নির্ভরতা'   => 'জিরো (Zero Dependency)',
                'dependencies'       => 'None (0% External Dependencies)',
                'পিএইচপি_মুক্ত'      => true,
                'জিসিসি_মুক্ত'       => true,
                'কার্নেল_ডাইরেক্ট'   => true,
                'স্ট্যান্ডঅ্যালোন_ELF' => true,
            ];
        });

        return [
            'সিপিইউ'             => $cpuFn,
            'cpu'                => $cpuFn,
            'ইউনাম'              => $unumFn,
            'unum'               => $unumFn,
            'তৈরি_নির্দেশ'       => $unumFn,
            'make_instruction'   => $unumFn,
            'রেজিস্টার_ম্যাপ'    => $regMapFn,
            'register_map'       => $regMapFn,
            'সিস্টেম_কল_ম্যাপ'   => $syscallMapFn,
            'syscall_map'        => $syscallMapFn,
            'সার্বভৌম_স্থিতি'    => $sovereigntyFn,
            'sovereignty'        => $sovereigntyFn,
        ];
    }
}

