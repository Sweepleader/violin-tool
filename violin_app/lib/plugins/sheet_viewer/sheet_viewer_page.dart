import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SheetViewerPage extends StatefulWidget {
  const SheetViewerPage({super.key});
  @override
  State<SheetViewerPage> createState() => _SheetViewerPageState();
}

class _SheetViewerPageState extends State<SheetViewerPage> {
  WebViewController? _controller;
  bool _osmdReady = false;

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
        if (msg.message == 'osmdReady') {
          setState(() => _osmdReady = true);
        }
      })
      ..setNavigationDelegate(NavigationDelegate())
      ..loadHtmlString(fullHtml);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sheet Viewer')),
      body: _controller != null
          ? WebViewWidget(controller: _controller!)
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
