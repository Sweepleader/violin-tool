import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'widgets/playhead_overlay.dart';

class SheetViewerPage extends StatefulWidget {
  const SheetViewerPage({super.key});
  @override State<SheetViewerPage> createState() => _SheetViewerPageState();
}

class _SheetViewerPageState extends State<SheetViewerPage> {
  WebViewController? _controller;
  bool _osmdReady = false;
  String? _currentTitle;
  bool _trackingMode = false;
  double? _playheadX;
  int? _startNoteIndex;

  bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    if (_isMobile) _initController();
  }

  Future<void> _initController() async {
    final osmdJs = await rootBundle.loadString('assets/osmd/opensheetmusicdisplay.min.js');
    final html = await rootBundle.loadString('assets/osmd/sheet_viewer.html');
    final fullHtml = html.replaceFirst(
      '<script src="opensheetmusicdisplay.min.js"></script>',
      '<script>$osmdJs</script>',
    );
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('Flutter', onMessageReceived: (msg) {
        final m = msg.message;
        if (m == 'osmdReady') {
          setState(() => _osmdReady = true);
          _loadBuiltIn();
        } else if (m.startsWith('noteIndex:')) {
          final idx = int.tryParse(m.substring(10)) ?? -1;
          if (idx >= 0) setState(() { _startNoteIndex = idx; _playheadX = null; });
        }
      })
      ..setNavigationDelegate(NavigationDelegate())
      ..loadHtmlString(fullHtml);
    setState(() {});
  }

  Future<void> _loadBuiltIn() async {
    try {
      final xml = await rootBundle.loadString('assets/sheet_music/twinkle_twinkle.musicxml');
      _loadXml(xml);
      setState(() => _currentTitle = 'Twinkle Twinkle');
    } catch (_) {}
  }

  Future<void> _importFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['musicxml', 'mxl', 'xml']);
    if (result == null || result.files.isEmpty) return;
    final file = File(result.files.single.path!);
    final xml = await file.readAsString();
    _loadXml(xml);
    setState(() => _currentTitle = result.files.single.name);
  }

  void _loadXml(String xml) {
    final escaped = xml.replaceAll("'", "\\'").replaceAll('\n', '\\n').replaceAll('\r', '');
    _controller?.runJavaScript("loadXml('$escaped');");
  }

  void _toggleTracking() {
    setState(() {
      _trackingMode = !_trackingMode;
      if (!_trackingMode) { _playheadX = null; _startNoteIndex = null; }
    });
  }

  void _onPlayheadPosition(double x) {
    _controller?.runJavaScript("Flutter.postMessage('noteIndex:'+getNoteIndexAtPixel($x));");
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_isMobile) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sheet Viewer')),
        body: const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.phone_android, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Sheet Viewer requires Android',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
            SizedBox(height: 4),
            Text('Windows WebView not yet available',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
          ]),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTitle ?? 'Sheet Viewer'),
        actions: [
          TextButton(
            onPressed: _toggleTracking,
            child: Text(_trackingMode ? 'Stop' : 'Follow',
                style: TextStyle(color: theme.colorScheme.onPrimary)),
          ),
          IconButton(icon: const Icon(Icons.file_open), tooltip: 'Import', onPressed: _importFile),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (!_osmdReady) const LinearProgressIndicator(),
              Expanded(
                child: _controller != null
                    ? WebViewWidget(controller: _controller!)
                    : const Center(child: CircularProgressIndicator()),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: theme.colorScheme.surface,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton(icon: const Icon(Icons.skip_previous),
                      onPressed: () => _controller?.runJavaScript('prevPage();')),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.skip_next),
                      onPressed: () => _controller?.runJavaScript('nextPage();')),
                  if (_startNoteIndex != null) ...[
                    const SizedBox(width: 16),
                    Text('Start at note ${_startNoteIndex! + 1}', style: theme.textTheme.bodySmall),
                  ],
                ]),
              ),
            ],
          ),
          PlayheadOverlay(
            visible: _trackingMode,
            lockedX: _startNoteIndex != null ? _playheadX : null,
            onPositionSelected: _onPlayheadPosition,
          ),
        ],
      ),
    );
  }
}
