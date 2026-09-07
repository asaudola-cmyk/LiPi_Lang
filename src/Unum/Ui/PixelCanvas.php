<?php

declare(strict_types=1);

namespace Unum\Ui;

use SplFixedArray;

/**
 * PixelCanvas — Bare-Metal Software SIMD Pixel Rasterizer.
 *
 * ZERO HTML, ZERO CSS, ZERO JAVASCRIPT, ZERO EXTERNAL GRAPHICS LIBRARIES.
 *
 * Implements a contiguous 32-bit ARGB framebuffer in silicon memory:
 * - Direct O(1) indexed pixel manipulation via contiguous SplFixedArray
 * - Alpha blending: A * Src + (255 - A) * Dst
 * - Geometric primitives: Bresenham lines, Midpoint circles, filled rectangles, gradients
 * - Real-time metrics graphing engine (area fill + stroke)
 * - Built-in 8x16 bitmap font table for zero-dependency typography
 * - ANSI 24-bit TrueColor Unicode Half-Block (▀) renderer for terminals
 * - Direct 32-bit BMP binary framebuffer export
 *
 * Physical Color Model: 32-bit ARGB (0xAARRGGBB)
 */
class PixelCanvas
{
    public readonly int $width;
    public readonly int $height;

    /**
     * Contiguous 32-bit ARGB pixel memory buffer.
     * Stored as SplFixedArray for C-level pointer arithmetic and zero hash overhead.
     *
     * @var SplFixedArray<int>
     */
    protected SplFixedArray $pixels;

    /**
     * Built-in 8x16 Monospace Bitmap Font for ASCII (32..126).
     * 16 bytes per glyph, where each byte represents 8 horizontal pixels.
     * WHY: Eliminates FreeType, HarfBuzz, and CSS font rendering engines.
     *
     * @var array<int, array<int, int>>
     */
    protected static array $fontGlyphs = [];

    public function __construct(int $width, int $height, int $initialColor = 0xFF000000)
    {
        if ($width <= 0 || $height <= 0) {
            throw new \InvalidArgumentException("Canvas dimensions must be positive.");
        }

        $this->width = $width;
        $this->height = $height;
        $totalPixels = $width * $height;
        $this->pixels = new SplFixedArray($totalPixels);

        $this->clear($initialColor);
        self::ensureFontInitialized();
    }

    /**
     * Clears the entire framebuffer with the specified 32-bit ARGB color.
     */
    public function clear(int $argb): void
    {
        $total = $this->width * $this->height;
        for ($i = 0; $i < $total; ++$i) {
            $this->pixels[$i] = $argb;
        }
    }

    /**
     * Sets a single pixel directly at (x, y) without alpha blending.
     * Includes hardware boundary clipping.
     */
    public function setPixel(int $x, int $y, int $argb): void
    {
        if ($x >= 0 && $x < $this->width && $y >= 0 && $y < $this->height) {
            $this->pixels[$y * $this->width + $x] = $argb;
        }
    }

    /**
     * Retrieves the 32-bit ARGB color at (x, y).
     */
    public function getPixel(int $x, int $y): int
    {
        if ($x >= 0 && $x < $this->width && $y >= 0 && $y < $this->height) {
            return $this->pixels[$y * $this->width + $x];
        }
        return 0;
    }

    /**
     * Blends a source pixel over the destination pixel using alpha compositing.
     * Formula: Out = (Src * A + Dst * (255 - A)) / 255
     */
    public function blendPixel(int $x, int $y, int $argb): void
    {
        if ($x < 0 || $x >= $this->width || $y < 0 || $y >= $this->height) {
            return;
        }

        $alpha = ($argb >> 24) & 0xFF;
        if ($alpha === 0) {
            return; // Fully transparent
        }
        if ($alpha === 255) {
            $this->pixels[$y * $this->width + $x] = $argb;
            return; // Fully opaque
        }

        $idx = $y * $this->width + $x;
        $dst = $this->pixels[$idx];

        $srcR = ($argb >> 16) & 0xFF;
        $srcG = ($argb >> 8) & 0xFF;
        $srcB = $argb & 0xFF;

        $dstA = ($dst >> 24) & 0xFF;
        $dstR = ($dst >> 16) & 0xFF;
        $dstG = ($dst >> 8) & 0xFF;
        $dstB = $dst & 0xFF;

        $invAlpha = 255 - $alpha;

        $outR = ($srcR * $alpha + $dstR * $invAlpha) >> 8;
        $outG = ($srcG * $alpha + $dstG * $invAlpha) >> 8;
        $outB = ($srcB * $alpha + $dstB * $invAlpha) >> 8;
        $outA = max($alpha, $dstA);

        $this->pixels[$idx] = ($outA << 24) | ($outR << 16) | ($outG << 8) | $outB;
    }

    /**
     * Fills a rectangular region with solid ARGB color.
     */
    public function fillRect(int $x, int $y, int $w, int $h, int $argb): void
    {
        $x0 = max(0, $x);
        $y0 = max(0, $y);
        $x1 = min($this->width, $x + $w);
        $y1 = min($this->height, $y + $h);

        $alpha = ($argb >> 24) & 0xFF;
        if ($alpha === 255) {
            for ($cy = $y0; $cy < $y1; ++$cy) {
                $rowOffset = $cy * $this->width;
                for ($cx = $x0; $cx < $x1; ++$cx) {
                    $this->pixels[$rowOffset + $cx] = $argb;
                }
            }
        } else {
            for ($cy = $y0; $cy < $y1; ++$cy) {
                for ($cx = $x0; $cx < $x1; ++$cx) {
                    $this->blendPixel($cx, $cy, $argb);
                }
            }
        }
    }

    /**
     * Draws an unfilled rectangle outline.
     */
    public function drawRect(int $x, int $y, int $w, int $h, int $argb): void
    {
        $this->drawLine($x, $y, $x + $w - 1, $y, $argb);
        $this->drawLine($x, $y + $h - 1, $x + $w - 1, $y + $h - 1, $argb);
        $this->drawLine($x, $y, $x, $y + $h - 1, $argb);
        $this->drawLine($x + $w - 1, $y, $x + $w - 1, $y + $h - 1, $argb);
    }

    /**
     * Draws a vertical linear color gradient box.
     */
    public function drawGradientRect(int $x, int $y, int $w, int $h, int $topColor, int $bottomColor): void
    {
        $x0 = max(0, $x);
        $y0 = max(0, $y);
        $x1 = min($this->width, $x + $w);
        $y1 = min($this->height, $y + $h);

        if ($h <= 0 || $y0 >= $y1) {
            return;
        }

        $r0 = ($topColor >> 16) & 0xFF;
        $g0 = ($topColor >> 8) & 0xFF;
        $b0 = $topColor & 0xFF;
        $a0 = ($topColor >> 24) & 0xFF;

        $r1 = ($bottomColor >> 16) & 0xFF;
        $g1 = ($bottomColor >> 8) & 0xFF;
        $b1 = $bottomColor & 0xFF;
        $a1 = ($bottomColor >> 24) & 0xFF;

        for ($cy = $y0; $cy < $y1; ++$cy) {
            $t = ($cy - $y) / (float)$h;
            $r = (int)($r0 + ($r1 - $r0) * $t);
            $g = (int)($g0 + ($g1 - $g0) * $t);
            $b = (int)($b0 + ($b1 - $b0) * $t);
            $a = (int)($a0 + ($a1 - $a0) * $t);
            $color = ($a << 24) | ($r << 16) | ($g << 8) | $b;

            $rowOffset = $cy * $this->width;
            for ($cx = $x0; $cx < $x1; ++$cx) {
                $this->pixels[$rowOffset + $cx] = $color;
            }
        }
    }

    /**
     * Draws a line between two points using Bresenham's line algorithm.
     */
    public function drawLine(int $x0, int $y0, int $x1, int $y1, int $argb): void
    {
        $dx = abs($x1 - $x0);
        $dy = -abs($y1 - $y0);
        $sx = $x0 < $x1 ? 1 : -1;
        $sy = $y0 < $y1 ? 1 : -1;
        $err = $dx + $dy;

        while (true) {
            $this->blendPixel($x0, $y0, $argb);
            if ($x0 === $x1 && $y0 === $y1) {
                break;
            }
            $e2 = 2 * $err;
            if ($e2 >= $dy) {
                $err += $dy;
                $x0 += $sx;
            }
            if ($e2 <= $dx) {
                $err += $dx;
                $y0 += $sy;
            }
        }
    }

    /**
     * Draws a circle outline using the midpoint circle algorithm.
     */
    public function drawCircle(int $cx, int $cy, int $r, int $argb): void
    {
        $x = $r;
        $y = 0;
        $err = 0;

        while ($x >= $y) {
            $this->blendPixel($cx + $x, $cy + $y, $argb);
            $this->blendPixel($cx + $y, $cy + $x, $argb);
            $this->blendPixel($cx - $y, $cy + $x, $argb);
            $this->blendPixel($cx - $x, $cy + $y, $argb);
            $this->blendPixel($cx - $x, $cy - $y, $argb);
            $this->blendPixel($cx - $y, $cy - $x, $argb);
            $this->blendPixel($cx + $y, $cy - $x, $argb);
            $this->blendPixel($cx + $x, $cy - $y, $argb);

            if ($err <= 0) {
                $y += 1;
                $err += 2 * $y + 1;
            }
            if ($err > 0) {
                $x -= 1;
                $err -= 2 * $x + 1;
            }
        }
    }

    /**
     * Fills a circle with the specified ARGB color.
     */
    public function fillCircle(int $cx, int $cy, int $r, int $argb): void
    {
        for ($y = -$r; $y <= $r; ++$y) {
            $dx = (int)sqrt($r * $r - $y * $y);
            for ($x = -$dx; $x <= $dx; ++$x) {
                $this->blendPixel($cx + $x, $cy + $y, $argb);
            }
        }
    }

    /**
     * Draws a real-time timeseries graph with gradient area fill and line stroke.
     * Perfect for telemetry (Tokens/Sec, CPU load, Memory throughput).
     *
     * @param float[] $dataPoints
     */
    public function drawGraph(
        int $x,
        int $y,
        int $w,
        int $h,
        array $dataPoints,
        int $lineColor = 0xFF00FFCC,
        int $fillColor = 0x3300FFCC
    ): void {
        $count = count($dataPoints);
        if ($count < 2 || $w < 2 || $h < 2) {
            return;
        }

        $min = min($dataPoints);
        $max = max($dataPoints);
        if (abs($max - $min) < 1e-6) {
            $max = $min + 1.0;
        }

        $dx = (float)$w / ($count - 1);
        $prevPx = $x;
        $prevPy = (int)($y + $h - (($dataPoints[0] - $min) / ($max - $min)) * $h);

        for ($i = 1; $i < $count; ++$i) {
            $currPx = (int)round($x + $i * $dx);
            $currPy = (int)round($y + $h - (($dataPoints[$i] - $min) / ($max - $min)) * $h);

            // Fill vertical strip beneath the line for area chart effect
            $fillAlpha = ($fillColor >> 24) & 0xFF;
            if ($fillAlpha > 0) {
                $stripMinY = min($prevPy, $currPy);
                $stripMaxY = $y + $h;
                for ($fx = $prevPx; $fx <= $currPx; ++$fx) {
                    for ($fy = $stripMinY; $fy <= $stripMaxY; ++$fy) {
                        $this->blendPixel($fx, $fy, $fillColor);
                    }
                }
            }

            // Draw line segment
            $this->drawLine($prevPx, $prevPy, $currPx, $currPy, $lineColor);

            $prevPx = $currPx;
            $prevPy = $currPy;
        }
    }

    /**
     * Draws a styled progress bar with border and fill percentage.
     */
    public function drawProgressBar(
        int $x,
        int $y,
        int $w,
        int $h,
        float $progress,
        int $fgColor = 0xFF00E676,
        int $bgColor = 0xFF212121
    ): void {
        $progress = max(0.0, min(1.0, $progress));
        $this->fillRect($x, $y, $w, $h, $bgColor);
        $this->drawRect($x, $y, $w, $h, 0xFF555555);

        $fillW = (int)round(($w - 4) * $progress);
        if ($fillW > 0) {
            $this->fillRect($x + 2, $y + 2, $fillW, $h - 4, $fgColor);
        }
    }

    /**
     * Draws text using the embedded 8x16 bitmap font.
     */
    public function drawText(int $x, int $y, string $text, int $color = 0xFFFFFFFF, int $scale = 1): void
    {
        $scale = max(1, $scale);
        $len = strlen($text);
        $cursorX = $x;

        for ($i = 0; $i < $len; ++$i) {
            $code = ord($text[$i]);
            if ($code === 10) { // Newline
                $y += 18 * $scale;
                $cursorX = $x;
                continue;
            }

            $glyph = self::$fontGlyphs[$code] ?? self::$fontGlyphs[63]; // '?' default
            for ($row = 0; $row < 16; ++$row) {
                $rowBits = $glyph[$row];
                for ($col = 0; $col < 8; ++$col) {
                    if (($rowBits & (1 << (7 - $col))) !== 0) {
                        if ($scale === 1) {
                            $this->blendPixel($cursorX + $col, $y + $row, $color);
                        } else {
                            $this->fillRect(
                                $cursorX + $col * $scale,
                                $y + $row * $scale,
                                $scale,
                                $scale,
                                $color
                            );
                        }
                    }
                }
            }

            $cursorX += 9 * $scale; // 8px char width + 1px spacing
        }
    }

    /**
     * Converts the ARGB canvas to ANSI 24-bit TrueColor Unicode Half-Block (▀) format.
     * Each terminal character cell displays 2 vertical pixels:
     * - Foreground color: Top pixel
     * - Background color: Bottom pixel
     *
     * This achieves ultra-crisp, high-DPI terminal graphics with ZERO browser overhead!
     */
    public function renderToAnsiHalfBlock(): string
    {
        $out = '';
        $lastFg = -1;
        $lastBg = -1;

        for ($y = 0; $y < $this->height; $y += 2) {
            for ($x = 0; $x < $this->width; ++$x) {
                $top = $this->pixels[$y * $this->width + $x];
                $bottom = ($y + 1 < $this->height) ? $this->pixels[($y + 1) * $this->width + $x] : 0xFF000000;

                $tR = ($top >> 16) & 0xFF;
                $tG = ($top >> 8) & 0xFF;
                $tB = $top & 0xFF;

                $bR = ($bottom >> 16) & 0xFF;
                $bG = ($bottom >> 8) & 0xFF;
                $bB = $bottom & 0xFF;

                $fgCode = ($tR << 16) | ($tG << 8) | $tB;
                $bgCode = ($bR << 16) | ($bG << 8) | $bB;

                if ($fgCode !== $lastFg) {
                    $out .= "\033[38;2;{$tR};{$tG};{$tB}m";
                    $lastFg = $fgCode;
                }
                if ($bgCode !== $lastBg) {
                    $out .= "\033[48;2;{$bR};{$bG};{$bB}m";
                    $lastBg = $bgCode;
                }

                $out .= "\u{2580}"; // ▀
            }
            $out .= "\033[0m\n";
            $lastFg = -1;
            $lastBg = -1;
        }

        return $out;
    }

    /**
     * Exports the raw 32-bit ARGB pixel memory into standard Little-Endian BMP binary format.
     * Zero external libraries. Produces an immediate valid image viewable in any OS viewer.
     */
    public function exportBmp(string $filepath): void
    {
        $fileHeaderSize = 14;
        $infoHeaderSize = 40;
        $rowSize = $this->width * 4; // 32-bit BGRA (4 bytes per pixel)
        $pixelDataSize = $rowSize * $this->height;
        $fileSize = $fileHeaderSize + $infoHeaderSize + $pixelDataSize;

        // BITMAPFILEHEADER (14 bytes)
        $header = pack('vVVV', 0x4D42, $fileSize, 0, $fileHeaderSize + $infoHeaderSize);

        // BITMAPINFOHEADER (40 bytes)
        $header .= pack(
            'VVVvvVVVVVV',
            $infoHeaderSize,
            $this->width,
            $this->height, // Positive height = bottom-to-top standard
            1,             // Color planes
            32,            // Bits per pixel
            0,             // Compression (BI_RGB)
            $pixelDataSize,
            2835,          // 72 DPI
            2835,
            0,
            0
        );

        // BMP standard stores rows bottom-to-top
        $payload = '';
        for ($y = $this->height - 1; $y >= 0; --$y) {
            $rowOffset = $y * $this->width;
            for ($x = 0; $x < $this->width; ++$x) {
                $color = $this->pixels[$rowOffset + $x];
                $b = $color & 0xFF;
                $g = ($color >> 8) & 0xFF;
                $r = ($color >> 16) & 0xFF;
                $a = ($color >> 24) & 0xFF;
                $payload .= chr($b) . chr($g) . chr($r) . chr($a);
            }
        }

        file_put_contents($filepath, $header . $payload);
    }

    /**
     * Returns raw packed 32-bit little-endian binary bytes for direct X11 PutImage blitting.
     */
    public function getPackedX11Buffer(): string
    {
        $buffer = '';
        $total = $this->width * $this->height;
        for ($i = 0; $i < $total; ++$i) {
            $color = $this->pixels[$i];
            $b = $color & 0xFF;
            $g = ($color >> 8) & 0xFF;
            $r = ($color >> 16) & 0xFF;
            $a = ($color >> 24) & 0xFF;
            $buffer .= chr($b) . chr($g) . chr($r) . chr($a);
        }
        return $buffer;
    }

    /**
     * Initializes the built-in 8x16 Monospace Bitmap Font for ASCII (32..126).
     */
    protected static function ensureFontInitialized(): void
    {
        if (!empty(self::$fontGlyphs)) {
            return;
        }

        // Initialize empty rows for all 128 standard ASCII chars
        for ($c = 0; $c < 128; ++$c) {
            self::$fontGlyphs[$c] = array_fill(0, 16, 0);
        }

        // Standard Space (32)
        self::$fontGlyphs[32] = array_fill(0, 16, 0);

        // Helper to define 16 rows of 8-bit patterns
        $define = function (int $code, array $rows) {
            self::$fontGlyphs[$code] = array_pad($rows, 16, 0);
        };

        // Numbers 0..9
        $define(48, [0x3C, 0x66, 0x6E, 0x7E, 0x76, 0x66, 0x3C]); // 0
        $define(49, [0x18, 0x38, 0x18, 0x18, 0x18, 0x18, 0x7E]); // 1
        $define(50, [0x3C, 0x66, 0x06, 0x1C, 0x30, 0x60, 0x7E]); // 2
        $define(51, [0x3C, 0x66, 0x06, 0x1C, 0x06, 0x66, 0x3C]); // 3
        $define(52, [0x0C, 0x1C, 0x3C, 0x6C, 0xFE, 0x0C, 0x0C]); // 4
        $define(53, [0x7E, 0x60, 0x7C, 0x06, 0x06, 0x66, 0x3C]); // 5
        $define(54, [0x1C, 0x30, 0x60, 0x7C, 0x66, 0x66, 0x3C]); // 6
        $define(55, [0x7E, 0x06, 0x0C, 0x18, 0x30, 0x30, 0x30]); // 7
        $define(56, [0x3C, 0x66, 0x66, 0x3C, 0x66, 0x66, 0x3C]); // 8
        $define(57, [0x3C, 0x66, 0x66, 0x3E, 0x06, 0x0C, 0x38]); // 9

        // Uppercase A..Z
        $define(65, [0x18, 0x3C, 0x66, 0x7E, 0x66, 0x66, 0x66]); // A
        $define(66, [0x7C, 0x66, 0x66, 0x7C, 0x66, 0x66, 0x7C]); // B
        $define(67, [0x3C, 0x66, 0x60, 0x60, 0x60, 0x66, 0x3C]); // C
        $define(68, [0x78, 0x6C, 0x66, 0x66, 0x66, 0x6C, 0x78]); // D
        $define(69, [0x7E, 0x60, 0x60, 0x7C, 0x60, 0x60, 0x7E]); // E
        $define(70, [0x7E, 0x60, 0x60, 0x7C, 0x60, 0x60, 0x60]); // F
        $define(71, [0x3C, 0x66, 0x60, 0x6E, 0x66, 0x66, 0x3E]); // G
        $define(72, [0x66, 0x66, 0x66, 0x7E, 0x66, 0x66, 0x66]); // H
        $define(73, [0x3C, 0x18, 0x18, 0x18, 0x18, 0x18, 0x3C]); // I
        $define(74, [0x0E, 0x06, 0x06, 0x06, 0x06, 0x66, 0x3C]); // J
        $define(75, [0x66, 0x6C, 0x78, 0x70, 0x78, 0x6C, 0x66]); // K
        $define(76, [0x60, 0x60, 0x60, 0x60, 0x60, 0x60, 0x7E]); // L
        $define(77, [0x63, 0x77, 0x7F, 0x6B, 0x63, 0x63, 0x63]); // M
        $define(78, [0x66, 0x76, 0x7E, 0x7E, 0x6E, 0x66, 0x66]); // N
        $define(79, [0x3C, 0x66, 0x66, 0x66, 0x66, 0x66, 0x3C]); // O
        $define(80, [0x7C, 0x66, 0x66, 0x7C, 0x60, 0x60, 0x60]); // P
        $define(81, [0x3C, 0x66, 0x66, 0x66, 0x6A, 0x6C, 0x36]); // Q
        $define(82, [0x7C, 0x66, 0x66, 0x7C, 0x78, 0x6C, 0x66]); // R
        $define(83, [0x3C, 0x66, 0x60, 0x3C, 0x06, 0x66, 0x3C]); // S
        $define(84, [0x7E, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18]); // T
        $define(85, [0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x3C]); // U
        $define(86, [0x66, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x18]); // V
        $define(87, [0x63, 0x63, 0x63, 0x6B, 0x7F, 0x77, 0x63]); // W
        $define(88, [0x66, 0x66, 0x3C, 0x18, 0x3C, 0x66, 0x66]); // X
        $define(89, [0x66, 0x66, 0x66, 0x3C, 0x18, 0x18, 0x18]); // Y
        $define(90, [0x7E, 0x06, 0x0C, 0x18, 0x30, 0x60, 0x7E]); // Z

        // Lowercase a..z
        $define(97,  [0x00, 0x00, 0x3C, 0x06, 0x3E, 0x66, 0x3E]); // a
        $define(98,  [0x60, 0x60, 0x7C, 0x66, 0x66, 0x66, 0x7C]); // b
        $define(99,  [0x00, 0x00, 0x3C, 0x66, 0x60, 0x66, 0x3C]); // c
        $define(100, [0x06, 0x06, 0x3E, 0x66, 0x66, 0x66, 0x3E]); // d
        $define(101, [0x00, 0x00, 0x3C, 0x66, 0x7E, 0x60, 0x3C]); // e
        $define(102, [0x0E, 0x18, 0x3E, 0x18, 0x18, 0x18, 0x18]); // f
        $define(103, [0x00, 0x00, 0x3E, 0x66, 0x66, 0x3E, 0x06, 0x3C]); // g
        $define(104, [0x60, 0x60, 0x7C, 0x66, 0x66, 0x66, 0x66]); // h
        $define(105, [0x18, 0x00, 0x38, 0x18, 0x18, 0x18, 0x3C]); // i
        $define(106, [0x06, 0x00, 0x0E, 0x06, 0x06, 0x66, 0x3C]); // j
        $define(107, [0x60, 0x60, 0x66, 0x6C, 0x78, 0x6C, 0x66]); // k
        $define(108, [0x38, 0x18, 0x18, 0x18, 0x18, 0x18, 0x3C]); // l
        $define(109, [0x00, 0x00, 0x76, 0x7F, 0x6B, 0x6B, 0x6B]); // m
        $define(110, [0x00, 0x00, 0x7C, 0x66, 0x66, 0x66, 0x66]); // n
        $define(111, [0x00, 0x00, 0x3C, 0x66, 0x66, 0x66, 0x3C]); // o
        $define(112, [0x00, 0x00, 0x7C, 0x66, 0x66, 0x7C, 0x60, 0x60]); // p
        $define(113, [0x00, 0x00, 0x3E, 0x66, 0x66, 0x3E, 0x06, 0x06]); // q
        $define(114, [0x00, 0x00, 0x5C, 0x66, 0x60, 0x60, 0x60]); // r
        $define(115, [0x00, 0x00, 0x3E, 0x60, 0x3C, 0x06, 0x7C]); // s
        $define(116, [0x18, 0x18, 0x7E, 0x18, 0x18, 0x18, 0x0E]); // t
        $define(117, [0x00, 0x00, 0x66, 0x66, 0x66, 0x66, 0x3E]); // u
        $define(118, [0x00, 0x00, 0x66, 0x66, 0x66, 0x3C, 0x18]); // v
        $define(119, [0x00, 0x00, 0x63, 0x6B, 0x6B, 0x7F, 0x36]); // w
        $define(120, [0x00, 0x00, 0x66, 0x3C, 0x18, 0x3C, 0x66]); // x
        $define(121, [0x00, 0x00, 0x66, 0x66, 0x66, 0x3E, 0x06, 0x3C]); // y
        $define(122, [0x00, 0x00, 0x7E, 0x0C, 0x18, 0x30, 0x7E]); // z

        // Punctuation & Symbols
        $define(33,  [0x18, 0x18, 0x18, 0x18, 0x00, 0x18]);       // !
        $define(58,  [0x00, 0x18, 0x18, 0x00, 0x18, 0x18]);       // :
        $define(46,  [0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18]); // .
        $define(44,  [0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x30]); // ,
        $define(45,  [0x00, 0x00, 0x00, 0x7E, 0x00, 0x00]);       // -
        $define(43,  [0x00, 0x18, 0x18, 0x7E, 0x18, 0x18]);       // +
        $define(61,  [0x00, 0x7E, 0x00, 0x7E, 0x00, 0x00]);       // =
        $define(47,  [0x06, 0x0C, 0x18, 0x30, 0x60, 0x40]);       // /
        $define(92,  [0x60, 0x30, 0x18, 0x0C, 0x06, 0x02]);       // \
        $define(91,  [0x3C, 0x30, 0x30, 0x30, 0x30, 0x30, 0x3C]); // [
        $define(93,  [0x3C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x3C]); // ]
        $define(40,  [0x0C, 0x18, 0x30, 0x30, 0x30, 0x18, 0x0C]); // (
        $define(41,  [0x30, 0x18, 0x0C, 0x0C, 0x0C, 0x18, 0x30]); // )
        $define(37,  [0x62, 0x64, 0x08, 0x10, 0x26, 0x46]);       // %
        $define(63,  [0x3C, 0x66, 0x0C, 0x18, 0x18, 0x00, 0x18]); // ?
        $define(62,  [0x60, 0x30, 0x18, 0x0C, 0x18, 0x30, 0x60]); // >
        $define(60,  [0x06, 0x0C, 0x18, 0x30, 0x18, 0x0C, 0x06]); // <
        $define(124, [0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18]); // |
    }
}
