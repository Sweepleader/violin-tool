# Plan 3 — Sheet Music System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flutter plugin that renders MusicXML as sheet music via OSMD in a WebView, with draggable playhead and real-time pitch-following.

**Architecture:** flutter_inappwebview hosts OSMD JavaScript (bundled as asset). A Flutter overlay provides a draggable playhead cursor. Dart ↔ OSMD communicate via JavaScript channels. MusicXmlParser extracts note sequences; NoteTracker matches YIN output to the score via sliding window.

**Tech Stack:** flutter_inappwebview, OSMD (JS), file_picker, Dart xml package

---

## File Structure

```
violin_app/
├── assets/
│   ├── osmd/
│   │   └── opensheetmusicdisplay.min.js
│   ├── sheet_music/
│   │   ├── twinkle_twinkle.musicxml
│   │   └── minuet_in_g.musicxml
├── lib/
│   ├── plugins/
│   │   ├── sheet_viewer/
│   │   │   ├── sheet_viewer_plugin.dart
│   │   │   ├── sheet_viewer_page.dart
│   │   │   ├── html/
│   │   │   │   └── sheet_viewer.html
│   │   │   ├── widgets/
│   │   │   │   ├── playhead_overlay.dart
│   │   │   ├── services/
│   │   │   │   ├── osmd_bridge.dart
│   │   │   │   ├── music_xml_parser.dart
│   │   │   │   └── note_tracker.dart
├── test/
│   ├── plugins/
│   │   ├── sheet_viewer/
│   │   │   ├── music_xml_parser_test.dart
│   │   │   ├── note_tracker_test.dart
```

---

### Task 1: WebView Integration & OSMD Assets

**Files:**
- Modify: `violin_app/pubspec.yaml`
- Create: `violin_app/assets/osmd/` (OSMD JS)
- Create: `violin_app/lib/plugins/sheet_viewer/html/sheet_viewer.html`
- Create: `violin_app/lib/plugins/sheet_viewer/sheet_viewer_plugin.dart` (stub)
- Create: `violin_app/lib/plugins/sheet_viewer/sheet_viewer_page.dart`

**验收:** WebView 加载本地 HTML，显示 "OSMD loaded" 确认 JS 就绪。

- [ ] **Step 1: Add dependencies to pubspec.yaml**

```yaml
dependencies:
  flutter_inappwebview: ^6.1.5
  file_picker: ^8.0.0
  xml: ^6.5.0
```

Run: `flutter pub get`

- [ ] **Step 2: Create OSMD assets directory + placeholder**

```bash
mkdir -p violin_app/assets/osmd
mkdir -p violin_app/lib/plugins/sheet_viewer/html
```

Download OSMD: the user must place `opensheetmusicdisplay.min.js` at `assets/osmd/opensheetmusicdisplay.min.js`. For now, create a placeholder note.

Declare assets in pubspec.yaml:
```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/osmd/
    - assets/sheet_music/
```

- [ ] **Step 3: Create sheet viewer HTML**

```html
<!-- violin_app/assets/osmd/../lib/plugins/sheet_viewer/html/sheet_viewer.html -->
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <script src="opensheetmusicdisplay.min.js"></script>
</head>
<body style="margin:0; background:#FFFCF7;">
  <div id="osmd-container"></div>
  <script>
    var osmd = null;
    function initOsmd() {
      osmd = new opensheetmusicdisplay.OpenSheetMusicDisplay("osmd-container", {
        autoResize: true,
        backend: "svg",
        drawTitle: false,
      });
      window.flutter_inappwebview.callHandler('onOsmdReady', true);
    }
    function loadMusicXml(xml) {
      osmd.load(xml).then(function() { osmd.render(); });
    }
    function highlightNote(index) {
      osmd.cursor.show(); osmd.cursor.next(); // navigate to index
      for (var i = 0; i < index; i++) osmd.cursor.next();
    }
    function getNoteAtPixel(x) {
      var notes = osmd.GraphicalMusicSheet.GetAllGraphicalObjects();
      var closest = null, minDist = Infinity;
      for (var n of notes) {
        var d = Math.abs(n.PositionAndShape.RelativePosition.x - x);
        if (d < minDist) { minDist = d; closest = n; }
      }
      return closest ? closest.staffEntry.voiceEntry.indexInStaff : -1;
    }
    function nextPage() { osmd.nextPage(); osmd.render(); }
    function prevPage() { osmd.previousPage(); osmd.render(); }
    initOsmd();
  </script>
</body>
</html>
```

- [ ] **Step 4: Create SheetViewerPlugin stub**

```dart
// lib/plugins/sheet_viewer/sheet_viewer_plugin.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/plugin/tool_plugin.dart';
import '../../core/plugin/plugin_action.dart';
import 'sheet_viewer_page.dart';

class SheetViewerPlugin extends ToolPlugin {
  @override String get id => 'sheet_viewer';
  @override String get name => 'Sheet Viewer';
  @override String get description => 'View and follow sheet music';
  @override IconData get icon => Icons.library_music;
  @override List<PluginAction> get actions => const [];

  @override Future<void> init(ProviderContainer container) async {}

  @override Widget buildView() => const SheetViewerPage();
  @override Widget? buildCompactView() => null;
}
```

- [ ] **Step 5: Create SheetViewerPage with WebView**

```dart
// lib/plugins/sheet_viewer/sheet_viewer_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class SheetViewerPage extends StatefulWidget {
  const SheetViewerPage({super.key});
  @override State<SheetViewerPage> createState() => _SheetViewerPageState();
}

class _SheetViewerPageState extends State<SheetViewerPage> {
  InAppWebViewController? _controller;
  bool _osmdReady = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sheet Viewer')),
      body: InAppWebView(
        initialFile: 'assets/osmd/sheet_viewer.html', // will fix path in next step
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
        ),
        onWebViewCreated: (c) {
          _controller = c;
          c.addJavaScriptHandler(
            handlerName: 'onOsmdReady',
            callback: (_) => setState(() => _osmdReady = true),
          );
        },
        onLoadStop: (c, url) {
          c.evaluateJavascript(source: 'initOsmd()');
        },
      ),
    );
  }
}
```

- [ ] **Step 6: Register plugin in main.dart**

```dart
// In main.dart, add:
import 'plugins/sheet_viewer/sheet_viewer_plugin.dart';

final sheetViewer = SheetViewerPlugin();
await sheetViewer.init(container);
registry.register(sheetViewer);
```

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: add SheetViewer stub with inappwebview + OSMD HTML skeleton"
```

---

### Task 2: Built-in MusicXML + First Render

**Files:**
- Create: `violin_app/assets/sheet_music/twinkle_twinkle.musicxml`
- Create: `violin_app/assets/sheet_music/minuet_in_g.musicxml`
- Modify: `violin_app/lib/plugins/sheet_viewer/html/sheet_viewer.html`
- Modify: `violin_app/lib/plugins/sheet_viewer/sheet_viewer_page.dart`

**验收:** App 打开 Sheet Viewer 标签 → 自动加载并渲染 "小星星" 五线谱。

- [ ] **Step 1: Create Twinkle Twinkle MusicXML**

Create `violin_app/assets/sheet_music/twinkle_twinkle.musicxml` with minimal MusicXML for Twinkle Twinkle Little Star (violin key of D, single voice, 12 bars):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 4.0 Partwise//EN"
  "http://www.musicxml.org/dtds/partwise.dtd">
<score-partwise version="4.0">
  <part-list>
    <score-part id="P1"><part-name>Violin</part-name></score-part>
  </part-list>
  <part id="P1">
    <!-- Bar 1: D D A A -->
    <measure number="1">
      <attributes><divisions>4</divisions><time><beats>4</beats><beat-type>4</beat-type></time>
        <clef><sign>G</sign><line>2</line></clef></attributes>
      <note><pitch><step>D</step><octave>5</octave></pitch><duration>4</duration><type>quarter</type></note>
      <note><pitch><step>D</step><octave>5</octave></pitch><duration>4</duration><type>quarter</type></note>
      <note><pitch><step>A</step><octave>4</octave></pitch><duration>4</duration><type>quarter</type></note>
      <note><pitch><step>A</step><octave>4</octave></pitch><duration>4</duration><type>quarter</type></note>
    </measure>
    <!-- Bar 2: B B A-->
    <measure number="2">
      <note><pitch><step>B</step><octave>4</octave></pitch><duration>4</duration><type>quarter</type></note>
      <note><pitch><step>B</step><octave>4</octave></pitch><duration>4</duration><type>quarter</type></note>
      <note><pitch><step>A</step><octave>4</octave></pitch><duration>8</duration><type>half</type></note>
    </measure>
  </part>
</score-partwise>
```

- [ ] **Step 2: Create Minuet in G MusicXML**

Same format, basic 8-bar minuet excerpt (simplified).

- [ ] **Step 3: Update HTML to load built-in piece on init**

Modify `sheet_viewer.html` to load a piece after OSMD init:

```javascript
function initOsmd() {
  osmd = new opensheetmusicdisplay.OpenSheetMusicDisplay("osmd-container", {
    autoResize: true, backend: "svg", drawTitle: true,
  });
  window.flutter_inappwebview.callHandler('onOsmdReady', true);
}
// Called from Dart to load content
function loadMusicXml(xml) {
  osmd.load(xml).then(function() { osmd.render(); });
}
function loadBuiltIn(name) {
  // Dart passes the XML content directly
}
```

- [ ] **Step 4: Update SheetViewerPage to load built-in XML on ready**

```dart
// On OSMD ready, load built-in piece
void _onOsmdReady() {
  setState(() => _osmdReady = true);
  _loadBuiltIn('twinkle_twinkle');
}

Future<void> _loadBuiltIn(String name) async {
  final xml = await DefaultAssetBundle.of(context)
      .loadString('assets/sheet_music/$name.musicxml');
  _controller?.evaluateJavascript(
      source: "loadMusicXml(`${xml.replaceAll("'", "\\'").replaceAll('\n', ' ')}`);");
}
```

Note: For large XML, use `controller.postMessage()` with JS handler instead of string escaping.

Use JS handler approach:
```javascript
window.addEventListener('message', function(e) {
  if (e.data.type === 'loadXml') {
    loadMusicXml(e.data.xml);
  }
});
```

Dart side:
```dart
_controller?.evaluateJavascript(source: """
  window.postMessage({type: 'loadXml', xml: `${xml.replaceAll("'", "\\'")}`}, '*');
""");
```

Better: use `InAppWebViewController.evaluateJavascript` with a base64-encoded XML or use a file:// URI.

Simplest working approach: write XML to temp file, load via `initialFile`:
```dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<void> _loadBuiltIn(String name) async {
  final xml = await DefaultAssetBundle.of(context)
      .loadString('assets/sheet_music/$name.musicxml');
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$name.musicxml');
  await file.writeAsString(xml);
  // Use JS to load the file via fetch
  _controller?.evaluateJavascript(source: """
    fetch('${file.uri}').then(r => r.text()).then(xml => loadMusicXml(xml));
  """);
}
```

Or simplest: inject the XML directly via a JS variable:

```dart
// Escape single quotes and newlines
final escaped = xml.replaceAll("'", "\\'").replaceAll('\n', '\\n');
_controller?.evaluateJavascript(source: "loadMusicXml('$escaped');");
```

For now, the simplest approach: use `evaluateJavascript` with escaped string. It works for small files (<100KB).

- [ ] **Step 5: Run and verify**

```bash
flutter run -d windows
```

Expected: Click "Sheet Viewer" in toolbar → OSMD renders a 2-bar "Twinkle Twinkle" score.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: built-in MusicXML + first sheet music render in OSMD WebView"
```

---

### Task 3: File Import (file_picker)

**Files:**
- Modify: `violin_app/lib/plugins/sheet_viewer/sheet_viewer_page.dart`

**验收:** 点 AppBar "导入" 按钮 → 系统文件选择器打开 → 选 .musicxml 文件 → WebView 渲染新谱。

- [ ] **Step 1: Add import button + logic**

```dart
// In SheetViewerPage AppBar:
actions: [
  IconButton(
    icon: const Icon(Icons.file_open),
    tooltip: 'Import',
    onPressed: _importFile,
  ),
],

Future<void> _importFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['musicxml', 'mxl', 'xml'],
  );
  if (result == null || result.files.isEmpty) return;
  final file = File(result.files.single.path!);
  final xml = await file.readAsString();
  final escaped = xml.replaceAll("'", "\\'").replaceAll('\n', '\\n');
  _controller?.evaluateJavascript(source: "loadMusicXml('$escaped');");
}
```

- [ ] **Step 2: Run and verify**

```bash
flutter run -d windows
# Click Import → select a .musicxml file → verify it renders
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add file import — file_picker loads MusicXML into OSMD WebView"
```

---

### Task 4: Playhead Overlay Widget

**Files:**
- Create: `violin_app/lib/plugins/sheet_viewer/widgets/playhead_overlay.dart`
- Modify: `violin_app/lib/plugins/sheet_viewer/sheet_viewer_page.dart`

**验收:** 点 "跟谱" 按钮 → 半透明竖线出现在谱面上方 → 手指拖动竖线左右移动 → 松手时 UI 显示 "起点已标记"。

- [ ] **Step 1: Create PlayheadOverlay**

```dart
// widgets/playhead_overlay.dart
import 'package:flutter/material.dart';

class PlayheadOverlay extends StatefulWidget {
  final bool visible;
  final double? lockedX; // non-null when tracking
  final ValueChanged<double>? onPositionSelected;

  const PlayheadOverlay({
    super.key,
    this.visible = false,
    this.lockedX,
    this.onPositionSelected,
  });

  @override State<PlayheadOverlay> createState() => _PlayheadOverlayState();
}

class _PlayheadOverlayState extends State<PlayheadOverlay> {
  double _x = 0;

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    final x = widget.lockedX ?? _x;

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanUpdate: widget.lockedX == null
            ? (d) => setState(() => _x = (_x + d.delta.dx).clamp(20.0, 500.0))
            : null,
        onPanEnd: widget.lockedX == null
            ? (_) => widget.onPositionSelected?.call(_x)
            : null,
        child: Stack(
          children: [
            // Vertical line
            Positioned(
              left: x - 1.5,
              top: 0, bottom: 0,
              child: Container(
                width: 3,
                color: Colors.amber.withAlpha(180),
              ),
            ),
            // Drag handle
            Positioned(
              left: x - 12,
              top: 0, bottom: 0,
              child: Center(
                child: Container(
                  width: 24, height: 48,
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(100),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.drag_handle, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Integrate into SheetViewerPage**

Wrap WebView in a Stack, add PlayheadOverlay on top. Add a "跟谱" button in AppBar.

```dart
// In SheetViewerPage state:
bool _trackingMode = false;
double? _playheadX; // locked position during tracking

// In build():
Stack(
  children: [
    InAppWebView(...),
    PlayheadOverlay(
      visible: _trackingMode,
      lockedX: _playheadX,
      onPositionSelected: (x) {
        setState(() => _playheadX = x);
        _queryNearestNote(x); // JS Bridge, Task 5
      },
    ),
  ],
),
```

- [ ] **Step 3: Run and verify**

```bash
flutter run -d windows
# Open Sheet Viewer → tap "跟谱" → vertical line appears → drag it → verify handle moves
```

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: add draggable playhead overlay on sheet music WebView"
```

---

### Task 5: JS Bridge — Pixel to Note Mapping

**Files:**
- Modify: `violin_app/lib/plugins/sheet_viewer/html/sheet_viewer.html`
- Create: `violin_app/lib/plugins/sheet_viewer/services/osmd_bridge.dart`

**验收:** 拖动播放头松手后，JS Bridge 返回最近音符索引，Dart 打印 `Nearest note: 5`。

- [ ] **Step 1: Add JS handler for getNoteAtPixel**

In `sheet_viewer.html`, already have `getNoteAtPixel(x)` function. Wire it up:

```javascript
// Register a handler Dart can call
window.flutter_inappwebview.callHandler('onOsmdReady', true);
```

In Dart, add a handler registration after WebView creation:

```dart
_controller?.addJavaScriptHandler(
  handlerName: 'getNoteIndex',
  callback: (args) {
    final index = args[0] as int;
    debugPrint('Nearest note: $index');
    setState(() { _trackingNoteIndex = index; });
  },
);
```

And on playhead release:
```dart
void _queryNearestNote(double x) {
  _controller?.evaluateJavascript(source: """
    var idx = getNoteAtPixel($x);
    window.flutter_inappwebview.callHandler('getNoteIndex', idx);
  """);
}
```

- [ ] **Step 2: Create OSMDBridge service class**

```dart
// services/osmd_bridge.dart
class OSMDBridge {
  final InAppWebViewController _controller;
  OSMDBridge(this._controller);

  Future<void> loadXml(String xml) {
    final escaped = xml.replaceAll("'", "\\'").replaceAll('\n', '\\n');
    return _controller.evaluateJavascript(source: "loadMusicXml('$escaped');");
  }

  Future<void> highlightNote(int index) {
    return _controller.evaluateJavascript(source: "highlightNote($index);");
  }

  Future<void> nextPage() {
    return _controller.evaluateJavascript(source: "nextPage();");
  }

  Future<void> prevPage() {
    return _controller.evaluateJavascript(source: "prevPage();");
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: JS Bridge pixel-to-note mapping + OSMDBridge service class"
```

---

### Task 6: MusicXmlParser — Extract Note Sequence

**Files:**
- Create: `violin_app/lib/plugins/sheet_viewer/services/music_xml_parser.dart`
- Create: `violin_app/test/plugins/sheet_viewer/music_xml_parser_test.dart`

**验收:** 解析 Twinkle Twinkle MusicXML → 输出 11 个音符序列，每个含 `{pitch, octave, measure, beat}`。

- [ ] **Step 1: Write test**

```dart
// test/plugins/sheet_viewer/music_xml_parser_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:violin_app/plugins/sheet_viewer/services/music_xml_parser.dart';

void main() {
  test('parses twinkle twinkle MusicXML correctly', () {
    const xml = '''<?xml version="1.0"?>
    <score-partwise><part-list><score-part id="P1"/></part-list>
    <part id="P1">
      <measure number="1"><attributes><divisions>4</divisions><time><beats>4</beats></time><clef><sign>G</sign><line>2</line></clef></attributes>
        <note><pitch><step>D</step><octave>5</octave></pitch><duration>4</duration></note>
        <note><pitch><step>A</step><octave>4</octave></pitch><duration>4</duration></note>
      </measure>
    </part></score-partwise>''';

    final notes = MusicXmlParser.parse(xml);
    expect(notes.length, 2);
    expect(notes[0].step, 'D');
    expect(notes[0].octave, 5);
    expect(notes[0].measure, 1);
    expect(notes[1].step, 'A');
    expect(notes[1].octave, 4);
  });
}
```

- [ ] **Step 2: Run test — expected fail**

```bash
flutter test test/plugins/sheet_viewer/music_xml_parser_test.dart
```

Expected: FAIL — `MusicXmlParser` not defined.

- [ ] **Step 3: Implement parser**

```dart
// services/music_xml_parser.dart
import 'package:xml/xml.dart';

class ParsedNote {
  final String step;    // C, D, E, F, G, A, B
  final int octave;     // 4, 5, etc.
  final int measure;    // measure number
  final int beat;       // beat within measure (1-indexed)
  final int duration;   // divisions

  const ParsedNote({
    required this.step, required this.octave,
    required this.measure, required this.beat, required this.duration,
  });

  String get noteName => '$step$octave';
}

class MusicXmlParser {
  static List<ParsedNote> parse(String xmlString) {
    final doc = XmlDocument.parse(xmlString);
    final notes = <ParsedNote>[];
    int divisions = 4;
    int measureNum = 0;
    int beatPosition = 0;

    for (final measure in doc.findAllElements('measure')) {
      measureNum++;
      // Reset beat position per measure
      for (final note in measure.findAllElements('note')) {
        // Skip rests
        if (note.findAllElements('rest').isNotEmpty) continue;
        if (note.findAllElements('pitch').isEmpty) continue;

        final pitch = note.findAllElements('pitch').first;
        final step = pitch.findAllElements('step').first.innerText;
        final octave = int.parse(pitch.findAllElements('octave').first.innerText);
        final durStr = note.findAllElements('duration').first.innerText;
        final duration = int.tryParse(durStr) ?? 1;

        notes.add(ParsedNote(
          step: step, octave: octave,
          measure: measureNum,
          beat: beatPosition ~/ divisions + 1,
          duration: duration,
        ));
        beatPosition += duration;
      }
    }
    return notes;
  }
}
```

- [ ] **Step 4: Run test — expected pass**

```bash
flutter test test/plugins/sheet_viewer/music_xml_parser_test.dart
```

Expected: PASS — 2 notes parsed correctly.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: MusicXmlParser — extract note sequence from MusicXML"
```

---

### Task 7: NoteTracker — Sliding Window Match + Highlight

**Files:**
- Create: `violin_app/lib/plugins/sheet_viewer/services/note_tracker.dart`
- Create: `violin_app/test/plugins/sheet_viewer/note_tracker_test.dart`
- Modify: `violin_app/lib/plugins/sheet_viewer/sheet_viewer_page.dart`

**验收:** Demo 模式下乐谱自动跟随 — 当前音符黄色高亮，播放头移动到正确位置。

- [ ] **Step 1: Write test**

```dart
// test/plugins/sheet_viewer/note_tracker_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:violin_app/plugins/sheet_viewer/services/note_tracker.dart';
import 'package:violin_app/plugins/sheet_viewer/services/music_xml_parser.dart';

void main() {
  test('sliding window match finds correct note', () {
    final notes = [
      ParsedNote(step: 'D', octave: 5, measure: 1, beat: 1, duration: 4),
      ParsedNote(step: 'A', octave: 4, measure: 1, beat: 2, duration: 4),
      ParsedNote(step: 'B', octave: 4, measure: 1, beat: 3, duration: 4),
      ParsedNote(step: 'G', octave: 4, measure: 1, beat: 4, duration: 4),
    ];
    final tracker = NoteTracker(notes, startIndex: 0);

    // Match D5
    var result = tracker.match('D', 5);
    expect(result, isNotNull);
    expect(result!.matchedIndex, 0);

    // Skip ahead — should find A4 in window
    result = tracker.match('B', 4);
    expect(result, isNotNull);
    expect(result!.matchedIndex, 2);
  });

  test('returns null when no match in window', () {
    final notes = [ParsedNote(step: 'D', octave: 5, measure: 1, beat: 1, duration: 4)];
    final tracker = NoteTracker(notes, startIndex: 0);
    final result = tracker.match('F', 7); // F7 not in score
    expect(result, isNull);
  });
}
```

- [ ] **Step 2: Run test — expected fail**

```bash
flutter test test/plugins/sheet_viewer/note_tracker_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implement NoteTracker**

```dart
// services/note_tracker.dart
class TrackResult {
  final int matchedIndex;
  TrackResult(this.matchedIndex);
}

class NoteTracker {
  final List<ParsedNote> _notes;
  int _currentIndex;
  static const _windowSize = 3;

  NoteTracker(this._notes, {required int startIndex})
      : _currentIndex = startIndex;

  TrackResult? match(String step, int octave) {
    final start = (_currentIndex - _windowSize).clamp(0, _notes.length - 1);
    final end = (_currentIndex + _windowSize).clamp(0, _notes.length - 1);

    for (int i = start; i <= end; i++) {
      if (_notes[i].step == step && _notes[i].octave == octave) {
        _currentIndex = i;
        return TrackResult(i);
      }
    }
    return null; // no match — stay at current position
  }

  int get currentIndex => _currentIndex;
  ParsedNote get currentNote => _notes[_currentIndex];
}
```

- [ ] **Step 4: Run test — expected pass**

```bash
flutter test test/plugins/sheet_viewer/note_tracker_test.dart
```

Expected: PASS — 2 tests pass.

- [ ] **Step 5: Wire NoteTracker to SheetViewerPage**

In SheetViewerPage, after playhead selects start index + AudioEngine pitchStream:

```dart
// On playhead release:
void _startTracking(int startIndex) {
  final notes = MusicXmlParser.parse(_currentXml);
  _tracker = NoteTracker(notes, startIndex: startIndex);

  // Subscribe to pitch stream
  final audio = ref.read(audioEngineProvider);
  _pitchSub = audio.pitchStream.listen((pitch) {
    final match = RegExp(r'^([A-G]#?)(\d+)').firstMatch(pitch.note);
    if (match == null) return;
    final result = _tracker!.match(match.group(1)!, int.parse(match.group(2)!));
    if (result != null) {
      _bridge.highlightNote(result.matchedIndex);
      // Auto-flip: if near end of page, advance
      if (result.matchedIndex >= notes.length - 2) {
        _bridge.nextPage();
      }
      setState(() => _trackedIndex = result.matchedIndex);
    }
  });
}
```

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: NoteTracker sliding window match + highlight + auto-page-flip"
```

---

### Task 8: Final Integration & Test

- [ ] **Step 1: Run full test suite**

```bash
flutter test
flutter build windows --debug
```

Expected: All tests pass, app builds.

- [ ] **Step 2: Manual smoke test**

```bash
flutter run -d windows
```

1. Click "Sheet Viewer" → built-in "Twinkle Twinkle" renders
2. Click "Import" → select external .musicxml file → renders
3. Click "跟谱" → playhead appears → drag to first note → release
4. If mic is on and tuner is detecting pitch → notes highlight as played

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore: finalize Plan 3 — sheet viewing + import + auto-tracking"
```

---

## Plan 3 Summary

After 8 Tasks:
- ✅ WebView + OSMD renders MusicXML
- ✅ Built-in example pieces (Twinkle Twinkle, Minuet in G)
- ✅ File import via file_picker
- ✅ Draggable playhead overlay
- ✅ JS Bridge position → note mapping
- ✅ MusicXmlParser extracts note sequences
- ✅ NoteTracker sliding window match + highlight + auto-flip
- ✅ SheetViewerPlugin registered in app shell
