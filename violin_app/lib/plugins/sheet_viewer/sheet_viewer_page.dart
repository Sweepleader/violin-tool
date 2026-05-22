import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SheetViewerPage extends StatefulWidget {
  const SheetViewerPage({super.key});
  @override
  State<SheetViewerPage> createState() => _SheetViewerPageState();
}

class _SheetViewerPageState extends State<SheetViewerPage> {
  WebViewController? _controller;
  bool _osmdReady = false;
  String? _currentTitle;

  @override
  void initState() {
    super.initState();
    _initController();
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
      type: FileType.custom,
      allowedExtensions: ['musicxml', 'mxl', 'xml'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = File(result.files.single.path!);
    final xml = await file.readAsString();
    _loadXml(xml);
    final name = result.files.single.name;
    setState(() => _currentTitle = name);
  }

  void _loadXml(String xml) {
    final escaped = xml
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '');
    _controller?.runJavaScript("loadXml('$escaped');");
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTitle ?? 'Sheet Viewer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_open),
            tooltip: 'Import MusicXML',
            onPressed: _importFile,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_osmdReady)
            const LinearProgressIndicator(),
          Expanded(
            child: _controller != null
                ? WebViewWidget(controller: _controller!)
                : const Center(child: CircularProgressIndicator()),
          ),
          // Bottom bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                    icon: const Icon(Icons.skip_previous),
                    onPressed: () => _controller?.runJavaScript('prevPage();')),
                const SizedBox(width: 8),
                IconButton(
                    icon: const Icon(Icons.skip_next),
                    onPressed: () => _controller?.runJavaScript('nextPage();')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
