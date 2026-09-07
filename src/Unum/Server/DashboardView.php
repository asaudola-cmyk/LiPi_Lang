<?php

declare(strict_types=1);

namespace Unum\Server;

/**
 * DashboardView: Sovereign Terminal & Telemetry View (Zero HTML / Zero JS).
 *
 * NOTE: All HTML, CSS, JavaScript, and React dependencies have been completely
 * eradicated in favor of pure silicon remote streams and direct ANSI TrueColor consoles.
 *
 * @author Shafiullah (Gyani Supreme Core)
 */
final class DashboardView
{
    /**
     * Renders pure ANSI/Plain-Text Sovereign Telemetry.
     * ZERO HTML tags, ZERO CSS, ZERO JavaScript, ZERO React.
     */
    public static function render(): string
    {
        return SovereignTerminalView::renderAnsiDashboard();
    }
}
