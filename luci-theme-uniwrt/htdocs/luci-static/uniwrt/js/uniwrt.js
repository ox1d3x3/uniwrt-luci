/*
 * luci-theme-uniwrt  —  shell behaviour
 * SPDX-License-Identifier: MIT
 *
 * LuCI renders most of its chrome client-side, so the top menu may not exist
 * at DOMContentLoaded. This script waits for it (observer + short poll),
 * relocates it into a fixed left rail, and adds a floating top bar with a
 * collapse toggle and a light/dark switch. If the menu can't be found it
 * degrades gracefully: dark mode + all CSS styling still apply, and the
 * native top navigation is left in place (the CSS only hides it once the
 * rail has actually been built).
 */
(function () {
  "use strict";

  var KEY_THEME = "uniwrt:theme";   // "light" | "dark" | "" (=auto)
  var KEY_RAIL  = "uniwrt:rail";    // "collapsed" | ""

  /* ---- icons (Lucide-style, label-keyed) ---- */
  var I = {
    status:   'M3 12h4l3 8 4-16 3 8h4',
    overview: 'M3 12h4l3 8 4-16 3 8h4',
    system:   'M12 15a3 3 0 100-6 3 3 0 000 6zM19.4 13a7.8 7.8 0 000-2l2-1.5-2-3.5-2.4 1a8 8 0 00-1.7-1l-.4-2.5h-4l-.4 2.5a8 8 0 00-1.7 1l-2.4-1-2 3.5L4.6 11a7.8 7.8 0 000 2l-2 1.5 2 3.5 2.4-1a8 8 0 001.7 1l.4 2.5h4l.4-2.5a8 8 0 001.7-1l2.4 1 2-3.5z',
    services: 'M20 7h-9M14 17H5M17 17a3 3 0 100-6 3 3 0 000 6zM7 13a3 3 0 100-6 3 3 0 000 6z',
    network:  'M5 9V5h4M15 5h4v4M19 15v4h-4M9 19H5v-4M9 9h6v6H9z',
    wifi:     'M5 13a10 10 0 0114 0M8.5 16.5a5 5 0 017 0M12 20h.01',
    vpn:      'M12 2l8 4v6c0 5-3.5 8-8 10-4.5-2-8-5-8-10V6z',
    firewall: 'M12 2l8 4v6c0 5-3.5 8-8 10-4.5-2-8-5-8-10V6z',
    statistics:'M3 3v18h18M7 14l3-4 3 3 4-6',
    logout:   'M16 17l5-5-5-5M21 12H9M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4',
    "default":'M4 6h16M4 12h16M4 18h16'
  };

  function svg(path) {
    return '<svg class="nav-ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" ' +
           'stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
           '<path d="' + path + '"/></svg>';
  }
  function iconFor(label) {
    var t = (label || "").toLowerCase();
    for (var k in I) if (k !== "default" && t.indexOf(k) !== -1) return svg(I[k]);
    if (t.indexOf("log") === 0 || t.indexOf("logout") !== -1) return svg(I.logout);
    return svg(I["default"]);
  }
  // un-classed icons for the top-bar buttons (sized via .uniwrt-iconbtn svg)
  function bsvg(inner) {
    return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" ' +
      'stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
      inner + '</svg>';
  }
  var ICON_MENU = bsvg('<path d="M4 6h16M4 12h16M4 18h16"/>');
  var ICON_SUN  = bsvg('<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>');
  var ICON_MOON = bsvg('<path d="M21 12.8A9 9 0 1 1 11.2 3 7 7 0 0 0 21 12.8z"/>');
  function ls(get, k, v) {
    try { return get ? localStorage.getItem(k) : localStorage.setItem(k, v); }
    catch (e) { return null; }
  }

  /* ---- dark mode ---- */
  function applyTheme(mode) {
    var h = document.documentElement;
    if (mode === "dark" || mode === "light") h.setAttribute("data-theme", mode);
    else h.removeAttribute("data-theme");
  }
  function currentMode() {
    var saved = ls(true, KEY_THEME);
    if (saved === "dark" || saved === "light") return saved;
    return window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches
      ? "dark" : "light";
  }
  function toggleTheme() {
    var next = currentMode() === "dark" ? "light" : "dark";
    ls(false, KEY_THEME, next); applyTheme(next); paintThemeBtn(next);
  }
  function paintThemeBtn(mode) {
    var b = document.getElementById("uniwrt-theme-btn"); if (!b) return;
    b.innerHTML = (mode === "dark") ? ICON_SUN : ICON_MOON;
    b.title = (mode === "dark") ? "Switch to light mode" : "Switch to dark mode";
  }

  /* ---- find LuCI's main menu (varies a little by version) ---- */
  function findMenu() {
    var sel = ["#mainmenu", "#topmenu", ".main-left .nav", "header .nav",
               ".main > .main-left", "nav.nav", "#menubar ul"];
    for (var i = 0; i < sel.length; i++) {
      var el = document.querySelector(sel[i]);
      if (el && el.querySelectorAll("a").length >= 2) return el;
    }
    return null;
  }

  function buildRail(menu) {
    if (document.querySelector(".uniwrt-sidebar")) return; // already built
    var body = document.body;

    /* gather top-level links */
    var links = [];
    var items = menu.querySelectorAll(":scope > li > a, :scope > a, li > a");
    var seen = {};
    items.forEach(function (a) {
      var href = a.getAttribute("href") || "";
      var label = (a.textContent || "").trim();
      if (!label || seen[href + label]) return;
      seen[href + label] = 1;
      links.push({ href: href, label: label, active: a.classList.contains("active") ||
        (a.parentElement && a.parentElement.classList.contains("active")) });
    });
    if (links.length < 2) return;

    /* sidebar */
    var aside = document.createElement("aside");
    aside.className = "uniwrt-sidebar";
    var navHtml = links.map(function (l) {
      return '<li><a href="' + l.href + '"' + (l.active ? ' class="active"' : '') + '>' +
             iconFor(l.label) + '<span class="nav-label">' +
             l.label.replace(/&/g, "&amp;").replace(/</g, "&lt;") + '</span></a></li>';
    }).join("");

    aside.innerHTML =
      '<div class="uniwrt-brand">' +
        '<img src="/luci-static/uniwrt/logo.svg" alt="" onerror="this.style.display=\'none\'">' +
        '<span class="brand-text">UniWRT</span>' +
      '</div>' +
      '<nav class="uniwrt-nav"><ul>' + navHtml + '</ul></nav>' +
      '<div class="uniwrt-rail-foot">OpenWrt &middot; LuCI</div>';

    /* top bar */
    var bar = document.createElement("div");
    bar.className = "uniwrt-topbar";
    var pageTitle = document.title.split(" - ")[0] || "Dashboard";
    bar.innerHTML =
      '<button class="uniwrt-iconbtn" id="uniwrt-collapse" title="Toggle menu">' +
        ICON_MENU + '</button>' +
      '<span class="crumb">' + pageTitle.replace(/</g, "&lt;") + '</span>' +
      '<span class="spacer"></span>' +
      '<button class="uniwrt-iconbtn" id="uniwrt-theme-btn" title="Theme"></button>';

    var scrim = document.createElement("div");
    scrim.className = "uniwrt-scrim";

    body.appendChild(aside);
    body.appendChild(bar);
    body.appendChild(scrim);
    body.classList.add("uniwrt-shell");

    /* restore collapse state */
    if (ls(true, KEY_RAIL) === "collapsed") body.classList.add("rail-collapsed");

    /* highlight active by URL if LuCI didn't mark one */
    if (!aside.querySelector("a.active")) {
      var path = location.pathname.replace(/\/$/, "");
      aside.querySelectorAll("a").forEach(function (a) {
        var h = (a.getAttribute("href") || "").replace(/\/$/, "");
        if (h && path.indexOf(h) === 0) a.classList.add("active");
      });
    }

    /* wires */
    document.getElementById("uniwrt-collapse").addEventListener("click", function () {
      if (window.innerWidth <= 900) {
        body.classList.toggle("rail-open");
      } else {
        body.classList.toggle("rail-collapsed");
        ls(false, KEY_RAIL, body.classList.contains("rail-collapsed") ? "collapsed" : "");
      }
    });
    scrim.addEventListener("click", function () { body.classList.remove("rail-open"); });
    var tb = document.getElementById("uniwrt-theme-btn");
    tb.addEventListener("click", toggleTheme);
    paintThemeBtn(currentMode());
  }

  function decorateLogin() {
    var pw = document.querySelector('input[type="password"]');
    if (!pw || findMenu()) return false;
    document.body.classList.add("uniwrt-login");
    var form = pw.closest("form, .cbi-map");
    if (form && !form.querySelector(".uniwrt-login-brand")) {
      var b = document.createElement("div");
      b.className = "uniwrt-login-brand";
      b.innerHTML = '<img src="/luci-static/uniwrt/logo.svg" alt="" ' +
        'onerror="this.style.display=\'none\'"><strong>UniWRT</strong>';
      form.insertBefore(b, form.firstChild);
    }
    return true;
  }

  /* ---- boot ---- */
  function init() {
    applyTheme(currentMode());
    if (decorateLogin()) return;
    var menu = findMenu();
    if (menu) { buildRail(menu); return true; }
    return false;
  }

  function start() {
    if (init()) return;
    // menu not ready yet — watch for it (LuCI builds chrome async)
    var tries = 0;
    var obs = new MutationObserver(function () {
      if (init() || ++tries > 60) obs.disconnect();
    });
    obs.observe(document.body, { childList: true, subtree: true });
    var poll = setInterval(function () {
      if (init() || tries > 60) { clearInterval(poll); }
      tries++;
    }, 250);
  }

  if (document.readyState === "loading")
    document.addEventListener("DOMContentLoaded", start);
  else start();

  // keep dark mode in sync if user is on "auto" and the OS flips
  if (window.matchMedia) {
    window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", function () {
      if (!ls(true, KEY_THEME)) { applyTheme(currentMode()); paintThemeBtn(currentMode()); }
    });
  }
})();
