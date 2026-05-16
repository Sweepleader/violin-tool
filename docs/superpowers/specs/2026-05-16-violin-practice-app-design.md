# 小提琴智能陪练软件 — 功能需求汇总

## 项目定位
不只是陪练工具，更是一个全面的小提琴演奏辅助工具。支持 Windows + Android 双平台。

## 核心功能模块

### 1. 乐谱系统
- 乐谱显示与渲染（MusicXML / ABC 格式支持）
- 导入音乐文件、生成曲谱
- 乐谱滚动/翻页（自动跟随练习进度）
- 多声部/合奏谱支持

### 2. 音频工具
- 调音辅助（基础调音器）
- 节拍器（可视化 + 音频节拍）
- 实时音准检测 — 麦克风拾音，可视化显示音高偏差
- 录音与回放分析 — 变速播放、段落标记、对比进步
- 分段循环练习 — A-B 段落循环 + 渐进加速

### 3. 智能练习系统
- LLM 驱动的练习计划生成
- 每日热身自动生成（音阶 + 练习曲片段）
- 练习数据追踪 — 时长、频率、音准趋势、曲目完成度
- 视奏训练 — 随机生成片段，难度递增

### 4. 参考工具
- 交互式指法与把位图 — 各调式音阶指法参考
- 基础入门引导（作为辅助小功能）

### 5. 曲目管理
- 曲目库 — 按难度、风格、作曲家组织
- 练习状态标记（待练 / 进行中 / 已掌握）
- 曲目与练习计划关联同步

### 6. 其他
- 伴奏系统 — 钢琴/乐队伴奏，可调速移调
- 弓法分析 — 音频推测弓速、弓压
- 考级/比赛曲目模板（如 ABRSM、国内考级）

---

## 技术栈

| 层面 | 选型 | 说明 |
|------|------|------|
| 跨平台框架 | **Flutter** (Dart) | 单代码库编译 Windows 原生 + Android 原生 |
| 音频 I/O | **PortAudio** (C) | 跨平台低延迟音频采集，通过 dart:ffi 调用 |
| 音高检测 | **Aubio** (C) 或 **TarsosDSP** (Java → FFI) | YIN / MPM 算法，实时音高提取 |
| 乐谱渲染 | **OpenSheetMusicDisplay (OSMD)** (JS) | WebView 嵌入，支持 MusicXML 渲染 |
| 合成音频 | **FluidSynth** (C, FFI) | MIDI → WAV，节拍器声音、伴奏回放，走统一音频管线 |
| LLM 接入 | **Windows**: Ollama 本地 / **Android**: OpenAI API 或云中转 | 练习计划生成、曲目推荐。Android 端 Ollama 最小模型需 8GB+ 内存不可行 |
| 本地存储 | **SQLite** (drift) + **SharedPreferences** | 曲目库、练习记录、用户偏好、插件配置 |
| 依赖注入 | **Riverpod** | 全局服务发现、插件状态管理 |
| 路由 | **go_router** | 插件页面路由 |
| Trace/评估 | **Trace Logger** + **Eval Engine** | Agent 调用全链路日志，客观评测（音准偏差%等） |

### 架构总览：插件化工具系统

以 v2 插件架构为基础，在三个精准点引入 Agentic 能力（详见下一节）。

```
┌──────────────────────────────────────────────────┐
│              App Shell (主框架)                   │
│                                                   │
│  ┌─────────────────────────────────────────────┐ │
│  │          Global Services (Riverpod)          │ │
│  │  ┌──────────┐ ┌──────────┐ ┌────────────┐  │ │
│  │  │AudioEngine│ │Database  │ │ LLM Client │  │ │
│  │  │PortAudio │ │ SQLite   │ │Windows:    │  │ │
│  │  │Aubio     │ │ drift    │ │ Ollama     │  │ │
│  │  │FluidSynth│ │          │ │Android:API │  │ │
│  │  └──────────┘ └──────────┘ └────────────┘  │ │
│  │  ┌──────────────┐ ┌──────────────────────┐   │ │
│  │  │ Trace Logger │ │ Eval Engine          │   │ │
│  │  │ (新增)       │ │ (新增)               │   │ │
│  │  └──────────────┘ └──────────────────────┘   │ │
│  └─────────────────────────────────────────────┘ │
│                                                   │
│  ┌─────────────────────────────────────────────┐ │
│  │           Plugin Registry                    │ │
│  │  发现 → 注册 → 生命周期 → 依赖注入          │ │
│  └─────────────────────────────────────────────┘ │
│                                                   │
│  ┌──────┐ ┌──────┐ ┌────────┐ ┌──────────────┐  │
│  │Tuner │ │Metro-│ │Sheet   │ │Practice      │  │
│  │Plugin│ │nome  │ │Viewer  │ │Planner       │  │
│  │      │ │Plugin│ │Plugin  │ │Plugin        │  │
│  └──────┘ └──────┘ └────────┘ └──────────────┘  │
│  ┌──────┐ ┌──────┐ ┌────────┐ ┌──────────────┐  │
│  │Recor-│ │Finge-│ │Sight-  │ │Progress      │  │
│  │ding  │ │ring  │ │Reading │ │Tracker       │  │
│  │Plugin│ │Plugin│ │Plugin  │ │Plugin        │  │
│  └──────┘ └──────┘ └────────┘ └──────────────┘  │
│  ┌──────┐ ┌──────┐ ┌────────┐ ┌──────────────┐  │
│  │Back- │ │Warmup│ │Bow     │ │Repertoire    │  │
│  │ingTrk│ │Gen   │ │Analysis│ │Manager       │  │
│  │Plugin│ │Plugin│ │Plugin  │ │Plugin        │  │
│  └──────┘ └──────┘ └────────┘ └──────────────┘  │
│  ┌──────────────┐ ┌────────────────────────────┐ │
│  │BeginnerGuide │ │ExamTemplate                │ │
│  │Plugin        │ │Plugin                      │ │
│  └──────────────┘ └────────────────────────────┘ │
└──────────────────────────────────────────────────┘
```

### ToolPlugin 接口

```dart
abstract class ToolPlugin {
  String get id;
  String get name;
  String get description;
  IconData get icon;

  Future<void> init(PluginContext context);
  Widget buildView();
  Widget? buildCompactView();
  List<PluginAction> get actions;
  Future<void> dispose();
}

class PluginContext {
  AudioEngine get audio;
  Database get db;
  LlmClient get llm;
  TraceLogger get trace;   // 新增
  PluginRegistry get registry;
}
```

### Agentic 能力：3 项精准引入（非完整 Agent 层）

仅引入能直接解决用户痛点的模式，不作为独立架构层存在。

#### A. Trace Logger + Eval Engine（必须）

**解决的问题**：Agent 生成的练习计划质量如何？音准检测的准确率？没有量化反馈就无法迭代优化。

- `TraceLogger`：记录每次 LLM 调用的输入/输出/耗时/成功失败，每个 Plugin 的关键操作
- `Eval Engine`：
  - 客观评测：音准偏差 %、练习计划完成率、用户标记的"有用"次数
  - 主观评测：LLM-as-judge 对生成的练习计划打分（1-5）
  - 二元评测："此计划是否符合当前水平？yes/no"
- `TraceViewer`：在 App 设置页可视化执行日志，方便调试

#### B. 双模型反思（用于练习计划生成）

**解决的问题**：单个模型生成的练习计划可能偏难/偏易/遗漏基本功。

- Generator（轻量模型，如 Claude Haiku / GPT-3.5-turbo）→ 快速生成计划草稿
- Critic（强模型，如 Claude Sonnet / GPT-4o）→ 审查并给出修改意见
- Generator → 根据意见修订 → 最终输出
- 仅在网络可用时启用；离线时降级为单模型直接输出

#### C. Human-in-the-Loop 节点

**解决的问题**：LLM 生成的计划不应自动生效，关键决策需要用户确认。

- 练习计划生成后 → 用户预览 + 确认/修改
- 自定义自主性级别：完全自动 / 半自动（默认）/ 纯手动
- 技术实现：在 `PracticePlanner` 和 `WarmupGen` 插件中加入确认步骤，非独立 HITL Manager

## 开发环境需求

### 必装工具

| 工具 | 用途 | 下载 |
|------|------|------|
| **Flutter SDK** | 框架本体，含 Dart SDK | `winget install Flutter.Flutter` 或 flutter.dev |
| **Android Studio** | Android SDK、模拟器、Gradle 构建链 | developer.android.com/studio |
| **Visual Studio 2022 Community** | Windows 桌面编译所需的 C++ 工具链 | `winget install Microsoft.VisualStudio.2022.Community` |
| **VS Code**（推荐）或 Android Studio | 日常编码 IDE | code.visualstudio.com |
| **Git** | 版本管理 | `winget install Git.Git` |

### VS Code 推荐插件

- **Flutter** (官方) — Dart 支持 + 热重载 + Widget 预览
- **Flutter Riverpod Snippets** — 状态管理快捷代码
- **CMake Tools** — C 原生库构建辅助
- **Android iOS Emulator** — 模拟器管理

### 环境变量配置

安装完成后需确保以下命令可用：
```bash
flutter doctor    # 检查 Flutter 环境完整性
dart --version    # Dart SDK
git --version     # Git
```

`flutter doctor` 会自动检测 Android SDK、Visual Studio Build Tools、Windows SDK 等是否齐全，按提示补装即可。

### 原生音频库编译链

项目中的 C 音频库（PortAudio、Aubio）会通过 CMake 编译：
- Windows：MSVC 工具链（随 VS 2022 安装）
- Android：NDK（随 Android Studio 安装，通过 `sdkmanager` 获取）

---

## 核心技术风险与应对

### 风险 1：Flutter + C 音频库 FFI 集成（最高风险）

| 问题 | 详情 |
|------|------|
| 编译链差异 | Windows (MSVC) 和 Android (NDK/Clang) 的 C 编译器行为不同，ABI 兼容性需逐平台验证 |
| 音频权限 | Android 需动态申请 `RECORD_AUDIO` 权限，Android 13+ 额外需要 `POST_NOTIFICATIONS` |
| 低延迟保证 | PortAudio 在 Android 上默认走 OpenSL ES，延迟约 20-50ms；如需更低延迟需用 AAudio（API 26+）或 Oboe 库 |
| 线程模型 | Dart FFI 回调在 C 线程执行，不能直接操作 Flutter UI，需通过 `Isolate` + `SendPort` 传递音频数据 |

**应对**：
- Phase 1 优先在 Windows 端跑通完整音频管线，Android 端先用 `record` 包（纯 Dart）做高延迟版本
- Phase 2 引入 Oboe（Google 官方 C++ 音频库）替代 PortAudio 的 Android 后端，降低延迟
- 音频数据通过 `RingBuffer`（C 侧写入，Dart 侧轮询读取）而非回调，避免线程问题

### 风险 2：WebView 嵌入 OSMD 的性能

| 问题 | 详情 |
|------|------|
| Android 低端机 | OSMD 渲染复杂五线谱（多声部、密集音符）时，WebView 可能出现卡顿或白屏 |
| 内存占用 | WebView + OSMD JS bundle 初始内存约 50-80MB，持续渲染可能增长 |

**应对**：
- 乐谱预处理：将 MusicXML 在 Dart 侧预先分页/分段，每次只渲染当前页面
- 使用 `flutter_inappwebview`（比官方 `webview_flutter` 性能更好）
- 降级方案：简单乐谱（单声部练习曲）用 Canvas 自绘，复杂乐谱才走 WebView

### 风险 3：Ollama 在 Android 上不可行

| 问题 | 详情 |
|------|------|
| 内存要求 | Ollama 运行 1B 参数模型也需 4-8GB RAM，中低端 Android 设备（2-4GB）完全不可行 |
| 功耗 | 本地推理持续耗电，不适合陪练场景长时间使用 |

**应对**：
- **Windows 端**：Ollama 本地推理，支持离线使用，推荐模型 qwen2.5:3b 或 llama3.2:3b（练习计划生成对推理能力要求不高）
- **Android 端**：走云端 API（OpenAI / Claude API），通过 LiteLLM 或自建云函数做统一接口
- 可选方案：部署一台低功耗本地服务器（如树莓派 5 运行 Ollama），两端都通过局域网 API 访问

### 风险 4：LLM 调用延迟影响用户体验

| 场景 | 预估延迟 | 影响 |
|------|----------|------|
| 练习计划生成 (Plan-then-Execute) | 3-8s（API）/ 1-3s（本地 Ollama）| 可接受，用户发起后等待 |
| 双模型反思 (Generate → Critique → Revise) | 6-20s（API）/ 2-6s（本地）| 需显示进度提示，不阻塞 UI |
| 练习中实时反馈 | 不适合 LLM | 用本地规则引擎 + 客观指标，不走 Agent |

**应对**：
- LLM 调用全部异步，UI 显示骨架屏/进度动画
- 练习中反馈用纯本地逻辑（音准偏差 > 阈值 → 提示），不经过 LLM
- 双模型反思仅在生成练习计划时触发，不是每次交互都走

