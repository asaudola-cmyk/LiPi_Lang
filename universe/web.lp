// ==============================================================================
// 👑 LIPI UNIVERSE WEB — GRAND UMBRELLA PRELUDE (universe/web.lp)
// ⚡ 100% Pure Sovereign Lipi Machine Code Engine | Zero C | Zero External Tools
// ==============================================================================
//
// WHY: Provides a single, clean gateway for web application development.
// Developers can simply write:
//     import "universe/web"
// to access HTTP routers, app containers, middleware pipelines, fast URL parsers,
// and polymorphic epoll/multi-threaded server dispatchers.
// ==============================================================================

import "universe/web/url"
import "universe/web/router"
import "universe/web/context"
import "universe/web/middleware"
import "universe/web/server"
import "universe/web/app"
import "universe/web/markup_parser"
import "universe/web/engine"

// ── Web Application Factory ───────────────────────────────────────────────────
// WHY: Creates a new sovereign web application instance with default routes.
@fn lipi_web_new()
    return web_app_create()
@end

@fn লিপি_নতুন_ওয়েব()
    return lipi_web_new()
@end

// ── Quick Listen and Serve Helper ─────────────────────────────────────────────
// WHY: Boots the high-performance HTTP server on the designated TCP port.
@fn lipi_web_serve(app, port)
    return web_listen_and_serve(app, port)
@end

@fn লিপি_ওয়েব_সার্ভ(অ্যাপ, পোর্ট)
    return lipi_web_serve(অ্যাপ, পোর্ট)
@end
