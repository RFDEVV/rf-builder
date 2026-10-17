import 'dart:collection';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/bridge_js.dart';
import '../core/config.dart';
import '../core/downloader.dart';
import '../core/google_auth.dart';
import '../core/history_db.dart';
import '../core/prefs.dart';
import '../core/push.dart';

/// Menampilkan UI web RF Builder apa adanya (tampilan & fungsi 100% sama),
/// dibungkus fitur native: Google login, push notif, riwayat di HP, unduhan.
class WebShell extends StatefulWidget {
  const WebShell({super.key});
  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  InAppWebViewController? _c;
  PullToRefreshController? _pull;
  Color _bg = Color(Prefs.lastBgColor);
  double _progress = 0;
  bool _loadError = false;
  DateTime? _lastBack;
  final ValueNotifier<_Dl?> _dl = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _pull = PullToRefreshController(
      settings: PullToRefreshSettings(color: const Color(0xFFA855F7)),
      onRefresh: () async => _c?.reload(),
    );
  }

  @override
  void dispose() {
    _dl.dispose();
    super.dispose();
  }

  Color? _parseRgb(String s) {
    final m = RegExp(r'rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?\)').firstMatch(s);
    if (m == null) return null;
    final a = m.group(4) == null ? 1.0 : double.tryParse(m.group(4)!) ?? 1.0;
    if (a == 0) return null; // transparan -> abaikan
    return Color.fromARGB(255, int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
  }

  void _applyBg(String css) {
    final c = _parseRgb(css);
    if (c == null || c == _bg) return;
    Prefs.lastBgColor = c.value;
    Prefs.lastThemeLight = c.computeLuminance() > .5;
    setState(() => _bg = c);
  }

  void _registerHandlers(InAppWebViewController c) {
    c.addJavaScriptHandler(handlerName: 'googleLogin', callback: (_) async {
      final r = await GoogleAuth.signIn();
      return {'ok': r.ok, 'error': r.error, 'token': r.token, 'user': r.user};
    });
    c.addJavaScriptHandler(handlerName: 'session', callback: (args) async {
      final id = args.isNotEmpty ? (args[0] ?? '').toString() : '';
      await PushService.setUser(id);
      if (id.isEmpty) GoogleAuth.signOut();
    });
    c.addJavaScriptHandler(handlerName: 'bg', callback: (args) {
      if (args.isNotEmpty) _applyBg(args[0].toString());
    });
    c.addJavaScriptHandler(handlerName: 'saveBuild', callback: (args) async {
      if (args.isEmpty || args[0] is! Map) return;
      await HistoryDb.save(Map<String, dynamic>.from(args[0] as Map));
    });
    c.addJavaScriptHandler(handlerName: 'getLocalHistory', callback: (args) async {
      final uid = args.isNotEmpty ? (args[0] ?? '').toString() : '';
      return HistoryDb.list(uid);
    });
  }

  bool _isInternal(Uri u) {
    final base = Uri.parse(AppConfig.baseUrl);
    return u.host == base.host || u.scheme == 'about' || u.scheme == 'blob' || u.scheme == 'data';
  }

  Future<void> _external(Uri u) async {
    try {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _handleDownload(DownloadStartRequest req) async {
    final url = req.url.toString();
    final name = req.suggestedFilename ?? '';
    _dl.value = _Dl(name.isEmpty ? 'Mengunduh…' : name, 0);
    try {
      final path = await Downloader.download(url, suggestedName: name, onProgress: (p) {
        _dl.value = _Dl(name.isEmpty ? 'Mengunduh…' : name, p);
      });
      _dl.value = null;
      if (!mounted) return;
      _showDone(path);
    } catch (e) {
      _dl.value = null;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengunduh: $e')));
    }
  }

  void _showDone(String path) {
    final isApk = path.toLowerCase().endsWith('.apk');
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111122),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Unduhan selesai', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6),
            Text(path.split('/').last, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF9B97C0), fontSize: 12)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
                  onPressed: () { Navigator.pop(context); OpenFilex.open(path); },
                  child: Text(isApk ? 'Install' : 'Buka'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () { Navigator.pop(context); Share.shareXFiles([XFile(path)]); },
                  child: const Text('Simpan / Bagikan'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _onBack() async {
    final c = _c;
    if (c != null && await c.canGoBack()) {
      await c.goBack();
      return;
    }
    final now = DateTime.now();
    if (_lastBack == null || now.difference(_lastBack!) > const Duration(seconds: 2)) {
      _lastBack = now;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tekan sekali lagi untuk keluar'), duration: Duration(seconds: 2)));
      return;
    }
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final light = _bg.computeLuminance() > .5;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: _bg,
      statusBarIconBrightness: light ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: _bg,
      systemNavigationBarIconBrightness: light ? Brightness.dark : Brightness.light,
    ));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _onBack(); },
      child: Scaffold(
        backgroundColor: _bg,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Stack(children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(AppConfig.baseUrl)),
              initialUserScripts: UnmodifiableListView([
                // AT_DOCUMENT_END: dijalankan setelah app.js, supaya googleLogin() bawaan web tertimpa.
                UserScript(source: kBridgeJs, injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END),
              ]),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                databaseEnabled: true,
                applicationNameForUserAgent: AppConfig.userAgentSuffix,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                useShouldOverrideUrlLoading: true,
                useOnDownloadStart: true,
                supportMultipleWindows: true,
                javaScriptCanOpenWindowsAutomatically: true,
                thirdPartyCookiesEnabled: true,
                allowFileAccess: true,
                allowContentAccess: true,
                useHybridComposition: true,
                overScrollMode: OverScrollMode.NEVER,
                supportZoom: false,
                transparentBackground: false,
                safeBrowsingEnabled: false,
              ),
              pullToRefreshController: Platform.isAndroid ? null : _pull,
              onWebViewCreated: (c) {
                _c = c;
                _registerHandlers(c);
              },
              onLoadStart: (c, u) => setState(() => _loadError = false),
              onProgressChanged: (c, p) {
                setState(() => _progress = p / 100);
                if (p == 100) _pull?.endRefreshing();
              },
              onReceivedError: (c, req, err) {
                if (req.isForMainFrame ?? false) setState(() => _loadError = true);
              },
              shouldOverrideUrlLoading: (c, action) async {
                final u = action.request.url;
                if (u == null) return NavigationActionPolicy.ALLOW;
                final uri = Uri.parse(u.toString());
                if (_isInternal(uri)) return NavigationActionPolicy.ALLOW;
                await _external(uri); // wa.me, t.me, tel:, mailto:, dll
                return NavigationActionPolicy.CANCEL;
              },
              onCreateWindow: (c, action) async {
                final u = action.request.url;
                if (u != null) {
                  final uri = Uri.parse(u.toString());
                  if (_isInternal(uri)) {
                    c.loadUrl(urlRequest: URLRequest(url: u));
                  } else {
                    await _external(uri);
                  }
                }
                return false;
              },
              onDownloadStartRequest: (c, req) => _handleDownload(req),
              onPermissionRequest: (c, req) async {
                final need = <Permission>[];
                for (final r in req.resources) {
                  if (r == PermissionResourceType.CAMERA) need.add(Permission.camera);
                  if (r == PermissionResourceType.MICROPHONE) need.add(Permission.microphone);
                }
                var ok = true;
                for (final p in need) {
                  if (!(await p.request()).isGranted) ok = false;
                }
                return PermissionResponse(
                    resources: req.resources,
                    action: ok ? PermissionResponseAction.GRANT : PermissionResponseAction.DENY);
              },
              onGeolocationPermissionsShowPrompt: (c, origin) async =>
                  GeolocationPermissionShowPromptResponse(origin: origin, allow: true, retain: true),
            ),
            if (_progress < 1 && !_loadError)
              Positioned(
                top: 0, left: 0, right: 0,
                child: LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFA855F7)),
                ),
              ),
            ValueListenableBuilder<_Dl?>(
              valueListenable: _dl,
              builder: (_, d, __) => d == null
                  ? const SizedBox.shrink()
                  : Positioned(
                      left: 12, right: 12, bottom: 76,
                      child: Material(
                        color: const Color(0xFF161628),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: Colors.white)),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: d.progress == 0 ? null : d.progress,
                              color: const Color(0xFFA855F7),
                              backgroundColor: Colors.white12,
                            ),
                          ]),
                        ),
                      ),
                    ),
            ),
            if (_loadError) _errorView(),
          ]),
        ),
      ),
    );
  }

  Widget _errorView() => Container(
        color: _bg,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFF9B97C0)),
          const SizedBox(height: 12),
          const Text('Tidak bisa terhubung ke server',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Periksa koneksi internet lalu coba lagi.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF9B97C0))),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
            onPressed: () { setState(() => _loadError = false); _c?.reload(); },
            child: const Text('Coba lagi'),
          ),
        ]),
      );
}

class _Dl {
  final String name;
  final double progress;
  _Dl(this.name, this.progress);
}
