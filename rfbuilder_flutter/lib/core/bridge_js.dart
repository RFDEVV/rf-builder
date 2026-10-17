/// JavaScript yang disuntik ke web RF Builder (hanya di dalam aplikasi).
/// Tidak mengubah tampilan: hanya menyambungkan Google login, riwayat lokal,
/// dan info sesi/tema ke sisi native.
const String kBridgeJs = r'''
(function () {
  if (window.__rfAppBridge) return;
  window.__rfAppBridge = true;
  window.RF_IS_APP = true;

  function call(name) {
    var args = Array.prototype.slice.call(arguments, 1);
    try {
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        return window.flutter_inappwebview.callHandler.apply(null, [name].concat(args));
      }
    } catch (e) {}
    return Promise.resolve(null);
  }
  function uid() {
    try { return (JSON.parse(localStorage.getItem('rfUser') || 'null') || {}).id || ''; }
    catch (e) { return ''; }
  }
  function notify(msg, type) {
    try { if (typeof toast === 'function') toast(msg, type || 'err'); } catch (e) {}
  }

  // 1) Login Google native (Google memblokir OAuth di dalam WebView)
  window.googleLogin = function () {
    call('googleLogin').then(function (r) {
      if (!r) return;
      if (r.ok) {
        try {
          localStorage.setItem('rfToken', r.token);
          localStorage.setItem('rfUser', JSON.stringify(r.user || {}));
        } catch (e) {}
        location.reload();
      } else {
        notify(r.error || 'Login Google gagal', 'err');
      }
    });
  };

  // 2) Riwayat build disimpan di HP + digabung ke halaman Histori
  var _fetch = window.fetch.bind(window);
  function pathOf(input) {
    var u = typeof input === 'string' ? input : (input && input.url) || '';
    try { return new URL(u, location.origin).pathname; } catch (e) { return ''; }
  }
  function absUrl(u) {
    if (!u) return u;
    return /^https?:/i.test(u) ? u : location.origin + (u.charAt(0) === '/' ? '' : '/') + u;
  }
  function isBuildPath(p) {
    return p.indexOf('/api/apk/build') === 0 && p !== '/api/apk/build-api';
  }
  function jsonResponse(obj) {
    return new Response(JSON.stringify(obj), { status: 200, headers: { 'Content-Type': 'application/json' } });
  }

  window.fetch = async function (input, init) {
    var p = pathOf(input);

    if (p === '/api/apk/history') {
      var local = [];
      try { local = (await call('getLocalHistory', uid())) || []; } catch (e) {}
      try {
        var res = await _fetch(input, init);
        if (!res.ok) return res;
        var j = await res.clone().json();
        if (j && j.success) {
          var have = {};
          (j.history || []).forEach(function (h) { if (h.fileName) have[h.fileName] = 1; });
          var extra = local.filter(function (h) { return !(h.fileName && have[h.fileName]); });
          j.history = (j.history || []).concat(extra).sort(function (a, b) {
            return new Date(b.createdAt) - new Date(a.createdAt);
          });
          return jsonResponse(j);
        }
        return res;
      } catch (e) {
        return jsonResponse({ success: true, history: local }); // offline: tampilkan riwayat HP
      }
    }

    var response = await _fetch(input, init);
    if (isBuildPath(p) && response.ok) {
      try {
        var d = await response.clone().json();
        if (d && d.success && d.downloadUrl) {
          var fd = init && init.body instanceof FormData ? init.body : null;
          var g = function (k) { return fd ? (fd.get(k) || '') : ''; };
          var url = g('websiteUrl') || g('url') || '';
          call('saveBuild', {
            id: 'local-' + (d.buildId || Date.now()),
            userId: uid(),
            appName: g('appName') || g('name') || d.appName || d.fileName,
            packageName: g('packageName') || g('pkgName') || '',
            sourceUrl: url || (g('htmlFile') ? '[HTML File]' : '-'),
            mode: url ? 'online' : 'offline',
            fileName: d.fileName,
            fileSize: d.size,
            downloadUrl: absUrl(d.downloadUrl),
            via: 'app',
            createdAt: new Date().toISOString()
          });
        }
      } catch (e) {}
    }
    return response;
  };

  // 3) Sesi (untuk push per-user) + warna tema (untuk status bar)
  var lastSess = null, lastBg = null;
  function tick() {
    var t = localStorage.getItem('rfToken') || '';
    var s = uid() + '|' + t;
    if (s !== lastSess) { lastSess = s; call('session', uid(), t); }
    try {
      var bg = getComputedStyle(document.body).backgroundColor;
      if (bg && bg !== lastBg) { lastBg = bg; call('bg', bg); }
    } catch (e) {}
  }
  setInterval(tick, 1500);
  tick();
})();
''';
