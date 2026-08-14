# 即插即用示例：策划 → 开发 → 评审 全流程

本目录提供一套**开箱即用**的示例流程，演示如何用 DSH 完成一个 Godot 功能的完整生命周期。实际开发时，把示例需求单换成你的真实需求即可。

## 流程总览

```
① 策划 (godot-game-architect)  →  ② 实现 (godot-game-dev)  →  ③ 评审 (godot-code-reviewer)
       产出：设计文档/实现计划            产出：场景+脚本+测试              产出：评审报告
```

## 快速开始（3 步）

> 前置：项目技能已安装（`using-godot-prompter` 等 56 个技能在 `.dsh/skills/`，DSH 自动发现）。

### 第 1 步：策划

在 DSH 会话中启动一个子代理（或让当前代理直接执行）：

```
请以 docs/agent-prompts/godot-game-architect.md 为提示词，加载对应技能，
对 docs/dev-example/feature-brief-example.md 的需求单进行策划：
- 先加载 using-godot-prompter、godot-brainstorming、game-architect 等技能
- 产出：场景树设计、节点职责、信号图、数据流、实现计划（含任务顺序）
- 计划写入 docs/dev-example/design.md
```

**预期产出**：`docs/dev-example/design.md`（完整实现计划）。

### 第 2 步：实现

```
请以 docs/agent-prompts/godot-game-dev.md 为提示词，按 docs/dev-example/design.md 实现：
- 写代码前先加载对应技能（player-controller、state-machine、input-handling、godot-testing 等）
- 按计划创建 scenes/ scripts/ 下的文件
- 为关键逻辑编写 GUT 测试（test/ 目录），并运行验证
- 实现清单逐项勾选
```

**预期产出**：可运行的功能场景 + 通过的单元测试。

### 第 3 步：评审

```
请以 docs/agent-prompts/godot-code-reviewer.md 为提示词，
评审本次实现的全部变更文件（git diff / git status 查看），
按 godot-code-review 清单输出 Critical / Important / Minor 三级报告，
写入 docs/dev-example/review.md
```

**预期产出**：`docs/dev-example/review.md`，按报告修复 Critical/Important 项后完成闭环。

## 如何替换为真实需求

1. 复制 `feature-brief-example.md` 为 `feature-brief-<名称>.md`，改写需求内容（背景、目标、验收标准）
2. 按上述三步执行，把文档中的示例文件名替换为你的文件名
3. 产出文档建议命名：`design.md` / `review.md` 或按功能名区分

## 注意事项

- 每个子代理提示词里已含 DSH 工具映射说明（skill 工具加载技能、pwsh 等）
- 本项目输入系统使用 guide 插件（GUIDEAction），实现时注意与 `input-handling` 技能的结合
- 技能随仓库走：`.dsh/skills/` 如需裁剪直接删条目并提交
