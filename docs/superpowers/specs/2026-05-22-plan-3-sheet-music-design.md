# Plan 3 — 乐谱系统设计文档

> 状态：设计确认，待写 plan

## 目标

在 App 内显示五线谱、导入 MusicXML 文件、自动跟踪演奏位置。

## 最低交付

1. **SheetViewer 插件** — WebView + OSMD 渲染五线谱
2. **乐谱导入** — 内置示例曲 + 从文件系统导入 MusicXML
3. **可拖拽播放头** — 竖线表示当前位置，拖动定位，松手锁定起点
4. **自动跟谱** — YIN 实时匹配 → 高亮当前音符 → 播放头自动右移 → 自动翻页

## 技术选型

| 层面 | 选型 | 说明 |
|------|------|------|
| 乐谱渲染 | **OpenSheetMusicDisplay (OSMD)** | JavaScript 库，内嵌到 assets |
| WebView | **flutter_inappwebview** | 性能优于官方 webview_flutter |
| OSMD 加载 | **内嵌 assets** | ~2MB JS bundle 打包进应用，离线可用 |
| JS 通信 | JavaScript Channel | Flutter ↔ OSMD 双向通信 |
| 播放头 | **Flutter 半透明 Overlay** | 竖线盖在 WebView 上方，GestureDetector 拖动 |
| 位置映射 | 像素 → OSMD 内部坐标 → 音符索引 | 拖拽松手时 JS Bridge 查询最近音符 |
| MusicXML 解析 | Dart `xml` 包 | 提取音符序列用于跟谱匹配 |
| 文件导入 | `file_picker` 包 | 选择 .musicxml/.mxl 文件 |
| 跟谱匹配 | 滑动窗口 (窗口大小=3) | 实时 YIN 输出 vs 谱面音符序列 |

## UI 布局

```
┌──────────────────────────────────┐
│  Sheet Viewer      [导入] [跟谱] │  ← AppBar
│                                  │
│ ┌──────────────────────────────┐ │
│ │              ▌ ← 可拖竖线    │ │  ← Flutter 半透明 overlay
│ │              ▌   (播放头)     │ │
│ │  ♩  ♩  ♩  ♩ ▌ ♩  ♩  ♩     │ │  ← OSMD 渲染在 WebView 中
│ │              ▌                │ │
│ │              ▌                │ │
│ └──────────────────────────────┘ │
│                                  │
│   [⏪] [⏵]     ● 跟谱中          │  ← 底栏：导航 + 跟谱状态
└──────────────────────────────────┘
```

## 播放头交互

1. **未跟谱时**：竖线隐藏
2. **点"跟谱"**：竖线出现在屏幕中央，可拖动
3. **拖动到目标音符**：手指在竖线上滑动 → 竖线跟随 x 轴移动
4. **松手**：JS Bridge 把竖线 x 位置 → OSMD 内部坐标 → 最近音符索引 → 锁定起点
5. **跟踪中**：竖线随当前音符自动右移，到达页面底部 → 触发 OSMD 翻页
6. **拖拽跳转**：跟踪中也允许拖动竖线跳到新位置，即刻重新锁定

## 架构

```
┌─────────────────────────────────────────────────────┐
│                  Dart Layer                          │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │  SheetViewer Plugin                           │   │
│  │                                               │   │
│  │  ┌──────────┐  ┌──────────┐  ┌────────────┐  │   │
│  │  │ Playhead │  │ WebView  │  │ NoteTracker │  │   │
│  │  │ Overlay  │  │ (OSMD)   │  │             │  │   │
│  │  │          │  │          │  │ 滑动窗口    │  │   │
│  │  │ 拖拽竖线 │  │ JS Bridge│  │ 高亮+翻页  │  │   │
│  │  └────┬─────┘  └────┬─────┘  └─────┬───────┘  │   │
│  │       │             │              │           │   │
│  │       └─────────────┴──────────────┘           │   │
│  │                  ↕ JS Channel                  │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  ┌────────────────┐  ┌───────────────────────────┐  │
│  │ MusicXmlParser │  │ AudioEngine (已有)         │  │
│  │ (Dart xml 包)  │  │ pitchStream → NoteTracker  │  │
│  └────────────────┘  └───────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

## 播放头位置映射 (关键算法)

```
Playhead Overlay 层 (Flutter Widget, 半透明竖线)
     │
     │ 手指拖动
     ▼
  GestureDetector.onPanUpdate → 更新竖线 x 位置
     │
     │ 手指抬起 (onPanEnd)
     ▼
  JS Bridge: osmd.getNearestNoteAt(xPixel)
     │
     ▼
  Dart 收到音符索引 → 调用 NoteTracker.startTracking(index)
```

## 音符跟踪算法

```
1. 解析 MusicXML → 音符序列 [{pitch, startTime, duration, measureIndex}]
2. 用户拖动播放头到目标位置 → JS Bridge → 确定起始音符索引
3. 每收到 YIN 音高 → 转音符名 → 在序列中搜索
4. 滑动窗口 (窗口大小=3)：当前音符 ±1 开窗匹配
5. 匹配命中 → JS Bridge: osmd.highlightNote(index) → 竖线自动移到新位置
6. 竖线到达页面右边缘 → JS Bridge: osmd.nextPage()
```

## 插件接口

```dart
class SheetViewerPlugin extends ToolPlugin {
  // 插件元数据
  @override String get id => 'sheet_viewer';

  // 乐谱加载
  Future<void> loadMusicXml(String xmlContent, {String? title});
  Future<void> loadFromFile(String filePath);
  Future<void> loadBuiltIn(String pieceId);

  // 跟谱控制
  void enterTrackingMode();       // 显示播放头，等待拖动定位
  void exitTrackingMode();        // 隐藏播放头，停止高亮
  void onPitchDetected(PitchResult pitch); // 从 AudioEngine 接入
}
```

## 执行顺序

1. **WebView 集成** — 添加 `flutter_inappwebview` 依赖，加载本地 HTML (内嵌 OSMD JS)
2. **内置示例曲** — assets 放 2-3 首 MusicXML，渲染第一份五线谱
3. **文件导入** — `file_picker` 选 .musicxml/.mxl，加载到 OSMD
4. **Playhead Overlay** — 半透明竖线 + 拖拽手势
5. **JS Bridge 位置映射** — 像素坐标 → OSMD 音符索引
6. **MusicXmlParser** — Dart `xml` 解析音符序列
7. **NoteTracker** — 滑动窗口匹配 + 高亮 + 自动翻页

## 关键风险

| 风险 | 应对 |
|------|------|
| WebView 在 Android 低端机性能 | 预渲染策略，减小 OSMD 谱面复杂度 |
| OSMD JS 文件较大 (~2MB) | 内嵌到 assets，不依赖网络加载 |
| YIN 音高 ↔ 谱面音符映射错误 | 滑动窗口容错，允许 ±1 音符偏差 |
| 播放头位置映射不准确 | 先用 OSMD 提供的 `getNearestNote` API，测绘偏移量 |
| MusicXML 格式差异 (不同软件导出) | 先用 MuseScore 导出的标准格式 |
| WebView 加载慢 (冷启动) | 应用启动时预初始化 WebView |
