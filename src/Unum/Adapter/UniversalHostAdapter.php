<?php

declare(strict_types=1);

namespace Unum\Adapter;

use Unum\CrossIsa\UniversalTarget;

require_once __DIR__ . '/../CrossIsa/UniversalTarget.php';

/**
 * UniversalHostAdapter — Adaptive Hosting Environment Inspector & Bridge.
 *
 * Automatically adapts the UNUM Sovereign Ecosystem to run universally on:
 * 1. Bare-Metal Dedicated Silicon / VPS (Root, FFI, AVX-512, raw sockets, 60 FPS TUI)
 * 2. Restricted Shared Hosting / cPanel / LiteSpeed / Apache / CloudLinux CageFS
 * 3. Serverless / Containerized Environments (Docker, Kubernetes, AWS Lambda)
 *
 * WHY: On cPanel and shared hosting, root access is absent, port binding is firewalled,
 * and background daemons get killed. UniversalHostAdapter allows UNUM to operate
 * seamlessly over standard HTTP(S) port 80/443, using local mmap fallbacks and pure
 * 64-bit PHP arithmetic while maintaining ZERO HTML, ZERO JS, ZERO REACT.
 *
 * @author Shafiullah (Gyani Supreme Core)
 */
class UniversalHostAdapter
{
    public const ENV_BARE_METAL = 'BARE_METAL';
    public const ENV_CPANEL_SHARED = 'CPANEL_SHARED';
    public const ENV_CONTAINER = 'CONTAINER';

    /**
     * Detects the execution environment category.
     */
    public static function detectEnvironment(): string
    {
        $isCli = (PHP_SAPI === 'cli' || PHP_SAPI === 'phpdbg');

        // Check for cPanel / Shared Hosting markers
        if (!$isCli || isset($_SERVER['HTTP_HOST']) || isset($_SERVER['SERVER_SOFTWARE'])) {
            return self::ENV_CPANEL_SHARED;
        }

        if (getenv('CPANEL') !== false || file_exists('/usr/local/cpanel')) {
            return self::ENV_CPANEL_SHARED;
        }

        // Check if running in Docker / Container
        if (file_exists('/.dockerenv') || file_exists('/run/.containerenv')) {
            return self::ENV_CONTAINER;
        }

        return self::ENV_BARE_METAL;
    }

    /**
     * Checks if FFI is available and allowed by php.ini security policy.
     */
    public static function isFfiAvailable(): bool
    {
        if (!extension_loaded('ffi') || !class_exists('\FFI')) {
            return false;
        }

        $ffiEnable = ini_get('ffi.enable');
        if ($ffiEnable === '0' || strtolower($ffiEnable) === 'false') {
            return false;
        }

        // Under web SAPIs (Apache/FPM), ffi.enable is often 'preload' which forbids dynamic CDEF
        if (PHP_SAPI !== 'cli' && $ffiEnable === 'preload') {
            return false;
        }

        return true;
    }

    /**
     * Checks if POSIX /dev/shm is writable.
     */
    public static function isDevShmWritable(): bool
    {
        if (!file_exists('/dev/shm') || !is_dir('/dev/shm') || !is_writable('/dev/shm')) {
            return false;
        }

        // Test creating a temporary test file in /dev/shm
        $testFile = '/dev/shm/unum_test_' . getmypid() . '.tmp';
        $written = @file_put_contents($testFile, '1');
        if ($written === false) {
            return false;
        }
        @unlink($testFile);

        return true;
    }

    /**
     * Checks if process has permission to bind arbitrary custom TCP ports.
     */
    public static function canBindCustomPorts(): bool
    {
        if (PHP_SAPI !== 'cli') {
            return false; // Web SAPIs (cPanel/Apache) should route through Port 80/443
        }

        $sock = @stream_socket_server('tcp://127.0.0.1:0', $errno, $errstr);
        if (!$sock) {
            return false;
        }
        @fclose($sock);
        return true;
    }

    /**
     * Returns a safe writable storage directory for in-memory state fallbacks.
     * Guaranteed to work on cPanel, CageFS, and shared hosts.
     */
    public static function getSafeStorageDir(): string
    {
        if (self::isDevShmWritable()) {
            return '/dev/shm';
        }

        $sysTemp = sys_get_temp_dir();
        if (is_writable($sysTemp)) {
            $dir = $sysTemp . '/unum_storage';
            if (!is_dir($dir)) {
                @mkdir($dir, 0777, true);
            }
            return $dir;
        }

        $localDir = dirname(__DIR__, 3) . '/.unum_state';
        if (!is_dir($localDir)) {
            @mkdir($localDir, 0777, true);
        }
        return $localDir;
    }

    /**
     * Generates a comprehensive hosting diagnostics report.
     *
     * @return array<string, mixed>
     */
    public static function getDiagnostics(): array
    {
        return [
            'environment'         => self::detectEnvironment(),
            'php_version'         => PHP_VERSION,
            'sapi'                => PHP_SAPI,
            'host_architecture'   => UniversalTarget::detectHost(),
            'ffi_available'       => self::isFfiAvailable(),
            'dev_shm_writable'    => self::isDevShmWritable(),
            'can_bind_ports'      => self::canBindCustomPorts(),
            'storage_directory'   => self::getSafeStorageDir(),
            'memory_limit'        => ini_get('memory_limit'),
            'max_execution_time'  => ini_get('max_execution_time'),
            'zero_html_mandate'   => 'ACTIVE (Zero HTML, Zero JS, Zero React)',
        ];
    }
}
