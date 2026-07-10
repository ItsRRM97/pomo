'use strict';

(function () {
  var STORAGE_KEY = 'focus-pwa-install-dismissed';
  var SESSION_KEY = 'focus-pwa-install-shown';
  var deferredPrompt = null;

  function isStandalone() {
    return (
      window.matchMedia('(display-mode: standalone)').matches ||
      window.navigator.standalone === true
    );
  }

  function isIOS() {
    return /iPad|iPhone|iPod/.test(navigator.userAgent);
  }

  function isAndroid() {
    return /Android/.test(navigator.userAgent);
  }

  function isMobileBrowser() {
    return isIOS() || isAndroid();
  }

  function shouldShow() {
    if (isStandalone()) {
      return false;
    }
    if (localStorage.getItem(STORAGE_KEY) === 'true') {
      return false;
    }
    if (sessionStorage.getItem(SESSION_KEY) === 'true') {
      return false;
    }
    return deferredPrompt || isIOS() || isAndroid();
  }

  function markShown() {
    sessionStorage.setItem(SESSION_KEY, 'true');
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
  }

  function createPrompt(options) {
    if (!shouldShow() || document.getElementById('focus-pwa-install')) {
      return;
    }

    markShown();

    var overlay = document.createElement('div');
    overlay.id = 'focus-pwa-install';
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-label', 'Install Focus app');
    overlay.innerHTML =
      '<div class="focus-pwa-card">' +
      '<div class="focus-pwa-icon" aria-hidden="true">⏱</div>' +
      '<h2 class="focus-pwa-title">' + options.title + '</h2>' +
      '<p class="focus-pwa-body">' + options.body + '</p>' +
      (options.steps
        ? '<ol class="focus-pwa-steps">' +
          options.steps
            .map(function (step) {
              return '<li>' + step + '</li>';
            })
            .join('') +
          '</ol>'
        : '') +
      '<div class="focus-pwa-actions">' +
      (options.primaryLabel
        ? '<button type="button" class="focus-pwa-btn focus-pwa-btn-primary" id="focus-pwa-install-primary">' +
          options.primaryLabel +
          '</button>'
        : '') +
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

  function showAndroidPrompt() {
    createPrompt({
      title: 'Install Focus',
      body: 'Add Focus to your home screen for a full-screen timer experience.',
      primaryLabel: 'Install',
      onPrimary: function () {
        if (!deferredPrompt) {
          return;
        }
        deferredPrompt.prompt();
        deferredPrompt.userChoice.finally(function () {
          deferredPrompt = null;
          removePrompt();
        });
      },
    });
  }

  function showIOSPrompt() {
    createPrompt({
      title: 'Install Focus',
      body: 'Add Focus to your home screen for quick access and a full-screen timer.',
      steps: [
        'Tap the Share button in Safari',
        'Scroll down and tap Add to Home Screen',
        'Tap Add in the top right',
      ],
    });
  }

  function showAndroidManualPrompt() {
    createPrompt({
      title: 'Install Focus',
      body: 'Add Focus to your home screen from your browser menu for the best experience.',
      steps: [
        'Open the browser menu',
        'Tap Install app or Add to Home screen',
        'Confirm to install',
      ],
    });
  }

  function maybeShowPrompt() {
    if (!shouldShow()) {
      return;
    }

    if (deferredPrompt) {
      showAndroidPrompt();
      return;
    }

    if (isIOS()) {
      showIOSPrompt();
      return;
    }

    if (isAndroid()) {
      showAndroidManualPrompt();
    }
  }

  window.addEventListener('beforeinstallprompt', function (event) {
    event.preventDefault();
    deferredPrompt = event;
    maybeShowPrompt();
  });

  window.addEventListener('load', function () {
    if (!isMobileBrowser()) {
      return;
    }

    window.setTimeout(maybeShowPrompt, 2500);
  });
})();
