import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'widgets/playhead_overlay.dart';

class SheetViewerPage extends StatefulWidget {
  const SheetViewerPage({super.key});
  @override State<SheetViewerPage> createState() => _SheetViewerPageState();
}

class _SheetViewerPageState extends State<SheetViewerPage> {
  InAppWebViewController? _controller;
  bool _osmdReady = false;
  String? _currentTitle;
  bool _trackingMode = false;
  double? _playheadX;
  int? _startNoteIndex;
  String _fullHtml = '';

  @override
  void initState() {
    super.initState();
    _initHtml();
  }

  Future<void> _initHtml() async {
    final osmdJs = await rootBundle.loadString('assets/osmd/opensheetmusicdisplay.min.js');
    final html = await rootBundle.loadString('assets/osmd/sheet_viewer.html');
    _fullHtml = html.replaceFirst(
      '<script src="opensheetmusicdisplay.min.js"></script>',
      '<script>$osmdJs</script>',
    );
    setState(() {});
  }

  void _onWebViewCreated(InAppWebViewController c) {
    _controller = c;
    c.addJavaScriptHandler(handlerName: 'onOsmdReady', callback: (_) {
      setState(() => _osmdReady = true);
      _loadBuiltIn();
    });
    c.addJavaScriptHandler(handlerName: 'noteIndex', callback: (args) {
      final idx = (args.isNotEmpty ? args[0] : -1) as int;
      if (idx >= 0) setState(() { _startNoteIndex = idx; _playheadX = null; });
    });
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
    _controller?.evaluateJavascript(source: "loadXml('$escaped');");
  }

  void _toggleTracking() {
    setState(() {
      _trackingMode = !_trackingMode;
      if (!_trackingMode) { _playheadX = null; _startNoteIndex = null; }
    });
  }

  void _onPlayheadPosition(double x) {
    _controller?.evaluateJavascript(
        source: "window.flutter_inappwebview.callHandler('noteIndex',getNoteIndexAtPixel($x));");
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                child: _fullHtml.isNotEmpty
                    ? InAppWebView(
                        initialData: InAppWebViewInitialData(data: _fullHtml, baseUrl: WebUri('about:blank')),
                        initialSettings: InAppWebViewSettings(javaScriptEnabled: true),
                        onWebViewCreated: _onWebViewCreated,
                        onLoadStop: (c, url) { c.evaluateJavascript(source: 'initOsmd();'); },
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: theme.colorScheme.surface,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton(icon: const Icon(Icons.skip_previous),
                      onPressed: () => _controller?.evaluateJavascript(source: 'prevPage();')),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.skip_next),
                      onPressed: () => _controller?.evaluateJavascript(source: 'nextPage();')),
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
