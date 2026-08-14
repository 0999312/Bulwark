# 示例需求单：平台跳跃小样（Platformer Sample）

> 这是演示"策划 → 开发 → 评审"流程的**示例需求**，可直接执行，也可替换为你的真实需求。
> 目标：跑通全流程并产出一个可在 Godot 中运行的平台跳跃小样。

## 背景

godot_dsh_test 是一个刚初始化的 Godot 4.7 (mono) 项目（含 mc_game_framework、guide、dialogue_manager、sound_manager、gut 插件）。需要一个最小可玩示例，验证项目基建（输入、场景、测试）并演示 DSH 工作流。

## 需求

1. **玩家角色**（`scenes/player/player.tscn` + `scripts/player/player.gd`）
   - CharacterBody2D，支持左右移动、跳跃（含跳跃缓冲与土狼时间）
   - 状态机驱动（Idle / Run / Jump / Fall），信号对外通信
   - 简单动画表现（可用 ColorRect/Sprite2D 占位）

2. **输入**（使用 guide 插件）
   - 创建 GUIDE Action：`move_left` / `move_right` / `jump`（GUIDEAction 资源放 `input/actions/`）
   - 键盘映射：A/D 或 ←/→ 移动，空格/↑ 跳跃

3. **场景**（`scenes/main.tscn`，设为项目主场景）
   - 地面 + 若干静态平台 + 一个移动平台
   - 背景与简单的 UI 显示（移动/跳跃提示文字）

4. **音频**（sound_manager 或 kenney_interface_sounds 素材）
   - 跳跃音效（简单起见可用 UI 音效素材包中的 click）

5. **测试**（GUT）
   - 为玩家状态机核心逻辑（状态切换、跳跃缓冲、土狼时间判定）编写 `test/unit/player_test.gd`
   - 测试可 headless 运行通过

## 验收标准

- [ ] `godot --path .` 可运行，玩家可移动、跳跃，移动平台正常
- [ ] GUT 测试全部通过（`godot --headless -s addons/gut/gut_cmdln.gd --path .`）
- [ ] 代码遵循 `godot-code-review` 清单（信号优先、类型标注、无废弃 API）
- [ ] 场景树与脚本组织符合 `scene-organization` 技能模式

## 约束

- GDScript 实现（不引入 C#）
- 不修改 addons/ 内第三方插件源码
- 资源尽量使用项目现有 assets/（占位图形可用 ColorRect）
