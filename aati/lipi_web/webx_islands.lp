// ==============================================================================
// 👑 LIPI WEBX SOVEREIGN CLIENT-SIDE ISLANDS ARCHITECTURE & RUNTIME
// Module: aati/lipi_web/webx_islands.lp
// Milestone: Sovereign Full-Stack Paradigm (Zero React Hydration Lag & Overhead)
// 100% Pure LiPi Implementation — Zero External / Node.js / Framework Dependencies
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Traditional Single Page Applications (Next.js, Nuxt, Remix) force full-page JS
//    hydration, downloading megabytes of JavaScript runtime to re-render server HTML.
// 2. This causes massive Total Blocking Time (TBT), First Input Delay (FID), and memory churn.
//
// LIPI WEBX SOVEREIGN ISLANDS SOLUTION:
// - Sovereign Islands: 99% of page renders as static pure HTML5; only isolated dynamic
//   widgets ("islands") load JavaScript on demand.
// - Autonomous Activation: Each island emits its own self-contained activation script
//   triggering via IntersectionObserver (when visible), idle callback, or media query.
// - Lightweight Sovereign Island Runtime (webx_island_script): Under 1 KB (< 1024 bytes)
//   centralized coordinator with zero external framework dependencies.
// ==============================================================================

include "utso/string.lp"
include "utso/collections.lp"
include "aati/lipi_web/esm_assimilator.lp"
include "aati/lipi_web/webx_primitives.lp"

fn webx_escape_attr s
    // WHY: Escapes HTML attribute values so arbitrary JSON props or strings
    // can be safely serialized inside data-props="..." without breaking DOM attribute parsing.
    // Handles double quotes, ampersands, angle brackets, apostrophes, and ASCII CR/LF to preserve JSON structure.
    if s == 0 return "" end
    slen = len(s)
    out = ""
    i = 0
    while i < slen
        ch = char_at(s, i)
        c = ord(ch)
        if c == 34 // "
            out = out + "&quot;"
        elif c == 38 // &
            out = out + "&amp;"
        elif c == 60 // <
            out = out + "&lt;"
        elif c == 62 // >
            out = out + "&gt;"
        elif c == 39 // '
            out = out + "&#39;"
        elif c == 10 // \n
            out = out + "&#10;"
        elif c == 13 // \r
            out = out + "&#13;"
        else
            out = out + ch
        end
        i = i + 1
    end
    return out

fn webx_island_container_with_strategy island_id client_module mount_selector initial_props fallback_html strategy
    // WHY: Renders an isolated HTML container marked with sovereign island metadata attributes:
    // data-webx-island="true", data-module="...", data-mount="...", data-strategy="...", data-props="..."
    escaped_props = webx_escape_attr(initial_props)
    out = "<div id=\"" + island_id + "\" class=\"webx-island\" data-webx-island=\"true\" data-module=\"" + client_module + "\""
    if len(mount_selector) > 0
        out = out + " data-mount=\"" + mount_selector + "\""
    end
    if len(strategy) > 0 and strategy != "visible"
        out = out + " data-strategy=\"" + strategy + "\""
    end
    out = out + " data-props=\"" + escaped_props + "\">\n"
    if len(fallback_html) > 0
        out = out + "  " + fallback_html + "\n"
    end
    out = out + "</div>"
    return out

fn webx_island_container island_id client_module mount_selector initial_props fallback_html
    // WHY: Renders isolated HTML container with default visible strategy.
    return webx_island_container_with_strategy(island_id, client_module, mount_selector, initial_props, fallback_html, "visible")

fn webx_island_activation_script island_id client_module mount_selector strategy
    // WHY: Emits autonomous client-side activation script that lazy-loads and mounts
    // the module when visible (IntersectionObserver) or on idle/media query.
    // Locks hydration synchronously before async dynamic import to eliminate race conditions.
    act = "<script type=\"module\">\n"
    act = act + "(function() {\n"
    act = act + "  const el = document.getElementById(\"" + island_id + "\");\n"
    act = act + "  if (!el || el.hasAttribute(\"data-webx-hydrated\")) return;\n"
    act = act + "  const init = async () => {\n"
    act = act + "    if (el.hasAttribute(\"data-webx-hydrated\")) return;\n"
    act = act + "    el.setAttribute(\"data-webx-hydrated\", \"true\");\n"
    act = act + "    try {\n"
    act = act + "      const mod = await import(\"" + client_module + "\");\n"
    if len(mount_selector) > 0
        act = act + "      const target = el.querySelector(\"" + mount_selector + "\") || el;\n"
    else
        act = act + "      const target = el;\n"
    end
    act = act + "      let props = {};\n"
    act = act + "      const raw = el.getAttribute(\"data-props\");\n"
    act = act + "      if (raw && raw.length > 0) {\n"
    act = act + "        try { props = JSON.parse(raw); } catch (_) { props = raw; }\n"
    act = act + "      }\n"
    act = act + "      const mountFn = mod.mount || (typeof mod.default === \"function\" ? mod.default : mod.default && mod.default.mount) || mod.init;\n"
    act = act + "      if (typeof mountFn === \"function\") await mountFn(target, props);\n"
    act = act + "    } catch (e) {\n"
    act = act + "      console.error(\"[WebX Island] Activation failed for " + client_module + ":\", e);\n"
    act = act + "    }\n"
    act = act + "  };\n"
    act = act + "  const run = () => (\"requestIdleCallback\" in window) ? requestIdleCallback(init) : setTimeout(init, 1);\n"

    if str_starts_with(strategy, "media:") == 1
        q = str_slice(strategy, 6, len(strategy))
        act = act + "  const mq = window.matchMedia(\"" + q + "\");\n"
        act = act + "  if (mq.matches) run();\n"
        act = act + "  else mq.addEventListener(\"change\", () => { if (mq.matches) run(); }, { once: true });\n"
    elif strategy == "idle"
        act = act + "  run();\n"
    elif strategy == "load"
        act = act + "  if (document.readyState === \"complete\") run(); else window.addEventListener(\"load\", run, { once: true });\n"
    else
        // Default: visible (IntersectionObserver with 200px rootMargin pre-activation)
        act = act + "  if (\"IntersectionObserver\" in window) {\n"
        act = act + "    const obs = new IntersectionObserver((entries, o) => {\n"
        act = act + "      for (const entry of entries) {\n"
        act = act + "        if (entry.isIntersecting) { o.disconnect(); run(); }\n"
        act = act + "      }\n"
        act = act + "    }, { rootMargin: \"200px\" });\n"
        act = act + "    obs.observe(el);\n"
        act = act + "  } else {\n"
        act = act + "    run();\n"
        act = act + "  }\n"
    end
    act = act + "})();\n"
    act = act + "</script>"
    return act

fn webx_island_with_strategy island_id client_module mount_selector initial_props fallback_html strategy
    // WHY: Renders isolated HTML container marked with data attributes
    // AND emits autonomous client-side activation script configured for the specified strategy.
    c = webx_island_container_with_strategy(island_id, client_module, mount_selector, initial_props, fallback_html, strategy)
    act = webx_island_activation_script(island_id, client_module, mount_selector, strategy)
    return c + "\n" + act

fn webx_island island_id client_module mount_selector initial_props fallback_html
    // WHY: Canonical sovereign island renderer.
    // 1. Renders isolated HTML container marked with data attributes (data-webx-island="true", data-module, data-props).
    // 2. Emits autonomous activation script that lazy-loads and mounts when visible (IntersectionObserver).
    return webx_island_with_strategy(island_id, client_module, mount_selector, initial_props, fallback_html, "visible")

fn webx_island_script
    // WHY: Emits lightweight sovereign client-side loader runtime (under 1 KB, zero external framework runtime).
    // Centralized island hydration coordinator scanning document for [data-webx-island="true"].
    // Includes race-condition lock, DOMContentLoaded hook, non-clobbering listeners, and safe JSON fallback.
    s = "<script type=\"module\">(()=>{let H=async e=>{if(e.getAttribute(\"data-webx-hydrated\"))return;e.setAttribute(\"data-webx-hydrated\",1);let m=e.dataset.module;if(!m)return;try{let M=await import(m),t=(e.dataset.mount&&e.querySelector(e.dataset.mount))||e,p={};try{p=JSON.parse(e.dataset.props)}catch(_){}let f=M.mount||M.default?.mount||M.default||M.init;typeof f==\"function\"&&await f(t,p)}catch(e){console.error(m,e)}},S=e=>{let s=e.dataset.strategy||\"\",R=()=>(\"requestIdleCallback\"in window?requestIdleCallback:setTimeout)(()=>H(e),1);s[0]==\"m\"?(q=matchMedia(s.slice(6))).matches?R():q.onchange=()=>q.matches&&R():s==\"idle\"?R():s==\"load\"?document.readyState[0]==\"c\"?R():addEventListener(\"load\",R,{once:1}):window.IntersectionObserver?new IntersectionObserver(([x],o)=>{x.isIntersecting&&(o.disconnect(),R())}).observe(e):R()},A=window.__webx_hydrate_islands=()=>document.querySelectorAll(\"[data-webx-island]\").forEach(S);document.readyState[0]==\"l\"?addEventListener(\"DOMContentLoaded\",A,{once:1}):A()})();</script>"
    return s

fn webx_island_node island_id client_module mount_selector initial_props fallback_html
    // WHY: Wraps sovereign island in a WebXNode for declarative layout composition
    html_markup = webx_island(island_id, client_module, mount_selector, initial_props, fallback_html)
    return webx_raw(island_id + "_node", html_markup)

fn webx_render_island_page title body_html esm_modules_list class_tokens
    // WHY: Assembles full-stack sovereign HTML document featuring:
    // - Inlined Zero-CSS atomic rules
    // - Sovereign local W3C <script type="importmap">
    // - Pre-rendered Island containers
    // - Under-1KB Client-Side Islands Runtime
    css = webx_compile_classes(class_tokens)
    import_map = webx_generate_offline_importmap(esm_modules_list)
    island_runtime = webx_island_script()

    page = "<!DOCTYPE html>\n"
    page = page + "<html lang=\"en\">\n"
    page = page + "<head>\n"
    page = page + "  <meta charset=\"UTF-8\">\n"
    page = page + "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n"
    page = page + "  <title>" + title + "</title>\n"
    page = page + "  <style>\n"
    page = page + "    * { box-sizing: border-box; margin: 0; padding: 0; }\n"
    page = page + "    body { font-family: system-ui, sans-serif; background: #0b0f19; color: #f1f5f9; }\n"
    page = page + css
    page = page + "  </style>\n"
    page = page + "  " + import_map + "\n"
    page = page + "</head>\n"
    page = page + "<body>\n"
    page = page + "  <div id=\"app-root\">\n"
    page = page + body_html + "\n"
    page = page + "  </div>\n"
    page = page + "  " + island_runtime + "\n"
    page = page + "</body>\n"
    page = page + "</html>"
    return page
