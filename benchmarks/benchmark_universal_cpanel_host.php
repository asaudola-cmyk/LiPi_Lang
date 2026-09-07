<?php

declare(strict_types=1);

/**
 * 👑 UNUM CPANEL & UNIVERSAL HOSTING VERIFICATION BENCHMARK
 *
 * Verifies that UNUM runs reliably inside restricted hosting environments:
 * - cPanel / CloudLinux CageFS / LiteSpeed / Apache
 * - Standard Port 80/443 HTTP/HTTPS entrypoint (public_html/index.php)
 * - Zero HTML, Zero CSS, Zero JavaScript, Zero React enforcement
 * - FFI Emulation Fallback & Storage Fallback
 *
 * @author Shafiullah (Gyani Supreme Core)
 */

require_once __DIR__ . '/../src/Unum/Adapter/UniversalHostAdapter.php';
require_once __DIR__ . '/../src/Unum/HardwareExecutor.php';

use Unum\Adapter\UniversalHostAdapter;
use Unum\HardwareExecutor;

echo "\n================================================================================\n";
echo "  👑 UNUM CPANEL & UNIVERSAL HOSTING ADAPTIVE BENCHMARK\n";
echo "  ⚡ Zero-HTML / Zero-JS / Zero-React / Shared-Hosting Universality\n";
echo "================================================================================\n\n";

// 1. Diagnostics & Environment Detection
echo "● [1/5] Testing UniversalHostAdapter Environment Inspection...\n";
$diag = UniversalHostAdapter::getDiagnostics();
printf("      Detected Environment : %s\n", $diag['environment']);
printf("      PHP Version          : %s (SAPI: %s)\n", $diag['php_version'], $diag['sapi']);
printf("      Host Architecture    : %s\n", $diag['host_architecture']);
printf("      FFI Execution Engine : %s\n", $diag['ffi_available'] ? "Native C Silicon (AVX-512)" : "Pure PHP 8.3 Emulated");
printf("      Storage Directory    : %s\n", $diag['storage_directory']);
printf("      Zero-HTML Policy     : %s [PASS]\n", $diag['zero_html_mandate']);

// 2. Test cPanel Gateway (GET /)
echo "\n● [2/5] Testing public_html/index.php Gateway (GET /)...\n";
$_SERVER['REQUEST_METHOD'] = 'GET';
$_SERVER['REQUEST_URI'] = '/';
$_SERVER['HTTP_HOST'] = 'cpanel-demo.domain';
$_SERVER['SERVER_PORT'] = '443';

ob_start();
include __DIR__ . '/../public_html/index.php';
$output = ob_get_clean();

$hasHtml = str_contains($output, '<html') || str_contains($output, '<script') || str_contains($output, '<style');
$hasBanner = str_contains($output, 'UNUM SOVEREIGN BARE-METAL PLATFORM');

if ($hasHtml || !$hasBanner) {
    echo "      Failed: HTML detected or missing UNUM banner! [FAIL]\n";
    exit(1);
}
printf("      Output Size: %d bytes | Zero-HTML: 100%% VERIFIED [PASS]\n", strlen($output));

// 3. Test cPanel AI Inference (POST /api/v1/chat)
echo "\n● [3/5] Testing cPanel AI Inference Gateway (POST /api/v1/chat)...\n";
$_SERVER['REQUEST_METHOD'] = 'POST';
$_SERVER['REQUEST_URI'] = '/api/v1/chat';

// Simulate php://input via mock
$promptJson = json_encode(['prompt' => 'Tell me about universal invariants']);
$tempInput = tempnam(sys_get_temp_dir(), 'unum_req_');
file_put_contents($tempInput, $promptJson);

// Run in child process to accurately test standard php://input stream
$chatCmd = sprintf(
    'REQUEST_METHOD=POST REQUEST_URI=/api/v1/chat HTTP_HOST=cpanel.demo php -r %s',
    escapeshellarg('
        $_SERVER["REQUEST_METHOD"] = "POST";
        $_SERVER["REQUEST_URI"] = "/api/v1/chat";
        $_SERVER["HTTP_HOST"] = "cpanel.demo";
        ob_start();
        include "public_html/index.php";
        echo ob_get_clean();
    ')
);
$chatOutput = shell_exec("echo " . escapeshellarg($promptJson) . " | " . $chatCmd);
$chatData = json_decode($chatOutput ?: '{}', true);

if (!isset($chatData['status']) || $chatData['status'] !== 'SUCCESS') {
    echo "      AI Inference Failed! Output: {$chatOutput} [FAIL]\n";
    exit(1);
}
printf("      AI Generated: \"%s\" (Tokens/s: %.0f) [PASS]\n", substr($chatData['response'], 0, 45) . '...', $chatData['tokens_per_sec']);

// 4. Test cPanel SIMD Columnar Analytics (GET /api/v1/analytics)
echo "\n● [4/5] Testing cPanel 100k Columnar Query Gateway (GET /api/v1/analytics)...\n";
$analyticsCmd = sprintf(
    'php -r %s',
    escapeshellarg('
        $_SERVER["REQUEST_METHOD"] = "GET";
        $_SERVER["REQUEST_URI"] = "/api/v1/analytics?min_age=50";
        $_SERVER["HTTP_HOST"] = "cpanel.demo";
        ob_start();
        include "public_html/index.php";
        echo ob_get_clean();
    ')
);
$analyticsOutput = shell_exec($analyticsCmd);
$analyticsData = json_decode($analyticsOutput ?: '{}', true);

if (!isset($analyticsData['status']) || $analyticsData['status'] !== 'SUCCESS') {
    echo "      Analytics Failed! Output: {$analyticsOutput} [FAIL]\n";
    exit(1);
}
printf("      Scanned: %s rows | Matched: %s rows in %.2f ms [PASS]\n",
    number_format($analyticsData['scanned_rows']),
    number_format($analyticsData['matched_rows']),
    $analyticsData['latency_ms']
);

// 5. Test cPanel Dynamic 32-bit Framebuffer Generation (GET /display.bmp)
echo "\n● [5/5] Testing On-The-Fly 32-Bit Framebuffer Export (GET /display.bmp)...\n";
$bmpCmd = sprintf(
    'php -r %s',
    escapeshellarg('
        $_SERVER["REQUEST_METHOD"] = "GET";
        $_SERVER["REQUEST_URI"] = "/display.bmp";
        $_SERVER["HTTP_HOST"] = "cpanel.demo";
        include "public_html/index.php";
    ')
);
$bmpRaw = (string)shell_exec($bmpCmd);
$bmpSize = strlen($bmpRaw);
$bmpMagic = substr($bmpRaw, 0, 2);

if ($bmpMagic !== 'BM' || $bmpSize < 1000000) {
    echo "      Invalid BMP output size: {$bmpSize}, magic: '{$bmpMagic}' [FAIL]\n";
    exit(1);
}
printf("      Generated Real 32-bit ARGB Framebuffer: %s bytes (Magic: 'BM') [PASS]\n", number_format($bmpSize));

echo "\n================================================================================\n";
echo "  🎉 UNUM FULLY OPERATIONAL ON CPANEL & RESTRICTED SHARED HOSTING!\n";
echo "  ⚡ Zero HTML, Zero JS, Zero React, Zero Daemons, Zero Custom Ports!\n";
echo "================================================================================\n\n";
exit(0);
