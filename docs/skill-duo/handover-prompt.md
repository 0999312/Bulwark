# 交接一句话提示词

> 复制下面一句话（含占位符）到交接消息，把 `<一句话灵感>` 替换为人工编写的一句话灵感，再发给承接方 / 主代理。

```text
请按 Godot Skill Duo 路由先加载 `using-godot-skill-duo`，随后按「策划 → 实现 → 评审」标准流程推进，凡需要原型素材时调用 GrsAI 生图（默认链 nano-banana-pro → nano-banana-2 → gpt-image-2，Key 从 config/grsai.env 读取），本次唯一输入为：<一句话灵感>
```

## 使用说明

- 占位符：`<一句话灵感>`（人工在交接时填写）。
- 该提示词已绑定本项目两条工作流：
  1. 技能路由：`using-godot-skill-duo`（GodotPrompter 主 + GD-Agentic-Skills 辅）；
  2. 生图通道：`tools/grsai_image.py` / `tools/grsai_image.ps1`。
- 交接前请确认 `config/grsai.env` 已填入真实 API Key。

