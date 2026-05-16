# 吴恩达 Agentic AI 课程 — 技术分析选型参考手册

> **用途**：本文档为 Claude Code 离线参考资料，整理自 Andrew Ng 在 DeepLearning.AI 发布的《Agentic AI》课程（2025年10月上线）及相关资料，涵盖核心概念、四大设计模式、工程实践与主流框架横向对比。
>
> **原始课程**：https://learn.deeplearning.ai/courses/agentic-ai  
> **GitHub 中文整理**：https://github.com/datawhalechina/agentic-ai  
> **前提要求**：Python 基础 + LLM API 基本认知

---

## 一、核心理念：什么是 Agentic AI

### 1.1 定义

Agentic AI（智能体工作流）是指**基于 LLM 的应用程序执行多个步骤来完成一项任务**，而非一次性生成答案。

| 对比维度 | 传统 One-shot LLM | Agentic 工作流 |
|---|---|---|
| 执行方式 | prompt → 单次输出 | 多步骤迭代执行 |
| 质量优化 | 靠 prompt 工程 | 每步可独立评估、迭代 |
| 工具调用 | 手动触发 | LLM 自主决策调用 |
| 错误修复 | 人工干预 | 自我反思或外部检验循环 |
| 适用场景 | 简单问答、摘要 | 复杂研究、代码生成、多步业务流程 |

### 1.2 自主性层级（Autonomy Spectrum）

吴恩达强调"Agentic"是连续程度，而非二元分类：

```
低自主性 ──────────────────────────────→ 高自主性
  │                    │                    │
固定步骤流程        LLM 决定调用哪些工具    LLM 自主设计工作流
(开发者预定义)      (Semi-autonomous)       (甚至自写新工具/函数)
```

### 1.3 核心价值（量化案例）

- **GPT-3.5 + Agentic 工作流 vs GPT-4 直接输出**：在编程基准测试中，GPT-3.5 通过反思循环达到 74% 正确率，超过 GPT-4 直接输出的 67%。
- **并行处理**：多个 Agent 可同时抓取、分析多源信息。
- **模块化**：各步骤独立可替换、可优化。

---

## 二、构建 Agentic 系统的三大核心技能

### 技能 1：任务分解（Task Decomposition）

**核心方法**：
1. 分析现有业务流程，拆解为离散步骤
2. 判断每步是否可由 LLM/工具实现
3. 若模型无法完成某步，继续细化
4. 通过 JSON 或代码形式将步骤结构化，确保模型严格执行

**示例——论文写作分解**：
```
prompt（写一篇论文）
  → 设计提纲
  → 关键词搜索（调用搜索工具）
  → 撰写各章节草稿
  → 反思/修订（调用反思模块）
  → 输出最终版本
```

### 技能 2：评测（Evals）与错误分析

> 吴恩达：**"决定团队能否高效构建 Agent 的最大因素，是能否执行严格的 Evals 和错误分析流程。"**

**评测体系**：

| 类型 | 做法 | 示例 |
|---|---|---|
| 客观评测 | 统计可量化的质量问题 | Agent 是否提及了竞争对手？计次数 |
| 主观评测 | 用另一 LLM 作"裁判"评分 | 用 GPT-4 对输出打 1-5 分 |
| 二元打分 | 简化评估，让模型计算平均分 | "此输出是否满足需求？yes/no" |
| Trace 追踪 | 记录每步执行日志，定位断点 | 找到哪个节点导致了最终失败 |

**错误分析循环**：
```
运行 Agent → 查看 Traces → 找出失败步骤 → 针对性优化该组件 → 再评测
```

### 技能 3：四大设计模式（下节详述）

---

## 三、四大 Agentic 设计模式

### 模式 1：反思（Reflection）

**核心思想**：让 LLM 审视自己的输出，找出问题并改进，形成 Generate → Critique → Improve 循环。

**实现方式**：

```python
# 单模型反思
def reflection_loop(task, max_iter=3):
    output = llm.generate(task)
    for _ in range(max_iter):
        critique = llm.critique(output)  # 让同一模型审查
        if critique.is_satisfactory:
            break
        output = llm.improve(output, critique)
    return output

# 双模型对抗（更强效果）
def dual_model_reflection(task):
    draft = generator_llm.generate(task)
    feedback = critic_llm.critique(draft)  # 独立模型审查
    return generator_llm.improve(draft, feedback)
```

**实用 Prompt 技巧**：
- 明确告知模型要"反思"，不要只是"回答"（如："请先仔细审查以下草稿，找出需要改进的地方，再重写它"）
- 给出具体反思标准（准确性、格式、完整性等）
- 推理型模型（如 o1/o3）做反思效果优于普通模型

**适用场景**：代码生成 & 修复、报告写作、数据分析图表生成

---

### 模式 2：工具调用（Tool Use）

**核心思想**：LLM 决定调用哪些外部函数/API，获取结果后继续推理。

**传统方式 vs MCP**：

| | 传统工具调用 | MCP（Model Context Protocol）|
|---|---|---|
| 实现方式 | 开发者手动实现每个工具接口 | 标准客户端-服务端协议 |
| 扩展性 | 每个工具独立实现，重复劳动 | 统一协议，AI 像调本地函数一样调服务端 |
| 维护成本 | 高（各种 API/认证/解析各不同）| 低（标准化） |
| 典型工具 | 网络搜索、日历、邮件、代码执行 | Slack、GitHub、数据库、云服务 |

**代码执行安全建议**：
- 必须在沙盒环境中运行（Docker、e2b 等）
- LLM 偶尔会误删代码，需做快照/版本保护
- 推荐使用 `AISuite` 库简化多 LLM 提供商集成

**工具调用示例**：
```python
tools = [
    {
        "name": "web_search",
        "description": "Search the web for current information",
        "parameters": {"query": {"type": "string"}}
    },
    {
        "name": "run_python",
        "description": "Execute Python code in a sandbox",
        "parameters": {"code": {"type": "string"}}
    }
]
```

---

### 模式 3：规划（Planning）

**核心思想**：LLM 将复杂任务分解为可执行子步骤，并在执行中动态调整。

**两种规划策略**：

```
A. 预先规划（Plan-then-Execute）
   LLM 先生成完整计划 → 逐步执行 → 适合任务边界清晰的场景

B. 动态规划（ReAct 模式：Reason-Act-Observe）
   每步：思考 → 行动 → 观察结果 → 再思考
   → 适合开放性、不确定任务
```

**JSON 结构化步骤（推荐做法）**：

```json
{
  "task": "调研新能源汽车市场并写报告",
  "steps": [
    {"id": 1, "action": "web_search", "input": "新能源汽车2025市场份额"},
    {"id": 2, "action": "web_search", "input": "比亚迪特斯拉销量对比2025"},
    {"id": 3, "action": "synthesize", "depends_on": [1, 2]},
    {"id": 4, "action": "write_report", "depends_on": [3]},
    {"id": 5, "action": "reflect_and_revise", "depends_on": [4]}
  ]
}
```

---

### 模式 4：多智能体协作（Multi-Agent Collaboration）

**核心思想**：构建多个专业化 Agent，分工协作，类似公司雇佣不同职能员工。

**协作拓扑结构**：

```
层级式（Hierarchical）         对等式（Peer-to-peer）
    Orchestrator                 Agent A ←→ Agent B
    /    |    \                      ↕
  AgentA AgentB AgentC           Agent C

适合：流水线任务              适合：需要协商的任务
```

**典型分工示例（深度研究 Agent）**：

| Agent 角色 | 职责 |
|---|---|
| Planner Agent | 制定研究计划，分配子任务 |
| Search Agent × N | 并行搜索多个关键词 |
| Synthesis Agent | 汇总、去重、整合信息 |
| Writer Agent | 撰写结构化报告 |
| Critic Agent | 反思报告质量，提出修改建议 |

**LLM 调用其他 Agent**（嵌套调用）：
```python
# Agent 可以将另一个 Agent 视为工具来调用
tools = [
    {"name": "research_agent", "description": "专门负责信息检索的子智能体"},
    {"name": "code_agent", "description": "专门负责代码生成和执行的子智能体"},
]
```

**优势**：
- 并行处理加速（多 Agent 同时工作）
- 上下文窗口隔离（各 Agent 独立上下文，避免超限）
- 专业化提升质量（专精 Agent > 通才 Agent）
- 模块化维护（可单独优化某个 Agent）

---

## 四、课程模块结构（5 个模块）

| 模块 | 主题 | 核心内容 |
|---|---|---|
| Module 1 | 智能体工作流简介 | Agentic 概念、自主性层级、任务分解、Evals 基础、四大模式概览 |
| Module 2 | 反思设计模式 | Reflection 实现、双模型对抗、反思 Prompt 设计技巧 |
| Module 3 | 工具调用 | Tool Use 实现、SQL Agent、可视化 Agent、MCP 协议介绍 |
| Module 4 | 规划与高级技巧 | Planning 策略、ReAct 模式、构建 Agentic AI 的实用 Tips |
| Module 5 | 高自主性 Agent + Capstone | 多 Agent 协作、高自主性场景、综合项目：深度研究 Agent |

**Capstone 项目**：深度研究 Agent（搜索 → 综合分析 → 生成报告），整合全部四大模式。

---

## 五、主流 Agent 框架横向对比

> 课程本身使用**纯 Python 实现**（框架无关），以下为选型参考。

### 5.1 框架对比总表

| 框架 | 定位 | 编程模型 | 多 Agent | 可控性 | 学习曲线 | 适用场景 |
|---|---|---|---|---|---|---|
| **LangChain** | 通用 LLM 应用框架 | 链式组合 | 有限（借助子链）| 中 | 低-中 | 快速原型、RAG、问答 |
| **LangGraph** | 有状态图式工作流 | 图节点+边 | 强（图式协作）| 高 | 中-高 | 复杂决策树、人机协同、生产级 |
| **AutoGen** | 对话式多 Agent | 角色对话 | 强 | 中 | 中 | 研究实验、代码生成、协商任务 |
| **CrewAI** | 角色驱动多 Agent | YAML/Python 声明式 | 强 | 中 | 低-中 | 内容生产、营销自动化、团队模拟 |
| **smolagents** | 轻量代码执行 Agent | 极简 API | 基础 | 低 | 极低 | 离线/隐私场景、轻量助手 |
| **OpenAI Swarm** | 实验性多 Agent | 轻量编排 | 有 | 低 | 低 | 学习/实验用途（非生产） |
| **原生 Python** | 完全自定义 | 无框架约束 | 完全可控 | 极高 | 高 | 深入理解原理、高度定制需求 |

### 5.2 选型决策树

```
需要快速验证想法？
  ├─ 是 → smolagents / CrewAI（1-2天上手）
  └─ 否 ↓

需要精细流程控制 & 人机协同？
  ├─ 是 → LangGraph（图式状态机，支持条件分支、人工审批）
  └─ 否 ↓

需要角色分工 & 内容生产自动化？
  ├─ 是 → CrewAI（YAML 声明，角色定义清晰）
  └─ 否 ↓

需要研究实验 & 对话式协作？
  ├─ 是 → AutoGen（灵活的多模型对话）
  └─ 否 ↓

需要完整 LLM 生态 & 丰富工具插件？
  └─ LangChain（工具生态最完整）
```

### 5.3 各框架代码风格示例

**LangGraph（图式状态机）**：
```python
from langgraph.graph import StateGraph

def research_node(state): return {"data": search(state["query"])}
def write_node(state): return {"report": write(state["data"])}

graph = StateGraph(...)
graph.add_node("research", research_node)
graph.add_node("write", write_node)
graph.add_edge("research", "write")
graph.set_entry_point("research")
app = graph.compile()
```

**CrewAI（声明式角色）**：
```python
from crewai import Agent, Task, Crew

researcher = Agent(role="研究员", goal="搜集信息", llm=llm)
writer = Agent(role="作家", goal="撰写报告", llm=llm)
task = Task(description="调研AI趋势", agent=researcher)
crew = Crew(agents=[researcher, writer], tasks=[task])
crew.kickoff()
```

**AutoGen（对话式）**：
```python
from autogen import AssistantAgent, UserProxyAgent

assistant = AssistantAgent(name="Assistant", llm_config={"model": "gpt-4"})
user = UserProxyAgent(name="User", human_input_mode="NEVER")
user.initiate_chat(assistant, message="帮我分析AI在医疗的应用")
```

---

## 六、工程化最佳实践

### 6.1 开发流程（吴恩达推荐）

```
1. 任务分解    → 把需求拆成离散步骤，确认每步可实现
2. 原型实现    → 用纯 Python 或轻量框架快速跑通流程
3. 建立 Evals  → 设计客观+主观评测，记录基线
4. Trace 分析  → 记录每步执行日志，找薄弱节点
5. 针对性优化  → 只优化 Evals 指向的具体组件
6. 迭代循环    → 重复 3-5，避免盲目调 prompt
```

### 6.2 安全与稳定性

- **代码执行沙盒**：必须用 Docker 或 e2b，防止 LLM 误删/破坏文件
- **上下文窗口管理**：长任务拆分子 Agent，各自维护独立上下文
- **人机协同节点**：在关键决策点加入 human-in-the-loop 确认
- **工具调用超时**：设置每个工具调用的最大等待时间
- **幂等设计**：工具操作尽量设计为可重试的幂等操作

### 6.3 模型选型建议

| 用途 | 推荐策略 |
|---|---|
| Reflection / Critique | 推理型模型（o1/o3/Claude 3.7）效果更好 |
| 简单工具调用 | 轻量模型（GPT-3.5/Claude Haiku）降低成本 |
| 复杂规划 | 强推理模型（GPT-4o/Claude Sonnet/Opus）|
| 生成+审查双模型 | 生成用轻量模型，审查用强模型，兼顾成本与质量 |

### 6.4 MCP（Model Context Protocol）关键概念

Anthropic 提出的 MCP 是当前工具调用标准化的主流方案：

```
传统方式：开发者 → 手动实现接口 → 调用工具 → 返回结果给 LLM
MCP 方式：LLM → MCP Client → MCP Server（标准协议）→ 工具/服务

优势：
- 标准化：Slack/GitHub/数据库等服务统一接入
- 可复用：一次实现，多个 Agent 共享
- 安全：服务端沙盒隔离
```

---

## 七、典型应用场景

| 场景 | 主要模式组合 | 关键工具 |
|---|---|---|
| 深度研究报告 | Planning + Tool Use + Reflection | 网络搜索、文档读取 |
| 自动化代码生成 | Reflection（测试驱动）+ Tool Use（代码执行）| 沙盒环境、测试框架 |
| 客服智能体 | Planning + Tool Use | CRM API、知识库检索 |
| 营销内容自动化 | Multi-Agent（研究员+写手+审核）| 搜索 + 写作工具 |
| 法律文档处理 | Tool Use + Reflection | PDF 解析、数据库查询 |
| 医疗诊断辅助 | Multi-Agent + Human-in-the-loop | 医学数据库、影像 API |
| 数据分析 + 可视化 | Tool Use（SQL + 图表）+ Reflection | 数据库、Python 执行 |

---

## 八、快速参考：关键术语表

| 术语 | 说明 |
|---|---|
| Agentic AI | LLM 通过多步骤迭代工作流完成复杂任务的范式 |
| Evals | 评测体系，是 Agent 工程化的核心 |
| Trace | 每步执行日志，用于定位问题 |
| Reflection | Agent 自我审查并改进输出的循环 |
| Tool Use | LLM 自主决定调用外部函数/API |
| Planning | LLM 将任务分解为子步骤并执行 |
| Multi-Agent | 多个专业化 Agent 协作完成复杂任务 |
| ReAct | Reason-Act-Observe 动态规划模式 |
| MCP | Model Context Protocol，Anthropic 提出的工具调用标准协议 |
| AISuite | 吴恩达团队开发的 Python 库，简化多 LLM 提供商集成 |
| Human-in-the-loop | 在关键节点引入人工确认/审批 |
| Orchestrator | 多 Agent 场景中负责协调的主控 Agent |

---

## 九、参考资源

| 资源 | 地址 |
|---|---|
| 课程官方页面 | https://learn.deeplearning.ai/courses/agentic-ai |
| 中文整理项目（DataWhale）| https://github.com/datawhalechina/agentic-ai |
| 吴恩达宣布课程（LinkedIn）| https://linkedin.com/posts/andrewyng_announcing-my-new-course-agentic-ai |
| LangGraph 文档 | https://langchain-ai.github.io/langgraph |
| CrewAI 文档 | https://docs.crewai.com |
| AutoGen 文档 | https://microsoft.github.io/autogen |
| MCP 规范（Anthropic）| https://modelcontextprotocol.io |
| AISuite（吴恩达团队）| https://github.com/andrewyng/aisuite |

---

*文档生成时间：2026年5月16日 | 基于吴恩达《Agentic AI》课程（DeepLearning.AI，2025年10月）*
