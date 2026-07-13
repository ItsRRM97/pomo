'use strict';

// Only show install prompt when Chrome/Edge fires the native beforeinstallprompt event.
// No manual fallback is shown.
(function () {
  var STORAGE_KEY = 'focus-pwa-install-dismissed';
  var deferredPrompt = null;
  var promptVisible = false;

  function isStandalone() {
    return (
      window.matchMedia('(display-mode: standalone)').matches ||
      window.navigator.standalone === true
    );
  }

  function isDismissed() {
    return localStorage.getItem(STORAGE_KEY) === 'true';
  }

  function shouldShow() {
    return !isStandalone() && !isDismissed();
  }

  function dismissForever() {
    localStorage.setItem(STORAGE_KEY, 'true');
    removePrompt();
  }

  function removePrompt() {
    var node = document.getElementById('focus-pwa-install');
    if (node) { node.remove(); }
    promptVisible = false;
  }

  function showNativePrompt() {
    if (!shouldShow() || !document.body || !deferredPrompt) { return; }
    removePrompt();
    promptVisible = true;

    var overlay = document.createElement('div');
    overlay.id = 'focus-pwa-install';
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-label', 'Install Focus app');
    overlay.innerHTML =
      '<div class="focus-pwa-card">' +
      '<div class="focus-pwa-icon" aria-hidden="true">&#x23F1;</div>' +
      '<h2 class="focus-pwa-title">Install Focus</h2>' +
      '<p class="focus-pwa-body">Install Focus for quick access and a full-screen timer experience.</p>' +
      '<div class="focus-pwa-actions">' +
      '<button type="button" class="focus-pwa-btn focus-pwa-btn-primary" id="focus-pwa-install-primary">Install</button>' +
      '<button type="button" class="focus-pwa-btn focus-pwa-btn-secondary" id="focus-pwa-install-later">Not now</button>' +
      '<button type="button" class="focus-pwa-btn focus-pwa-btn-ghost" id="focus-pwa-install-never">Don\'t show again</button>' +
      '</div>' +
      '</div>';

    document.body.appendChild(overlay);

    var later = document.getElementById('focus-pwa-install-later');
    var never = document.getElementById('focus-pwa-install-never');
    var primary = document.getElementById('focus-pwa-install-primary');

    if (later) { later.addEventListener('click', removePrompt); }
    if (never) { never.addEventListener('click', dismissForever); }
    if (primary) {
      primary.addEventListener('click', function () {
        if (!deferredPrompt) { return; }
        var p = deferredPrompt;
        deferredPrompt = null;
        p.prompt();
        p.userChoice.finally(removePrompt);
      });
    }
  }

  window.addEventListener('beforeinstallprompt', function (event) {
    event.preventDefault();
    deferredPrompt = event;
    if (!shouldShow()) { return; }
    if (document.readyState === 'loading') {
      window.addEventListener('DOMContentLoaded', function () {
        window.setTimeout(showNativePrompt, 800);
      }, { once: true });
    } else {
      window.setTimeout(showNativePrompt, 500);
    }
  });

  window.addEventListener('appinstalled', function () {
    deferredPrompt = null;
    dismissForever();
  });
})();
