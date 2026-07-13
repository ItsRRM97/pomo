'use strict';

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

  function isIOS() {
    return (
      /iPad|iPhone|iPod/.test(navigator.userAgent) ||
      (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)
    );
  }

  function isAndroid() {
    return /Android/.test(navigator.userAgent);
  }

  function isMobileBrowser() {
    return isIOS() || isAndroid();
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
    if (node) {
      node.remove();
    }
    promptVisible = false;
  }

  function createPrompt(options) {
    if (!shouldShow() || !document.body) {
      return;
    }

    // Remove any existing prompt so we can replace it (e.g. upgrade manual -> native)
    removePrompt();
    promptVisible = true;

    var overlay = document.createElement('div');
    overlay.id = 'focus-pwa-install';
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-label', 'Install Focus app');

    var stepsHtml = '';
    if (options.steps && options.steps.length) {
      stepsHtml = '<ol class="focus-pwa-steps">' +
        options.steps.map(function (s) { return '<li>' + s + '</li>'; }).join('') +
        '</ol>';
    }

    var primaryHtml = '';
    if (options.primaryLabel) {
      primaryHtml =
        '<button type="button" class="focus-pwa-btn focus-pwa-btn-primary" id="focus-pwa-install-primary">' +
        options.primaryLabel +
        '</button>';
    }

    overlay.innerHTML =
      '<div class="focus-pwa-card">' +
      '<div class="focus-pwa-icon" aria-hidden="true">&#x23F1;</div>' +
      '<h2 class="focus-pwa-title">' + options.title + '</h2>' +
      '<p class="focus-pwa-body">' + options.body + '</p>' +
      stepsHtml +
      '<div class="focus-pwa-actions">' +
      primaryHtml +
      '<button type="button" class="focus-pwa-btn focus-pwa-btn-secondary" id="focus-pwa-install-later">Not now</button>' +
      '<button type="button" class="focus-pwa-btn focus-pwa-btn-ghost" id="focus-pwa-install-never">Don\'t show again</button>' +
      '</div>' +
      '</div>';

    document.body.appendChild(overlay);

    var later = document.getElementById('focus-pwa-install-later');
    var never = document.getElementById('focus-pwa-install-never');
    var primary = document.getElementById('focus-pwa-install-primary');

    if (later) {
      later.addEventListener('click', removePrompt);
    }
    if (never) {
      never.addEventListener('click', dismissForever);
    }
    if (primary && options.onPrimary) {
      primary.addEventListener('click', options.onPrimary);
    }
  }

  function showNativePrompt() {
    createPrompt({
      title: 'Install Focus',
      body: 'Install Focus for quick access and a distraction-free timer experience.',
      primaryLabel: 'Install',
      onPrimary: function () {
        if (!deferredPrompt) { return; }
        var p = deferredPrompt;
        deferredPrompt = null;
        p.prompt();
        p.userChoice.finally(removePrompt);
      },
    });
  }

  function showIOSPrompt() {
    createPrompt({
      title: 'Install Focus',
      body: 'Add Focus to your Home Screen for quick access and a full-screen timer.',
      steps: [
        'Tap the <strong>Share</strong> button in Safari',
        'Tap <strong>Add to Home Screen</strong>',
        'Tap <strong>Add</strong> in the top right',
      ],
    });
  }

  function showAndroidManualPrompt() {
    createPrompt({
      title: 'Install Focus',
      body: 'Install Focus from your browser menu for the best experience.',
      steps: [
        'Open the <strong>browser menu</strong> (&vellip;)',
        'Tap <strong>Add to Home screen</strong> or <strong>Install app</strong>',
        'Confirm to install',
      ],
    });
  }

  // Fired by Chrome / Edge before the native install prompt is shown.
  // We capture the event and show our own UI with a working Install button.
  window.addEventListener('beforeinstallprompt', function (event) {
    event.preventDefault();
    deferredPrompt = event;

    if (!shouldShow()) { return; }

    // If we already showed a manual fallback, replace it immediately with
    // the native-capable version (this handles late-firing events on Android).
    if (promptVisible || document.readyState !== 'loading') {
      window.setTimeout(showNativePrompt, 200);
    } else {
      window.addEventListener('DOMContentLoaded', function () {
        window.setTimeout(showNativePrompt, 800);
      }, { once: true });
    }
  });

  window.addEventListener('appinstalled', function () {
    deferredPrompt = null;
    dismissForever();
  });

  // Fallback: show prompt after page load if beforeinstallprompt hasn't fired.
  // iOS never fires beforeinstallprompt; Android/Edge may fire late or not at all.
  window.addEventListener('load', function () {
    if (!shouldShow() || !isMobileBrowser()) { return; }

    // Wait 4 s for Chrome/Edge to fire beforeinstallprompt first.
    // If it fires, showNativePrompt() will already have been called above.
    window.setTimeout(function () {
      if (deferredPrompt) {
        // Native prompt available but no UI shown yet -- show it now.
        if (!promptVisible) { showNativePrompt(); }
        return;
      }
      // No native prompt: show platform-appropriate manual instructions.
      if (isIOS()) {
        showIOSPrompt();
      } else if (isAndroid()) {
        showAndroidManualPrompt();
      }
    }, 4000);
  });
})();
