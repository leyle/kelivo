import 'dart:math';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_flutter/webview_flutter.dart';
import 'mermaid_cache.dart';
import 'package:file_picker/file_picker.dart';

class MermaidViewHandle {
  final Widget widget;
  final Future<bool> Function() exportPng;
  final Future<Uint8List?> Function()? exportPngBytes;
  MermaidViewHandle({
    required this.widget,
    required this.exportPng,
    this.exportPngBytes,
  });
}

/// Mobile/desktop (non-web) Mermaid renderer using webview_flutter.
/// Returns a handle with the widget and an export-to-PNG action.
MermaidViewHandle? createMermaidView(
  String code,
  bool dark, {
  Map<String, String>? themeVars,
  GlobalKey? viewKey,
}) {
  final usedKey = viewKey ?? GlobalKey<_MermaidInlineWebViewState>();
  final widget = _MermaidInlineWebView(
    key: usedKey,
    code: code,
    dark: dark,
    themeVars: themeVars,
  );
  Future<bool> doExport() async {
    try {
      final state = usedKey.currentState;
      if (state is _MermaidInlineWebViewState) {
        return await state.exportPng();
      }
    } catch (_) {}
    return false;
  }

  Future<Uint8List?> doExportBytes() async {
    try {
      final state = usedKey.currentState;
      if (state is _MermaidInlineWebViewState) {
        return await state.exportPngBytes();
      }
    } catch (_) {}
    return null;
  }

  return MermaidViewHandle(
    widget: widget,
    exportPng: doExport,
    exportPngBytes: doExportBytes,
  );
}

// (Linux-only view removed; Linux now falls back to code block via null handle.)

class _MermaidInlineWebView extends StatefulWidget {
  final String code;
  final bool dark;
  final Map<String, String>? themeVars;
  const _MermaidInlineWebView({
    Key? key,
    required this.code,
    required this.dark,
    this.themeVars,
  }) : super(key: key);

  @override
  State<_MermaidInlineWebView> createState() => _MermaidInlineWebViewState();
}

class _MermaidInlineWebViewState extends State<_MermaidInlineWebView> {
  late final WebViewController _controller;
  double _height = 160;
  Completer<String?>? _exportCompleter;
  String? _lastThemeVarsSig;
  Timer? _heightDebounce;

  @override
  void initState() {
    super.initState();
    // Seed initial height from cache to reduce layout jumps
    try {
      final cached = MermaidHeightCache.get(widget.code);
      if (cached != null) _height = cached;
    } catch (_) {}
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'HeightChannel',
        onMessageReceived: (JavaScriptMessage msg) {
          final v = double.tryParse(msg.message);
          if (v != null && mounted) {
            // Debounce rapid height updates to avoid jank
            _heightDebounce?.cancel();
            _heightDebounce = Timer(const Duration(milliseconds: 60), () {
              if (!mounted) return;
              setState(() {
                _height = max(120, v + 16);
              });
              try {
                MermaidHeightCache.put(widget.code, _height);
              } catch (_) {}
            });
          }
        },
      )
      ..addJavaScriptChannel(
        'ExportChannel',
        onMessageReceived: (JavaScriptMessage msg) {
          if (_exportCompleter != null && !(_exportCompleter!.isCompleted)) {
            final b64 = msg.message;
            _exportCompleter!.complete(b64.isEmpty ? null : b64);
          }
        },
      );
    _loadHtml();
  }

  @override
  void didUpdateWidget(covariant _MermaidInlineWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final themeSig = _themeVarsSignature(widget.themeVars);
    final themeChanged = _lastThemeVarsSig != themeSig;
    final codeChanged = oldWidget.code != widget.code;
    final darkChanged = oldWidget.dark != widget.dark;
    if (codeChanged || darkChanged || themeChanged) {
      _loadHtml();
    } else {
      // No content change; still re-measure to keep height in sync after rebuilds
      _safePostHeight();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOutCubic,
      width: double.infinity,
      height: _height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: WebViewWidget(controller: _controller),
      ),
    );
  }

  Future<void> _loadHtml() async {
    // Load mermaid script from assets and inline it to avoid external requests.
    final mermaidJs = await rootBundle.loadString('assets/mermaid.min.js');
    final html = _buildHtml(
      widget.code,
      widget.dark,
      mermaidJs,
      widget.themeVars,
    );
    await _controller.loadHtmlString(html);
    // Store latest theme signature for change detection
    _lastThemeVarsSig = _themeVarsSignature(widget.themeVars);
  }

  String _buildHtml(
    String code,
    bool dark,
    String mermaidJs,
    Map<String, String>? themeVars,
  ) {
    final bg = dark ? '#111111' : '#ffffff';
    final fg = dark ? '#eaeaea' : '#222222';
    final escaped = code
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    // Build themeVariables JSON
    String themeVarsJson = '{}';
    if (themeVars != null && themeVars.isNotEmpty) {
      final entries = themeVars.entries
          .map((e) => '"${e.key}": "${e.value}"')
          .join(',');
      themeVarsJson = '{' + entries + '}';
    }
    return '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=yes, maximum-scale=5.0">
    <title>Mermaid</title>
    <script>${mermaidJs}</script>
    <style>
      html,body{margin:0;padding:0;background:${bg};color:${fg};}
      .wrap{padding:8px;}
      .mermaid{width:100%; text-align:center;}
    </style>
  </head>
  <body>
    <div class="wrap">
      <div class="mermaid">${escaped}</div>
    </div>
    <script>
      function postHeight(){
        try{
          const el = document.querySelector('.mermaid');
          const r = el.getBoundingClientRect();
          const scale = window.visualViewport ? window.visualViewport.scale : 1;
          const h = Math.ceil((r.height + 8) * scale);
          HeightChannel.postMessage(String(h));
        }catch(e){/*ignore*/}
      }
      window.exportSvgToPng = function(){
        try{
          const svg = document.querySelector('.mermaid svg');
          if(!svg){ ExportChannel.postMessage(''); return; }
          let w = 0, h = 0;
          try {
            if (svg.viewBox && svg.viewBox.baseVal && svg.viewBox.baseVal.width && svg.viewBox.baseVal.height) {
              w = Math.ceil(svg.viewBox.baseVal.width);
              h = Math.ceil(svg.viewBox.baseVal.height);
            } else if (svg.width && svg.height && svg.width.baseVal && svg.height.baseVal) {
              w = Math.ceil(svg.width.baseVal.value);
              h = Math.ceil(svg.height.baseVal.value);
            } else if (svg.getBBox) {
              const bb = svg.getBBox();
              w = Math.ceil(bb.width);
              h = Math.ceil(bb.height);
            }
          } catch(_) {}
          if (!w || !h) {
            const rect = svg.getBoundingClientRect();
            w = Math.ceil(rect.width);
            h = Math.ceil(rect.height);
          }
          const scale = (window.devicePixelRatio || 1) * 2;
          const canvas = document.createElement('canvas');
          canvas.width = Math.max(1, Math.floor(w * scale));
          canvas.height = Math.max(1, Math.floor(h * scale));
          const ctx = canvas.getContext('2d');
          const xml = new XMLSerializer().serializeToString(svg);
          const img = new Image();
          img.onload = function(){
            ctx.fillStyle = '${bg}';
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
            const data = canvas.toDataURL('image/png');
            const b64 = data.split(',')[1] || '';
            ExportChannel.postMessage(b64);
          };
          img.onerror = function(){ ExportChannel.postMessage(''); };
          img.src = 'data:image/svg+xml;base64,' + btoa(unescape(encodeURIComponent(xml)));
        }catch(e){
          ExportChannel.postMessage('');
        }
      };
      mermaid.initialize({ startOnLoad:false, theme: '${dark ? 'dark' : 'default'}', securityLevel:'loose', fontFamily: 'inherit', themeVariables: ${themeVarsJson} });
      mermaid.run({ querySelector: '.mermaid' }).then(postHeight).catch(postHeight);
      window.addEventListener('resize', postHeight);
      document.addEventListener('DOMContentLoaded', postHeight);
      setTimeout(postHeight, 200);
    </script>
  </body>
</html>
  ''';
  }

  void _safePostHeight() {
    try {
      _controller.runJavaScript('postHeight();');
    } catch (_) {}
  }

  String _themeVarsSignature(Map<String, String>? vars) {
    if (vars == null || vars.isEmpty) return '';
    final entries = vars.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((e) => '${e.key}=${e.value}').join('&');
  }

  Future<bool> exportPng() async {
    try {
      _exportCompleter = Completer<String?>();
      await _controller.runJavaScript('exportSvgToPng();');
      final b64 = await _exportCompleter!.future.timeout(
        const Duration(seconds: 8),
      );
      if (b64 == null || b64.isEmpty) return false;
      final bytes = base64Decode(b64);
      final suggested = 'mermaid_${DateTime.now().millisecondsSinceEpoch}.png';
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save PNG',
        fileName: suggested,
        type: FileType.custom,
        allowedExtensions: const ['png'],
      );
      if (savePath == null || savePath.isEmpty) return false;
      await File(savePath).parent.create(recursive: true);
      await File(savePath).writeAsBytes(bytes);
      return true;
    } catch (_) {
      return false;
    } finally {
      _exportCompleter = null;
    }
  }

  @override
  void dispose() {
    try {
      _heightDebounce?.cancel();
    } catch (_) {}
    _heightDebounce = null;
    super.dispose();
  }

  Future<Uint8List?> exportPngBytes() async {
    try {
      _exportCompleter = Completer<String?>();
      await _controller.runJavaScript('exportSvgToPng();');
      final b64 = await _exportCompleter!.future.timeout(
        const Duration(seconds: 8),
      );
      if (b64 == null || b64.isEmpty) return null;
      final bytes = base64Decode(b64);
      return bytes;
    } catch (_) {
      return null;
    } finally {
      _exportCompleter = null;
    }
  }
}
