/* SPDX-License-Identifier: Apache-2.0 */
/* UniWRT LuCI Theme Enhancer. */
(function () {
  'use strict';

  var VERSION = '0.1.2';
  var STORAGE_KEY = 'uniwrt.theme.mode';

  function qs(sel, root) { return (root || document).querySelector(sel); }
  function qsa(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }

  function ready(fn) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn, { once: true });
    else fn();
  }

  function safeText(el) { return el ? (el.textContent || '').trim() : ''; }

  function currentMode() {
    try {
      var saved = localStorage.getItem(STORAGE_KEY);
      if (saved === 'light' || saved === 'dark' || saved === 'system') return saved;
    } catch (e) {}
    return 'system';
  }

  function applyMode(mode) {
    document.documentElement.setAttribute('data-uniwrt-mode', mode || 'system');
    try { localStorage.setItem(STORAGE_KEY, mode || 'system'); } catch (e) {}
  }

  function createEl(tag, cls, text) {
    var el = document.createElement(tag);
    if (cls) el.className = cls;
    if (text != null) el.textContent = text;
    return el;
  }

  function addShell() {
    document.documentElement.classList.add('uniwrt-js');
    document.body.classList.add('uniwrt-ready');

    if (!qs('.uniwrt-bg')) {
      var bg = createEl('div', 'uniwrt-bg');
      bg.setAttribute('aria-hidden', 'true');
      bg.innerHTML = '<span></span><span></span><span></span>';
      document.body.prepend(bg);
    }
  }

  function enhanceBrand() {
    var brand = qs('header a.brand, .brand, #brand, header h1 a, header .brand a');
    if (!brand) return;

    if (!qs('.uniwrt-mark', brand)) {
      var img = document.createElement('img');
      img.className = 'uniwrt-mark';
      img.src = (window.L ? L.resource('uniwrt/logo.svg') : '/luci-static/uniwrt/logo.svg');
      img.alt = 'UniWRT';
      brand.prepend(img);
    }

    var host = safeText(brand) || document.title.split('|')[0].trim() || 'OpenWrt';
    brand.setAttribute('title', 'UniWRT - ' + host);
  }

  function enhanceSidebar() {
    var nav = qs('#mainmenu, nav, .mainmenu, .navigation, header .dropdown-menu');
    if (!nav) return;
    nav.classList.add('uniwrt-sidebar');

    if (!qs('.uniwrt-sidebar-head', nav)) {
      var head = createEl('div', 'uniwrt-sidebar-head');
      head.innerHTML = '<img src="' + (window.L ? L.resource('uniwrt/logo.svg') : '/luci-static/uniwrt/logo.svg') + '" alt="" aria-hidden="true"><div><strong>UniWRT</strong><span>Network OS</span></div>';
      nav.insertBefore(head, nav.firstChild);
    }

    if (!qs('.uniwrt-sidebar-section', nav)) {
      var label = createEl('div', 'uniwrt-sidebar-section', 'Control Centre');
      var ref = qs('a', nav);
      if (ref) nav.insertBefore(label, ref);
      else nav.appendChild(label);
    }

    qsa('a', nav).forEach(function (a) {
      var txt = safeText(a).toLowerCase();
      if (!a.dataset.uwIcon) {
        if (txt.indexOf('status') >= 0 || txt.indexOf('overview') >= 0) a.dataset.uwIcon = 'pulse';
        else if (txt.indexOf('system') >= 0 || txt.indexOf('admin') >= 0) a.dataset.uwIcon = 'chip';
        else if (txt.indexOf('network') >= 0 || txt.indexOf('wireless') >= 0 || txt.indexOf('dhcp') >= 0) a.dataset.uwIcon = 'nodes';
        else if (txt.indexOf('services') >= 0 || txt.indexOf('vpn') >= 0) a.dataset.uwIcon = 'stack';
        else if (txt.indexOf('logout') >= 0) a.dataset.uwIcon = 'exit';
        else a.dataset.uwIcon = 'dot';
      }
    });
  }

  function addTopTools() {
    var header = qs('header, .navbar, #mainmenu') || document.body;
    if (qs('.uniwrt-toolbar')) return;

    var toolbar = createEl('div', 'uniwrt-toolbar');
    var mode = currentMode();
    applyMode(mode);

    var title = createEl('div', 'uniwrt-title');
    title.innerHTML = '<strong>UniWRT</strong><span>OpenWrt Control</span>';

    var toggle = createEl('button', 'uniwrt-mode-toggle');
    toggle.type = 'button';
    toggle.setAttribute('aria-label', 'Switch UniWRT theme mode');
    toggle.innerHTML = '<span class="uniwrt-toggle-dot"></span><span class="uniwrt-toggle-text"></span>';
    toggle.dataset.mode = mode;

    function label() {
      var m = currentMode();
      toggle.dataset.mode = m;
      var text = m === 'dark' ? 'Dark' : (m === 'light' ? 'Light' : 'Auto');
      var slot = qs('.uniwrt-toggle-text', toggle);
      if (slot) slot.textContent = text;
    }
    label();

    toggle.addEventListener('click', function () {
      var next = currentMode() === 'system' ? 'dark' : (currentMode() === 'dark' ? 'light' : 'system');
      applyMode(next);
      label();
    });

    toolbar.appendChild(title);
    toolbar.appendChild(toggle);
    header.appendChild(toolbar);
  }

  function wrapTables() {
    qsa('table').forEach(function (table) {
      if (table.parentElement && table.parentElement.classList.contains('uniwrt-table-wrap')) return;
      var wrap = createEl('div', 'uniwrt-table-wrap');
      table.parentNode.insertBefore(wrap, table);
      wrap.appendChild(table);
    });
  }

  function enhanceCards() {
    qsa('.cbi-map, .cbi-section, .cbi-section-node, .table, .ifacebox, .network-status-table, .dsl-status').forEach(function (el) {
      el.classList.add('uniwrt-cardish');
    });

    qsa('.cbi-button, button, input[type="submit"], input[type="button"], .btn').forEach(function (el) {
      el.classList.add('uniwrt-buttonish');
    });
  }

  function addPageHeader() {
    var main = qs('#maincontent, main, .main, #content');
    if (!main || qs('.uniwrt-page-head', main)) return;

    var h1 = qs('h1, .cbi-map-title, .panel-title', main);
    var title = safeText(h1) || (document.title || 'Dashboard').replace(/\s*[-|].*$/, '');
    var crumb = location.pathname.split('/').filter(Boolean).slice(-3).join(' / ') || 'LuCI';

    var head = createEl('section', 'uniwrt-page-head');
    head.innerHTML = '<div><span class="uniwrt-eyebrow">' + escapeHtml(crumb) + '</span><h1>' + escapeHtml(title) + '</h1></div><div class="uniwrt-status-pill"><span></span>Live</div>';
    main.insertBefore(head, main.firstChild);
  }

  function escapeHtml(str) {
    return String(str).replace(/[&<>"']/g, function (m) {
      return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' })[m];
    });
  }

  function enhanceFooter() {
    var footer = qs('footer, .footer, #footer');
    if (!footer || qs('.uniwrt-author-line', footer)) return;
    var line = createEl('div', 'uniwrt-author-line');
    line.innerHTML = '<a href="https://github.com/ox1d3x3/uniwrt-luci" target="_blank" rel="noreferrer">Author: @Ox1d3x3 × UniWRT Theme v' + VERSION + '</a>';
    footer.appendChild(line);
  }

  ready(function () {
    addShell();
    enhanceBrand();
    enhanceSidebar();
    addTopTools();
    wrapTables();
    enhanceCards();
    addPageHeader();
    enhanceFooter();

    window.setTimeout(function () {
      wrapTables();
      enhanceCards();
    }, 900);
  });
}());
