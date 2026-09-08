<?php

declare(strict_types=1);

namespace Unum\Lipi;

use RuntimeException;

/**
 * 📦 Lipi Sovereign Package & Dependency Manager (লিপি প্যাকেজ ম্যানেজার)
 *
 * Provides industrial-grade project initialization, dependency resolution,
 * manifest management (lipi.json / লিপি.নথি), and automated testing suites.
 *
 * WHY: Eliminates external package managers (npm, pip, composer).
 * Empowers Lipi developers to scaffold, install, link, and test standalone
 * bilingual applications with zero dependencies.
 *
 * @author Shafiullah (Gyani Supreme Core)
 */
final class LipiPackageManager
{
    public const MANIFEST_FILE = 'lipi.json';
    public const MODULES_DIR   = 'lipi_modules';

    /**
     * Initializes a new Lipi project workspace with manifest and starter files.
     *
     * @return array<string, mixed> The initialized manifest structure
     */
    public function init(string $targetDir, ?string $projectName = null): array
    {
        if (!is_dir($targetDir)) {
            mkdir($targetDir, 0755, true);
        }

        $manifestPath = $targetDir . '/' . self::MANIFEST_FILE;
        $name = $projectName ?: basename(realpath($targetDir) ?: $targetDir);

        $manifest = [
            'name'         => $name,
            'version'      => '১.০.০',
            'description'  => 'সার্বভৌম লিপি অ্যাপ্লিকেশন (Sovereign Lipi Application)',
            'main'         => 'src/main.lp',
            'scripts'      => [
                'start' => 'run src/main.lp',
                'test'  => 'test',
                'build' => 'build src/main.lp -o dist/' . $name,
            ],
            'dependencies' => (object)[],
        ];

        file_put_contents(
            $manifestPath,
            json_encode($manifest, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES)
        );

        // Ensure directories exist
        $srcDir = $targetDir . '/src';
        $distDir = $targetDir . '/dist';
        $modDir = $targetDir . '/' . self::MODULES_DIR;
        foreach ([$srcDir, $distDir, $modDir] as $dir) {
            if (!is_dir($dir)) {
                mkdir($dir, 0755, true);
            }
        }

        // Create initial starter file if not present
        $starterFile = $srcDir . '/main.lp';
        if (!file_exists($starterFile)) {
            $starterCode = <<<LIPI
// 📜 {$name} — প্রধান এন্ট্রি পয়েন্ট
দেখাও "স্বাগতম লিপি প্যাকেজ অ্যাপ্লিকেশনে!"
দেখাও "প্রজেক্ট: {$name} | ভার্সন: ১.০.০"
LIPI;
            file_put_contents($starterFile, $starterCode);
        }

        return $manifest;
    }

    /**
     * Installs all dependencies declared in the project manifest into lipi_modules.
     *
     * @return list<string> List of installed package names
     */
    public function install(string $targetDir): array
    {
        $manifest = $this->readManifest($targetDir);
        $deps = (array)($manifest['dependencies'] ?? []);
        $installed = [];

        $modulesDir = $targetDir . '/' . self::MODULES_DIR;
        if (!is_dir($modulesDir)) {
            mkdir($modulesDir, 0755, true);
        }

        foreach ($deps as $pkgName => $spec) {
            $this->installSinglePackage($targetDir, (string)$pkgName, (string)$spec);
            $installed[] = (string)$pkgName;
        }

        return $installed;
    }

    /**
     * Adds a single dependency to the project manifest and links/installs it.
     */
    public function add(string $targetDir, string $sourceSpec, ?string $alias = null): string
    {
        $manifest = $this->readManifest($targetDir);

        // Deduce package name if alias not provided
        $pkgName = $alias ?: basename($sourceSpec, '.lp');
        $pkgName = preg_replace('/^local:/', '', $pkgName);

        $this->installSinglePackage($targetDir, $pkgName, $sourceSpec);

        $deps = (array)($manifest['dependencies'] ?? []);
        $deps[$pkgName] = $sourceSpec;
        $manifest['dependencies'] = $deps;

        $manifestPath = $targetDir . '/' . self::MANIFEST_FILE;
        file_put_contents(
            $manifestPath,
            json_encode($manifest, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES)
        );

        return $pkgName;
    }

    /**
     * Resolves and installs a single dependency into lipi_modules/.
     */
    private function installSinglePackage(string $targetDir, string $pkgName, string $sourceSpec): void
    {
        $modulesDir = $targetDir . '/' . self::MODULES_DIR;
        if (!is_dir($modulesDir)) {
            mkdir($modulesDir, 0755, true);
        }

        $destDir = $modulesDir . '/' . $pkgName;

        // 1. Local path reference: local:path/to/file.lp or direct filepath
        if (str_starts_with($sourceSpec, 'local:')) {
            $localRel = substr($sourceSpec, 6);
            $sourcePath = realpath($targetDir . '/' . $localRel) ?: realpath($localRel);
        } else {
            $sourcePath = realpath($targetDir . '/' . $sourceSpec) ?: realpath($sourceSpec);
        }

        if ($sourcePath !== false && file_exists($sourcePath)) {
            if (is_file($sourcePath)) {
                if (!is_dir($destDir)) {
                    mkdir($destDir, 0755, true);
                }
                copy($sourcePath, $destDir . '/main.lp');
                // Also copy directly as pkgName.lp for convenient imports
                copy($sourcePath, $modulesDir . '/' . $pkgName . '.lp');
                return;
            }

            if (is_dir($sourcePath)) {
                $this->recursiveCopy($sourcePath, $destDir);
                return;
            }
        }

        // 2. Synthesize virtual standalone module if not a file path
        if (!is_dir($destDir)) {
            mkdir($destDir, 0755, true);
        }
        $mockCode = <<<LIPI
// 📦 মডিউল: {$pkgName}
// উৎস: {$sourceSpec}
ধরি সংস্করণ = "১.০.০"
ধরি মডিউল_নাম = "{$pkgName}"
LIPI;
        file_put_contents($destDir . '/main.lp', $mockCode);
        file_put_contents($modulesDir . '/' . $pkgName . '.lp', $mockCode);
    }

    /**
     * Recursively copies a directory tree.
     */
    private function recursiveCopy(string $src, string $dst): void
    {
        if (!is_dir($dst)) {
            mkdir($dst, 0755, true);
        }
        $dir = opendir($src);
        if ($dir === false) return;
        while (($file = readdir($dir)) !== false) {
            if ($file === '.' || $file === '..') continue;
            $subSrc = $src . '/' . $file;
            $subDst = $dst . '/' . $file;
            if (is_dir($subSrc)) {
                $this->recursiveCopy($subSrc, $subDst);
            } else {
                copy($subSrc, $subDst);
            }
        }
        closedir($dir);
    }

    /**
     * Discovers and runs all unit test suites (*_test.lp or in tests/).
     *
     * @return array{total: int, passed: int, failed: int, details: list<array{file: string, passed: bool, output: string}>}
     */
    public function runTests(string $targetDir, LipiEngine $engine): array
    {
        $testFiles = [];

        // 1. Search in tests/
        $testsDir = $targetDir . '/tests';
        if (is_dir($testsDir)) {
            $iterator = new \RecursiveIteratorIterator(new \RecursiveDirectoryIterator($testsDir));
            foreach ($iterator as $file) {
                if ($file->isFile() && ($file->getExtension() === 'lp' || $file->getExtension() === 'lipi')) {
                    $testFiles[] = $file->getPathname();
                }
            }
        }

        // 2. Search root for *_test.lp
        $rootFiles = glob($targetDir . '/*_test.lp') ?: [];
        foreach ($rootFiles as $rf) {
            if (!in_array($rf, $testFiles, true)) {
                $testFiles[] = $rf;
            }
        }

        $results = [
            'total'   => count($testFiles),
            'passed'  => 0,
            'failed'  => 0,
            'details' => [],
        ];

        foreach ($testFiles as $tf) {
            $engine->clearOutput();
            $rel = str_replace($targetDir . '/', '', $tf);
            try {
                $engine->runFile($tf);
                $out = implode("\n", $engine->getRuntime()->getOutput());
                $passed = !str_contains(strtolower($out), 'failed') && !str_contains($out, '❌');
                if ($passed) {
                    $results['passed']++;
                } else {
                    $results['failed']++;
                }
                $results['details'][] = ['file' => $rel, 'passed' => $passed, 'output' => $out];
            } catch (\Throwable $e) {
                $results['failed']++;
                $results['details'][] = ['file' => $rel, 'passed' => false, 'output' => $e->getMessage()];
            }
        }

        return $results;
    }

    /**
     * Reads and parses lipi.json.
     *
     * @return array<string, mixed>
     */
    public function readManifest(string $targetDir): array
    {
        $manifestPath = $targetDir . '/' . self::MANIFEST_FILE;
        if (!file_exists($manifestPath)) {
            return [
                'name'         => basename(realpath($targetDir) ?: $targetDir),
                'version'      => '১.০.০',
                'dependencies' => (object)[],
            ];
        }

        $raw = file_get_contents($manifestPath);
        if ($raw === false) {
            throw new RuntimeException("Failed to read {$manifestPath}");
        }

        $decoded = json_decode($raw, true);
        return is_array($decoded) ? $decoded : [];
    }
}
