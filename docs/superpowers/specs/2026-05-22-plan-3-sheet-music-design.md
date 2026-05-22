# Plan 3 — 乐谱系统设计文档

> 状态：设计确认，待写 plan

## 目标

在 App 内显示五线谱、导入 MusicXML 文件、自动跟踪演奏位置。

## 最低交付

1. **SheetViewer 插件** — WebView + OSMD 渲染五线谱
2. **乐谱导入** — 内置示例曲 + 从文件系统导入 MusicXML
3. **自动跟谱** — 手动标记起点 → 实时音高匹配 → 高亮当前音符 → 自动翻页

## 技术选型

| 层面 | 选型 | 说明 |
|------|------|------|
| 乐谱渲染 | **OpenSheetMusicDisplay (OSMD)** | JavaScript 库，WebView 加载。最成熟的 MusicXML 渲染引擎 |
| WebView | **flutter_inappwebview** | 性能优于官方 webview_flutter |
| JS 通信 | JavaScript Channel | Flutter ↔ OSMD 双向通信 |
| MusicXML 解析 | Dart `xml` 包 | 提取音符序列用于跟谱匹配 |
| 文件导入 | `file_picker` 包 | 选择 .musicxml/.mxl 文件 |
| 跟谱匹配 | 滑动窗口 + DTW | 实时 YIN 输出 vs 谱面音符序列 |

## 架构

```
┌─────────────────────────────────────────────────────┐
│                  Dart Layer                          │
│                                                      │
│  ┌────────────────┐  ┌───────────────────────────┐  │
│  │ SheetViewer    │  │ NoteTracker                │  │
│  │ Plugin         │  │ (滑动窗口匹配)             │  │
│  │                │  │                            │  │
│  │ WebView        │  │ YIN音高 → 音符名 → 索引   │  │
│  │   ├ OSMD 渲染  │  │                            │  │
│  │   ├ JS Bridge  │  │ 高亮当前音符              │  │
│  │   └ 触摸起点   │  │ 自动翻页                  │  │
│  └───────┬────────┘  └──────────┬────────────────┘  │
│          │                      │                    │
│  ┌───────┴──────────────────────┴────────────────┐  │
│  │         MusicXmlParser (Dart xml 包)          │  │
│  │         提取音符序列 + 小节结构               │  │
│  └───────────────────────────────────────────────┘  │
│                                                      │
│  ┌────────────────────────────────────────────────┐  │
│  │           AudioEngine (已有)                    │  │
│  │           pitchStream → NoteTracker             │  │
│  └────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

## 音符跟踪算法

```
1. 解析 MusicXML → 音符序列 [{pitch, startTime, duration}]
2. 用户点击谱面 → 确定起始音符索引
3. 每收到 YIN 音高 → 转音符名 → 在序列中搜索
4. 滑动窗口 (窗口大小=3)：当前音符 ±1 开窗匹配
5. 匹配命中 → 通过 JS Bridge 高亮 OSMD 中对应音符
6. 当前音符靠近页面底部 → 触发 OSMD 翻页
```

## 插件接口

```dart
class SheetViewerPlugin extends ToolPlugin {
  // 加载谱面
  Future<void> loadMusicXml(String xmlContent, {String? sourceName});
  Future<void> loadFromFile(String filePath);
  Future<void> loadBuiltIn(String pieceId);

  // 跟谱控制
  void startTracking(int startNoteIndex);
  void stopTracking();
  void onPitchDetected(PitchResult pitch); // 从 AudioEngine 接入
}
```

## 执行顺序

1. WebView 集成 — flutter_inappwebview + 加载本地 HTML (含 OSMD JS)
2. 加载示例 MusicXML — 渲染第一份五线谱
3. 文件导入 — file_picker + 加载自定义谱
4. MusicXmlParser — Dart 端解析音符序列
5. NoteTracker — 滑动窗口匹配 + 高亮
6. 自动翻页 — 检测到达页面底部时触发 OSMD 翻页

## 关键风险

| 风险 | 应对 |
|------|------|
| WebView 在 Android 低端机性能 | 预渲染策略，减小 OSMD 谱面复杂度 |
| OSMD JS 文件较大 (~2MB) | 内嵌到 assets，不依赖网络加载 |
| YIN 音高 ↔ 谱面音符映射错误 | 滑动窗口容错，允许 ±1 音符偏差 |
| MusicXML 格式差异 (不同软件导出) | 先用 MuseScore 导出的标准格式 |
