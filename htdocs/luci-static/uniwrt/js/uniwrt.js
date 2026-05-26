/* UniWRT LuCI theme runtime. No external dependencies. */
(function () {
  'use strict';

  var root = document.documentElement;
  var storageKey = 'uniwrt.theme';
  var allowedThemes = ['auto', 'light', 'dark'];

  function selectedTheme() {
    var value = localStorage.getItem(storageKey) || 'auto';
    return allowedThemes.indexOf(value) >= 0 ? value : 'auto';
  }

  function applyTheme(value) {
    var theme = allowedThemes.indexOf(value) >= 0 ? value : 'auto';
    if (theme === 'auto') {
      root.removeAttribute('data-uniwrt-theme');
    } else {
      root.setAttribute('data-uniwrt-theme', theme);
    }
    localStorage.setItem(storageKey, theme);
    syncThemeButtons(theme);
  }

  function syncThemeButtons(theme) {
    document.querySelectorAll('[data-uniwrt-theme-choice]').forEach(function (btn) {
      btn.setAttribute('data-active', btn.getAttribute('data-uniwrt-theme-choice') === theme ? 'true' : 'false');
    });
  }

  function icon(path) {
    return '<svg viewBox="0 0 24 24" width="15" height="15" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' + path + '</svg>';
  }

  function buildActions() {
    if (document.querySelector('.uniwrt-actions')) return;

    var host = document.querySelector('header .pull-right, .navbar .pull-right, #indicators') ||
      document.querySelector('header .navbar-inner, .navbar-inner, header > div, header');
    if (!host) return;

    var actions = document.createElement('div');
    actions.className = 'uniwrt-actions';
    actions.innerHTML =
      '<span class="uniwrt-chip" title="LuCI is loaded"><span class="uniwrt-status-dot"></span>Live</span>' +
      '<button class="uniwrt-chip" data-uniwrt-theme-choice="auto" type="button" title="Follow system theme">Auto</button>' +
      '<button class="uniwrt-icon-btn" data-uniwrt-theme-choice="light" type="button" title="Light mode">' + icon('<circle cx="12" cy="12" r="4"></circle><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41"></path>') + '</button>' +
      '<button class="uniwrt-icon-btn" data-uniwrt-theme-choice="dark" type="button" title="Dark mode">' + icon('<path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path>') + '</button>';

    if (host.id === 'indicators' || host.classList.contains('pull-right')) {
      host.appendChild(actions);
    } else {
      host.appendChild(actions);
    }

    actions.addEventListener('click', function (ev) {
      var btn = ev.target.closest('[data-uniwrt-theme-choice]');
      if (!btn) return;
      applyTheme(btn.getAttribute('data-uniwrt-theme-choice'));
    });
    syncThemeButtons(selectedTheme());
  }

  function enhanceTables() {
    document.querySelectorAll('#maincontent table').forEach(function (table) {
      if (table.closest('.uniwrt-table-wrap') || table.classList.contains('cbi-section-table-descr')) return;
      var wrap = document.createElement('div');
      wrap.className = 'uniwrt-table-wrap';
      table.parentNode.insertBefore(wrap, table);
      wrap.appendChild(table);
    });
  }

  function addPageTitle() {
    var main = document.getElementById('maincontent') || document.querySelector('main, .main');
    if (!main || main.querySelector('.uniwrt-page-title')) return;
    var title = main.querySelector('h1, h2');
    if (!title) return;

    var wrapper = document.createElement('div');
    wrapper.className = 'uniwrt-page-title';
    title.parentNode.insertBefore(wrapper, title);
    wrapper.appendChild(title);

    var subtitle = document.createElement('div');
    subtitle.className = 'uniwrt-page-subtitle';
    subtitle.textContent = 'OpenWrt control centre';
    wrapper.appendChild(subtitle);
  }

  function markReady() {
    document.body.classList.add('uniwrt-ready');
  }

  applyTheme(selectedTheme());

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  function init() {
    markReady();
    buildActions();
    addPageTitle();
    enhanceTables();

    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function () {
      if (selectedTheme() === 'auto') applyTheme('auto');
    });
  }
})();
