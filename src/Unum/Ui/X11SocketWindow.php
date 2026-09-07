<?php

declare(strict_types=1);

namespace Unum\Ui;

/**
 * X11SocketWindow — Pure Unix Domain Socket Direct X11 Protocol Client.
 *
 * ZERO BROWSER, ZERO ELECTRON, ZERO GTK, ZERO QT, ZERO XLIB, ZERO XCB.
 *
 * Direct silicon wire protocol:
 * - Connects to Linux Unix Domain Socket `/tmp/.X11-unix/X0` via PHP native streams.
 * - Implements RFC-compliant X11 Wire Protocol directly in byte-level silicon packets:
 *   * Handshake & Screen discovery (Opcode 0)
 *   * CreateWindow (Opcode 1)
 *   * ChangeProperty for WM_NAME title (Opcode 18)
 *   * MapWindow (Opcode 8)
 *   * CreateGC (Opcode 55)
 *   * PutImage with automatic strip segmentation (Opcode 72)
 *   * Non-blocking 32-byte event polling (KeyPress, ButtonPress, Expose)
 *
 * @author Shafiullah (Gyani Supreme Core)
 */
class X11SocketWindow
{
    /** @var resource|null */
    protected $socket = null;

    protected string $socketPath;
    protected int $width;
    protected int $height;
    protected string $title;

    protected int $resourceBase = 0;
    protected int $resourceMask = 0;
    protected int $resourceCounter = 1;

    protected int $rootWindow = 0;
    protected int $rootVisual = 0;
    protected int $rootDepth = 24;

    protected int $windowId = 0;
    protected int $gcId = 0;

    protected bool $isMapped = false;
    protected bool $running = false;

    public function __construct(
        int $width = 640,
        int $height = 480,
        string $title = 'UNUM Sovereign Bare-Metal Silicon Window',
        ?string $display = null
    ) {
        $this->width = $width;
        $this->height = $height;
        $this->title = $title;

        $disp = $display ?? (getenv('DISPLAY') ?: ':0');
        if (preg_match('/:(\d+)/', $disp, $m)) {
            $dispNum = (int)$m[1];
        } else {
            $dispNum = 0;
        }

        $this->socketPath = "unix:///tmp/.X11-unix/X{$dispNum}";
    }

    /**
     * Connects to the X11 server and performs the initial wire handshake.
     */
    public function connect(): bool
    {
        $errno = 0;
        $errstr = '';
        $this->socket = @stream_socket_client($this->socketPath, $errno, $errstr, 2.0);

        if (!$this->socket) {
            return false;
        }

        // Send Setup Request: Little-Endian ('l'), Version 11.0, 0 auth
        $setupPkt = pack('CCvvvvv', ord('l'), 0, 11, 0, 0, 0, 0);
        fwrite($this->socket, $setupPkt);

        // Read 8-byte setup reply header
        $header = fread($this->socket, 8);
        if (strlen($header) < 8) {
            $this->close();
            return false;
        }

        $un = unpack('Cstatus/Cunused/vmajor/vminor/vlen', $header);
        if ($un['status'] !== 1) { // 1 = Success
            $this->close();
            return false;
        }

        // Read body: len * 4 bytes
        $body = '';
        $toRead = $un['len'] * 4;
        while (strlen($body) < $toRead) {
            $chunk = fread($this->socket, $toRead - strlen($body));
            if ($chunk === false || $chunk === '') {
                break;
            }
            $body .= $chunk;
        }

        if (strlen($body) < 32) {
            $this->close();
            return false;
        }

        // Parse fixed body parameters
        $fixed = unpack(
            'Vrelease/Vbase/Vmask/Vmotion/vvendor_len/vmax_req/Croots/Cpixmap_formats/Cbyte_order/Cbit_order/Cscanline_unit/Cscanline_pad/Cmin_kc/Cmax_kc/Vunused',
            substr($body, 0, 32)
        );

        $this->resourceBase = $fixed['base'];
        $this->resourceMask = $fixed['mask'];

        $vendorLen = $fixed['vendor_len'];
        $padVendor = ($vendorLen + 3) & ~3;
        $offset = 32 + $padVendor + ($fixed['pixmap_formats'] * 8);

        // Parse first screen structure
        $screen = unpack(
            'Vroot/Vcolormap/Vwhite/Vblack/Vinput_masks/vwidth/vheight/vwidth_mm/vheight_mm/vmin_maps/vmax_maps/Vroot_visual/Cbacking/Csave_unders/Cdepth/Cdepths_len',
            substr($body, $offset, 40)
        );

        $this->rootWindow = $screen['root'];
        $this->rootVisual = $screen['root_visual'];
        $this->rootDepth = $screen['depth'];

        // Set socket to non-blocking for high-FPS polling
        stream_set_blocking($this->socket, false);

        return true;
    }

    /**
     * Allocates a unique 32-bit X11 Resource ID.
     */
    protected function allocateId(): int
    {
        return $this->resourceBase | (($this->resourceCounter++) & $this->resourceMask);
    }

    /**
     * Creates the native window, graphics context, and maps it to the screen.
     */
    public function createWindow(): bool
    {
        if (!$this->socket) {
            return false;
        }

        $this->windowId = $this->allocateId();
        $this->gcId = $this->allocateId();

        // 1. CreateWindow (Opcode 1)
        // Value-Mask: CWBackPixel (0x0002) | CWEventMask (0x0800)
        $valMask = 0x0002 | 0x0800;
        $backPixel = 0x000D1117; // Dark slate background
        // ExposureMask (0x8000) | KeyPressMask (0x0001) | ButtonPressMask (0x0004) | StructureNotifyMask (0x00020000)
        $eventMask = 0x8000 | 0x0001 | 0x0004 | 0x00020000;

        $reqBody = pack('VVvvvvvvVV', $this->windowId, $this->rootWindow, 100, 100, $this->width, $this->height, 0, 1, 0, $valMask)
                 . pack('VV', $backPixel, $eventMask);
        $lenWords = 1 + (int)(strlen($reqBody) / 4);
        $createWinPkt = pack('CCv', 1, 0, $lenWords) . $reqBody;
        fwrite($this->socket, $createWinPkt);

        // 2. Set Window Title: ChangeProperty (Opcode 18)
        // WM_NAME atom = 39, STRING atom = 31, format = 8
        $this->setWindowTitle($this->title);

        // 3. CreateGC (Opcode 55)
        $gcPkt = pack('CCvVVV', 55, 0, 4, $this->gcId, $this->windowId, 0);
        fwrite($this->socket, $gcPkt);

        // 4. MapWindow (Opcode 8)
        $mapPkt = pack('CCvV', 8, 0, 2, $this->windowId);
        fwrite($this->socket, $mapPkt);

        $this->isMapped = true;
        return true;
    }

    /**
     * Sets the window manager title bar text via ChangeProperty (Opcode 18).
     */
    public function setWindowTitle(string $title): void
    {
        if (!$this->socket || $this->windowId === 0) {
            return;
        }

        $titleLen = strlen($title);
        $pad = (4 - ($titleLen % 4)) % 4;
        $paddedTitle = $title . str_repeat("\0", $pad);
        $lenWords = 6 + (int)(strlen($paddedTitle) / 4);

        // ChangeProperty: mode 0 (Replace), window, property 39 (WM_NAME), type 31 (STRING), format 8, numElements = titleLen
        $pkt = pack('CCvVVVVV', 18, 0, $lenWords, $this->windowId, 39, 31, 8, $titleLen) . $paddedTitle;
        fwrite($this->socket, $pkt);
    }

    /**
     * Blits a PixelCanvas ARGB framebuffer directly to the native X11 window.
     * Uses automatic strip segmentation to adhere to standard X11 max packet size (65,535 words).
     */
    public function blitCanvas(PixelCanvas $canvas): void
    {
        if (!$this->socket || $this->windowId === 0) {
            return;
        }

        $w = min($this->width, $canvas->width);
        $h = min($this->height, $canvas->height);

        // Compute max scanlines per PutImage packet to stay within 65,000 words
        // Header is 6 words. Max payload words = 65000. Each row is (w * 4) bytes = w words.
        $maxRows = max(1, (int)floor(64000 / $w));

        for ($y = 0; $y < $h; $y += $maxRows) {
            $stripH = min($maxRows, $h - $y);

            $pixels = '';
            for ($sy = 0; $sy < $stripH; ++$sy) {
                $canvasY = $y + $sy;
                for ($sx = 0; $sx < $w; ++$sx) {
                    $color = $canvas->getPixel($sx, $canvasY);
                    $b = $color & 0xFF;
                    $g = ($color >> 8) & 0xFF;
                    $r = ($color >> 16) & 0xFF;
                    $a = ($color >> 24) & 0xFF;
                    $pixels .= chr($b) . chr($g) . chr($r) . chr($a);
                }
            }

            $pad = (4 - (strlen($pixels) % 4)) % 4;
            if ($pad > 0) {
                $pixels .= str_repeat("\0", $pad);
            }

            $putImgLen = 6 + (int)(strlen($pixels) / 4);
            // PutImage: opcode 72, format 2 (ZPixmap), depth 24
            $putPkt = pack('CCvVVvvvvCCvv', 72, 2, $putImgLen, $this->windowId, $this->gcId, $w, $stripH, 0, $y, 0, 24, 0, 0)
                    . $pixels;

            fwrite($this->socket, $putPkt);
        }
    }

    /**
     * Polls for incoming X11 server events (non-blocking).
     *
     * @return array<int, array{type: int, raw: string}>
     */
    public function pollEvents(): array
    {
        if (!$this->socket) {
            return [];
        }

        $events = [];
        while (true) {
            $raw = @fread($this->socket, 32);
            if ($raw === false || strlen($raw) < 32) {
                break;
            }

            $eventType = ord($raw[0]) & 0x7F; // Top bit indicates synthetic event
            $events[] = ['type' => $eventType, 'raw' => $raw];
        }

        return $events;
    }

    /**
     * Closes the socket connection and releases resources.
     */
    public function close(): void
    {
        if ($this->socket) {
            @fclose($this->socket);
            $this->socket = null;
        }
        $this->isMapped = false;
        $this->running = false;
    }

    public function __destruct()
    {
        $this->close();
    }
}
