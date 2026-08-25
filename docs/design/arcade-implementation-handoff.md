# Bulwark 街机化实现交接提示词（审计通过 · v1.1）

> 用途：将下方“交接提示词”整段复制到 **新对话** 中开始实现。
> 已保存位置：本文件本身；权威设计文档：`docs/design/arcade-improvement-plan.md`（v1.1）。

---

## 交接提示词（复制以下整段）

```
你是一名资深 Godot 4.7 开发者，继续实现《Bulwark 前线壁垒》的“街机化”改造。请先完整阅读当前仓库的 AGENTS.md，然后按本提示执行；全程使用中文交流。

【项目上下文】
- 项目目录：E:\godot_learning\projects\godot_dsh_test（Godot 4.7 mono；GDScript 为主，禁止新增/修改 C#——DSH 会话无法编译 C#）
- 引擎：E:\godot_learning\Godot_v4.6.2-stable_mono_win64\godot.exe（实际为 4.7.2 stable mono）
- 权威方案（人工审计已通过）：docs/design/arcade-improvement-plan.md —— 必须逐节执行，任务编号 1–20，顺序 P0(1–7) → P1(8–16) → P2(17–20)
- 上一轮评审基线：docs/review/game-review.md（内容/时长、性能、美术一致性、游戏感四大问题的证据与结论）
- 现测试基线：GUT 285/285 通过（42 个测试脚本）；i18n zh/en 各 264 键；headless 冒烟 exit 0

【工作流程】
1. 先加载路由技能 using-godot-skill-duo（或 using-godot-prompter），确认本项目技能路由；按任务表里的技能列加载对应技能（assets-pipeline / particles-vfx / hud-system / event-bus / resource-pattern / godot-testing / tween-animation / audio-system / ability-system / game-architect / godot-brainstorming / godot-code-review 等）。
2. 每开始一个任务：先重读方案对应小节（§2 粒子、§3 章节、§4 街机玩法、§5 美术、§6 任务表、§7 审计清单、§8 决策点），再动手。
3. 实现顺序：先完成 P0 全部任务并全员回归；P0 完成后再继续 P1；P2 可选，做完 P0+P1 后如时间允许再做 P2。
4. 每个任务完成即跑一次局部回归（对应 GUT 用例 + 无报错冒烟）；P0/P1 每阶段结束跑全量回归与审计清单。
5. 记录执行状态：在 docs/design/arcade-improvement-plan.md 末尾追加“执行状态表”（任务号 | 状态 done/pending | 改动文件 | 验证结果），不要删除原方案内容。

【硬约束（违反即返工）】
A. 资产
- 旧粒子 assets/particles/*.png（20 个）全部删除；其中 15 个未引用直接删，5 个按 §2.2 替换为 Kenney 坦克素材/运行时像素几何，替换后 grep 必须 0 命中。
- 新素材只从 temp_assets/kenney_top-down-tanks-remastered/PNG/Default size/ 复制需要的约 25–35 个文件到 assets/（推荐 assets/sprites/turret/、assets/vfx/kenney/、assets/sprites/props/）；禁止使用 Retina、禁止运行时引用 temp_assets/。
- 导入设置：TextureFilter=Nearest、无 mipmap、lossless；与现有 Kenney 角色同分辨率体系。
- 炮塔按 §2.2A 拼接：底座 tankBody_dark.png（或沙/绿/红/蓝变体）+ 炮管 tankDark_barrel1/2/3.png 或 specialBarrel*.png；删除 temp_assets/turret/*.svg 引用。
- 死亡/自爆/AoE 用 explosion1..5.png 5 帧动画（SpriteFrames + AnimatedSprite2D，0.35s，ObjectPool 或 FxBurst 池化）；玩家/敌方弹体用 bulletGreen/Red/Blue/Dark*.png；枪口焰用 shotLarge/shotOrange/shotRed.png；路障碎片用 sandbagBrown/barricadeWood/crateWood.png；章节装饰可用 crateMetal/sandbagBeige/oilSpill_*.png。
- 新建 VfxBank（scripts/systems/vfx_bank.gd 或 Resource）作为纹理/动画唯一入口；任何场景不得散落 preload("res://temp_assets/...") 或重复 load 爆炸帧。
- 在 assets/CREDITS.md 记录 Kenney Top-down Tanks Remastered（CC0，来源 kenney.nl）。
B. 代码与架构
- 不修改 addons/ 内第三方插件源码（kenney_interface_sounds 仅资源）。
- 多人：所有新规则（章节/分数/连击/道具/Boss）保持 host 权威（host/OFFLINE 裁决），client 只镜像；新事件必须进 NetCodec 中继清单，事件携带 player_id。
- 波次：RunDefinition/ChapterDefinition 为数据驱动；WaveDirector 增加章间状态机与 BossWave；必须保留“单章 6 波”回退路径，确保 test_full_run_six_waves_to_victory、test_m1_full_run.gd 等既有测试不破坏。
- 难度：把未使用的 DifficultyCurve 接入（chapter_scale × wave_scale）；单波同屏上限（建议 ≤40）由 WaveDirector 控制。
- 性能：普通命中走 FxBurst 8px 几何（Tier1），只有炮塔/弹体/爆炸/枪口焰走 Kenney 素材（Tier2）；client 镜像爆炸/粒子降量；禁止每帧 load/preload 新资源。
C. 文案与 i18n
- 禁止硬编码用户可见文本；UI 一律 tr()/UiText.text()/UiText.content_name()；新增键同进 locales/zh.json 与 en.json（同键同参），跑 tools/update_locales.py 后执行 tests/unit/test_i18n.gd。
- 资源内的 display_name/description 中文属回退源，允许；UI 不得直接显示资源字段。
D. 交付与 Git
- 不要 push；git commit 每完成一个阶段做一次（如 feat(arcade): P0 asset pipeline），提交前 git status 自查。
- 不要删除 docs/ 任何文件；新文件按项目目录约定放置。

【完成标准（每任务验收）】
- P0（1–7）：15 个粒子删除；5 个被引用粒子替换；Kenney 素材复制入库 + CREDITS；VfxBank 建成；AudioDirector 武器音效分支修复（type_id 实际是 weapon/type/hg、sg、lmg、er，勿再用 ends_with("pistol"/"shotgun")）；本局随机种子接入（波次种子 + 商店刷新种子）；HUD 方向罗盘最短版。
- P1（8–16）：RunDefinition/ChapterDefinition + 4 章模板 + WaveDirector 章间状态机；ArcadeScore 分数/连击 + 结算 Top10（user://highscore.json 带版本号）；伤害数字池化；PowerUpSystem 道具掉落 + buff 计时；Boss 大血条 + 章节横幅；敌人轮廓差异 5 种；VfxBank 接入炮塔/弹体/爆炸动画；temp_assets 依赖清零。
- P2（17–20）：无尽模式 / meta / 章间三选一 / 叙事（可选）。
- 全量回归命令（PowerShell）：
  & "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless -s addons/gut/gut_cmdln.gd --path .
  & "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless --path . --quit-after 60
- 引用清零检查：
  grep -rn "temp_assets" scenes scripts resources assets
  grep -rn "assets/particles" scenes scripts resources assets
- 视觉检查：若环境支持运行窗口/截图，至少在 1280×720 与 1920×1080 截取炮塔、枪口焰、爆炸、HUD（分数/连击/罗盘/BossBar）并人工/read_image 复核；确认与 Kenney 像素角色风格一致、无缺纹理/黑块。
- 结尾交付：报告阶段完成情况、改动文件清单、GUT/i18n/冒烟结果、截图路径、未完成项与风险。
```

---

## 使用说明（给“人”看，不是给新对话的提示词）

1. 新对话开始时把上面“复制以下整段”内的内容原样粘贴即可。
2. 若新对话只允许一轮执行，请明确要求它“先做 P0（任务 1–7），完成后报告并等待指示”；强烈建议不要一次要求整个 P0+P1+P2 全做完。
3. 若执行环境没有窗口/截图能力，允许 2D 视觉项降级为“headless + 代码级断言 + 人工后续截图”，但需在报告中明确标注。
4. 重要：方案 v1.1 中“人工审计已通过”指设计/方案层；**实现阶段每一任务仍应跑测试与自查**。
