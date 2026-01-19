这是一个非常有趣且具有挑战性的项目。这个项目的核心难点不在于 UI，而在于 **Token 上下文限制**。

通常一个磁盘包含数十万甚至数百万个文件，直接把完整的“目录树”扔给 AI（如 GPT-4 或 DeepSeek）会瞬间撑爆上下文窗口，或者导致 Token 费用极高。

因此，**技术架构必须包含一个“预处理/缩略”层**。

以下是为你定制的 **AI 智能磁盘清理工具 PRD**。

---

#  Project Name: AI Disk Sentinel (AI 磁盘哨兵)

## 1. 项目概述 (Overview)
一个运行在 Windows/macOS 上的桌面应用。它首先对指定磁盘路径进行快速扫描，生成结构化的元数据（而非原始全量树），根据预设的“清理原则”和“可用技能（Skills）”，请求 AI 进行分析，并由 AI 生成清理建议（如：删除缓存、归档旧文件）。
**核心原则：** AI 只提供建议（Proposal），人类拥有最终决定权（Execution）。

## 2. 技术选型 (Tech Stack)

考虑到你需要高性能的文件扫描和跨平台 UI：

*   **UI 框架:** **Flutter** (Windows/macOS)
    *   *理由:* 桌面端渲染性能极好，适合展示复杂的目录树（TreeView）和聊天界面。
*   **核心逻辑/扫描器:** **Dart** (原生) 或 **Rust** (通过 `flutter_rust_bridge` 集成)
    *   *MVP 建议:* 先用纯 Dart 写 `Directory.list`，性能对于个人工具足够。
    *   *进阶:* 如果文件超多，用 Rust 做后端扫描，速度是 Python 的 10-50 倍。
*   **AI 模型:** **DeepSeek V3 / GPT-4o** (通过 API)
    *   *理由:* 需要极强的逻辑推理能力来判断什么能删，什么不能删。
*   **本地数据库:** **SQLite** 或 **Isar**
    *   *理由:* 临时存储扫描出的百万级文件记录，方便进行 SQL 查询（例如：“找出所有大于 500MB 的 .log 文件”）。

---

## 3. 核心工作流 (Core Workflow)

1.  **Scanner (扫描):** 遍历磁盘，建立数据库，计算文件夹大小。
2.  **Summarizer (摘要):** **(关键步骤)** 将庞大的文件树转化为 AI 能理解的“统计摘要”。
    *   * 错误做法:* 发送 10 万个文件路径给 AI。
    *   * 正确做法:* 发送“前 50 个大文件夹”、“占用最大的 5 种文件类型”、“超过 1 年未访问的目录列表”。
3.  **Analyzer (AI 分析):** AI 接收摘要 + 清理原则 + Skills 定义。
4.  **Proposal (提案):** AI 返回一个操作列表（JSON 格式）。
5.  **Review (审核):** 用户在 UI 上看到 AI 的建议，勾选/取消勾选。
6.  **Action (执行):** 调用本地 Skill 执行删除或移动。

---

## 4. 功能需求 (Functional Requirements)

### 4.1  扫描与可视化 (Scan & Visualize)
*   **目录选择:** 用户选择扫描 `C:\Users\Name` 或 `D:\Work`。
*   **Sunburst Chart (旭日图):** 类似 SpaceSniffer，直观显示哪个文件夹占地盘最大。
*   **Tree View:** 传统的树状文件列表，按大小排序。

### 4.2  AI 归纳与分析 (The Brain)
这是最核心的部分。我们需要设计一套 Prompt 结构。

**输入给 AI 的内容 (Context):**
1.  **用户原则 (Principles):**
    *   "如果是 `node_modules`，且超过 3 个月未修改，建议删除。"
    *   "如果是 `.tmp` 或 `.log` 文件，直接建议删除。"
    *   "如果是图片或文档，**绝对不要**建议删除，除非是重复文件。"
2.  **环境快照 (Snapshot):**
    *   Top 20 占用空间的文件夹路径。
    *   Top 20 占用空间的文件扩展名统计。
    *   根目录下的文件夹结构摘要。
3.  **可用技能 (Skills/Tools):**
    *   `delete_path(path)`: 删除文件或文件夹。
    *   `compress_folder(path)`: 将文件夹打包为 zip。
    *   `move_to_archive(path)`: 移动到特定的“冷数据”盘。

**AI 的输出 (Response):**
AI 必须返回 **JSON 格式** 的操作建议列表，包含 `reason` (理由) 和 `risk_level` (风险等级)。

### 4.3 🛡️ 安全执行 (Safety Execution)
*   **回收站机制:** 默认删除操作是“移入回收站”而非彻底粉碎。
*   **风险高亮:** AI 标记为 High Risk 的操作（如删除 Program Files 下的内容）需红色警告。
*   **一键回滚:** 记录操作日志，提供简单的 Undo 功能（如果仅仅是移动了文件）。

---

## 5. 提示词工程设计 (Prompt Engineering for App)

你在代码中构造的 System Prompt 应该长这样：

```markdown
Role: 你是一个专业的磁盘清理专家。你拥有对文件系统的分析能力，并且可以使用特定的工具(Tools)来处理文件。

Objective: 分析用户提供的磁盘摘要信息，根据用户的清理原则，生成一份清理建议列表。

Constraints:
1. 你的回答必须是严格的 JSON 格式。
2. 对于系统文件、应用核心文件，必须保持极其保守的态度。
3. 即使符合原则，如果是用户生成的文档/图片，优先建议“归档”而非“删除”。

Available Tools (Do not execute, just propose):
- delete(path): 移入回收站
- archive(path): 移动到备份目录

User Principles:
- 清理所有超过 1GB 的缓存文件夹。
- 清理所有 Python 的 `__pycache__`。
- 只有当确认是临时文件时才删除。

Current Disk State (Summary):
[...这里由程序动态插入 JSON 数据，例如大文件列表...]
```

### 5.1 多轮对话支持

支持用户与 AI 进行追问：
- "为什么建议删除这个文件夹？"
- "这个文件夹里有什么重要文件吗？"
- "帮我分析一下 D:/Projects 目录"

### 5.2 上下文窗口管理策略

| 优先级 | 内容 | Token 预算 |
|--------|------|-----------|
| P0 | System Prompt + 用户原则 | ~500 |
| P1 | 当前焦点路径的详细信息 | ~1000 |
| P2 | Top 50 大文件夹摘要 | ~2000 |
| P3 | 文件类型统计 | ~500 |
| 保留 | AI 回复空间 | ~2000 |

### 5.3 渐进式细节加载 (Drill-Down)

当 AI 需要某个文件夹的详细信息时：
1. 首次只发送 L1 摘要（子文件夹名+大小）
2. AI 可请求 `get_folder_details(path)` 获取 L2 详情
3. 避免一次性发送全量数据

---

## 6. 开发路线 (Development Roadmap)

### Phase 1: 基础扫描器 (The Scanner)
*   使用 Flutter 创建桌面应用。
*   实现递归扫描文件逻辑，计算文件夹大小。
*   使用 `fl_chart` 或简单的 `ListView` 展示占用最大的前 10 个文件夹。
*   **不接 AI**，先确保能准确列出大文件。

### Phase 2: AI 接口对接 (The Connector)
*   定义 `DiskAnalysisService`。
*   编写逻辑，将 Phase 1 扫描出的“Top 50 大文件夹”转换为文本描述。
*   调用 DeepSeek/OpenAI API，获取 JSON 建议。
*   解析 JSON，在界面上打印出 AI 的建议（如：“建议删除 C:/Temp，因为它占用了 5GB 且全是临时文件”）。

### Phase 3: 技能实现与交互 (The Actor)
*   实现 `FileOperator` 类（真实的删除/移动代码）。
*   制作“建议卡片”UI：左边是 AI 的建议理由，右边是“执行”和“忽略”按钮。
*   添加“一键执行”功能，并带有进度条。

---

## 7. 关键代码片段预演 (Dart)

**如何定义 AI 的工具 (Skills) 结构:**

```dart
// 定义一个清理建议类
class CleaningSuggestion {
  final String targetPath;
  final String operation; // 'delete', 'compress'
  final String reason;
  final String riskLevel; // 'low', 'medium', 'high'

  CleaningSuggestion({
    required this.targetPath, 
    required this.operation, 
    required this.reason,
    required this.riskLevel
  });
  
  // 工厂方法：从 AI 返回的 JSON 解析
  factory CleaningSuggestion.fromJson(Map<String, dynamic> json) {
    return CleaningSuggestion(
      targetPath: json['path'],
      operation: json['action'],
      reason: json['reason'],
      riskLevel: json['risk'] ?? 'medium',
    );
  }
}
```

**如何生成传给 AI 的摘要 (Summary Strategy):**

不要遍历每一个文件，而是统计：

```dart
String generateDiskSummary(List<FileItem> allFiles) {
  // 1. 找出最大的 20 个文件
  // 2. 找出占用空间最大的 10 个文件类型 (扩展名)
  // 3. 找出名字包含 'cache', 'temp', 'log' 的大文件夹
  
  // 拼接成 Prompt
  return """
  Analysis Context:
  - Top 10 Largest Files: ${topFiles.toString()}
  - Storage by Type: ${fileTypeStats.toString()}
  - Suspicious Cache Folders: ${cacheFolders.toString()}
  """;
}
```

这个项目非常实用，也是很好的 AI Agent 入门实践（即：AI 决策 -> 传统代码执行）。如果你需要 Phase 1 的具体代码，请告诉我！

---

## 8. 非功能性需求 (Non-Functional Requirements)

### 8.1 性能要求
- 扫描速度：100万文件 < 60秒（SSD）
- 内存占用：扫描时 < 500MB
- UI 响应：操作延迟 < 100ms

### 8.2 安全要求
- API Key 加密存储（使用系统 Keychain）
- 敏感路径保护名单（Windows/System32, Program Files 等）
- 操作日志审计

### 8.3 可用性
- 支持扫描中断/恢复
- 离线模式（使用本地缓存的历史分析）

## 9. 用户场景 (User Stories)

| 场景 | 描述 | 验收标准 |
|------|------|----------|
| 快速清理 | 作为用户，我想一键清理所有临时文件 | 自动识别 temp/cache/log，10秒内给出建议 |
| 大文件猎人 | 作为用户，我想找出占空间最大的文件 | 可按大小排序，支持筛选阈值 |
| 项目清理 | 作为开发者，我想清理 node_modules | 识别项目依赖，显示最后修改时间 |
| 重复文件 | 作为用户，我想找出重复的文件 | 基于 hash 去重，分组展示 |

## 10. 异常处理 (Error Handling)

| 场景 | 处理方式 |
|------|----------|
| 文件被占用无法删除 | 跳过并记录，建议重启后重试 |
| 权限不足 | 提示申请管理员权限 |
| API 调用失败 | 本地缓存 fallback + 重试机制 |
| 扫描路径不存在 | 友好提示 + 重新选择 |
| 磁盘空间不足（打包时） | 预检查 + 中止操作 |

## 11. 数据模型 (Data Model)

### FileItem 表
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键 |
| path | TEXT | 完整路径 |
| size | INTEGER | 文件大小 (bytes) |
| modified_at | DATETIME | 最后修改时间 |
| accessed_at | DATETIME | 最后访问时间 |
| extension | TEXT | 扩展名 |
| is_directory | BOOLEAN | 是否为目录 |
| parent_id | INTEGER | 父目录 ID |

### OperationLog 表（用于回滚）
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键 |
| operation | TEXT | delete/move/compress |
| original_path | TEXT | 原始路径 |
| target_path | TEXT | 目标路径（如回收站） |
| executed_at | DATETIME | 执行时间 |
| reversible | BOOLEAN | 是否可回滚 |

## 12. UI 设计要点

### 12.1 主界面布局
┌─────────────────────────────────────────┐
│  [选择目录]  [扫描]  [设置]             │
├──────────────────┬──────────────────────┤
│                  │                      │
│   旭日图/TreeView │   AI 建议面板        │
│   (可切换)        │   - 建议卡片列表     │
│                  │   - 一键执行          │
│                  │                      │
├──────────────────┴──────────────────────┤
│  状态栏: 已扫描 xxx 文件 | 可释放 xx GB  │
└─────────────────────────────────────────┘

### 12.2 建议卡片设计
- 🟢 低风险：绿色边框
- 🟡 中风险：黄色边框 + 警告图标
- 🔴 高风险：红色边框 + 二次确认弹窗

---

## 13. 增量扫描 (Incremental Scan)

首次扫描后，后续只扫描变化，提升效率：

### 13.1 实现策略

1. **文件系统监听**：使用 `FileSystemWatcher` 监听实时变更
2. **时间戳比对**：记录上次扫描时间，只查询 `modified_at > last_scan`
3. **目录级 Hash**：对于大目录，使用目录级别的 hash 快速判断变化

### 13.2 增量更新流程

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  首次全量   │ ──▶ │  监听变更   │ ──▶ │  增量更新   │
│   扫描      │     │  事件       │     │   数据库    │
└─────────────┘     └─────────────┘     └─────────────┘
                           │
                           ▼
                    ┌─────────────┐
                    │  定时全量   │
                    │  校验(可选) │
                    └─────────────┘
```

### 13.3 缓存策略

| 缓存类型 | 有效期 | 说明 |
|----------|--------|------|
| 文件大小统计 | 实时更新 | 监听变更即时刷新 |
| 文件夹大小 | 5分钟 | 避免频繁递归计算 |
| AI 分析结果 | 24小时 | 相同快照不重复请求 |

---

## 14. 测试计划 (Test Plan)

### 14.1 测试类型

| 测试类型 | 覆盖范围 | 工具 |
|----------|----------|------|
| 单元测试 | 文件大小计算、JSON 解析、摘要生成 | `flutter_test` |
| 集成测试 | AI API 调用、数据库 CRUD | `integration_test` |
| E2E 测试 | 扫描→分析→删除完整流程 | `patrol` |
| 性能测试 | 大量文件扫描、内存占用 | 自定义基准测试 |

### 14.2 边界测试用例

| 场景 | 预期行为 |
|------|----------|
| 空目录 | 正常显示，大小为 0 |
| 超长路径 (>260 字符) | Windows 使用 `\\?\` 前缀处理 |
| 特殊字符文件名 (中文、emoji) | 正确显示和处理 |
| 符号链接/快捷方式 | 标记类型，不递归跟随 |
| 无权限目录 | 跳过并记录警告 |
| 扫描中磁盘拔出 | 优雅中断，保存已扫描数据 |

### 14.3 Mock 策略

```dart
// AI API Mock
class MockAIService implements AIService {
  @override
  Future<List<CleaningSuggestion>> analyze(DiskSnapshot snapshot) async {
    return [
      CleaningSuggestion(
        targetPath: '/mock/cache',
        operation: 'delete',
        reason: 'Mock: 缓存文件夹',
        riskLevel: 'low',
      ),
    ];
  }
}
```

---

## 15. MVP 范围定义 (MVP Scope)

### 15.1 ✅ MVP 包含

| 功能 | 优先级 | 说明 |
|------|--------|------|
| 单目录扫描 | P0 | 选择一个目录进行扫描 |
| Top 50 大文件/文件夹展示 | P0 | 按大小排序的列表视图 |
| DeepSeek API 分析 | P0 | 基础 AI 清理建议 |
| 删除到回收站 | P0 | 安全删除操作 |
| 基础 TreeView | P0 | 文件树浏览 |
| 用户原则配置 | P1 | 简单的规则编辑器 |
| 操作日志 | P1 | 记录所有执行的操作 |

### 15.2 ❌ MVP 不包含（Phase 2+）

| 功能 | 计划阶段 | 说明 |
|------|----------|------|
| 重复文件检测 | Phase 2 | 基于 hash 的去重 |
| 压缩/归档功能 | Phase 2 | zip 打包能力 |
| 多目录同时扫描 | Phase 2 | 并行扫描多个路径 |
| 旭日图可视化 | Phase 2 | 高级可视化组件 |
| 定时自动清理 | Phase 3 | 后台定时任务 |
| 云同步配置 | Phase 3 | 多设备配置同步 |
| 本地 AI 模型 | Phase 3 | 离线分析能力 |

### 15.3 MVP 验收标准

- [ ] 能成功扫描 10 万+ 文件的目录（< 60秒）
- [ ] AI 能返回有效的清理建议（至少 5 条）
- [ ] 删除操作能正确移入回收站
- [ ] 无崩溃运行 1 小时以上
- [ ] 内存占用 < 500MB

---

## 16. 风险评估与缓解 (Risk Assessment)

| 风险 | 可能性 | 影响 | 缓解措施 |
|------|--------|------|----------|
| AI 误判重要文件 | 中 | 高 | 保守策略 + 二次确认 + 回收站机制 |
| API 费用超预期 | 中 | 中 | Token 预算控制 + 摘要压缩 |
| 扫描性能瓶颈 | 低 | 中 | Rust 后端扫描（可选） |
| 跨平台兼容问题 | 中 | 中 | 充分测试 Win/Mac |
| 用户隐私顾虑 | 低 | 高 | 本地处理优先 + 隐私声明 |

---

## 17. 术语表 (Glossary)

| 术语 | 定义 |
|------|------|
| Skill | AI 可调用的操作能力（如 delete、archive） |
| Proposal | AI 生成的建议，需用户确认后才执行 |
| Snapshot | 某一时刻的磁盘状态摘要 |
| Drill-Down | 渐进式加载详细信息的策略 |
| Cold Data | 长期未访问的归档数据 |

---

## 18. 参考资料 (References)

- [Flutter Desktop 官方文档](https://docs.flutter.dev/desktop)
- [DeepSeek API 文档](https://platform.deepseek.com/docs)
- [SpaceSniffer](http://www.intevation.de/~wilde/spacesniffer/) - UI 灵感参考
- [WizTree](https://diskanalyzer.com/) - 性能参考基准