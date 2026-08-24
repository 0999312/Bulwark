# Bulwark 前线壁垒

> Godot 4.7 多人合作塔防射击原型 —— 顶视角守住基地，抵御一波又一波敌军。

## 简介

《Bulwark 前线壁垒》是一个使用 **Godot 4.7 (Forward Plus)** 开发的合作塔防射击游戏原型：玩家防守基地，抵御多波敌人；支持单机（OFFLINE）与局域网 / 互联网（NodeTunnel）联机，采用 host 权威架构。

## 技术栈

- 引擎：Godot 4.7 stable（mono），GDScript 为主
- 渲染：Forward Plus + 像素风（Nearest 过滤）
- 测试：GUT v9.6.0（单元 + 集成测试）
- 插件：`mc_game_framework` / `guide` / `sound_manager` / `nodetunnel` / `gut`（详见 [AGENTS.md](AGENTS.md)）
- i18n：zh / en 双语（`locales/zh.json`、`locales/en.json`）

## 当前进度

- **M0** 垂直切片：移动 / 射击 / 换弹 / 切枪 / 暂停 / 结算 / 刷怪
- **M1** 可玩闭环 + 103 项 GUT 测试
- **M2** 多人架构：host 权威 + 意图 RPC + 快照同步 + 双进程验收
- **M3** 多人问题修复：摄像机归属、全队同意暂停、快照插值、per-player 资源、NodeTunnel 联机
- **M4** 素材 / 音频 / UI / 路障 + 像素游戏感改造
- **M5** 内容包扩展（敌人 / 武器 / 设施 / 商店）与 UI 专修进行中

## 运行与测试

开发环境与完整说明见 [AGENTS.md](AGENTS.md)，常用命令：

```powershell
# 运行游戏
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --path .

# GUT 单元测试
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless -s addons/gut/gut_cmdln.gd --path .

# 首次导入 / 重新导入资源
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless --import --path .
```

## 目录结构

| 目录 | 说明 |
|---|---|
| `scenes/` | 场景与表现层（UI / 玩家 / 敌人 / 基地 / VFX） |
| `scripts/` | 游戏逻辑（core / systems / data / net） |
| `resources/` | 内容数据（敌人 / 武器 / 商店 / 波次 / 设施） |
| `assets/` | 美术 / 音频 / 主题 / 字体 |
| `locales/` | 中英文翻译 |
| `input/` | GUIDE 输入映射与上下文 |
| `tests/` | GUT 单元 / 集成测试 |
| `docs/design/` | 各里程碑设计与交接文档 |
| `tools/` | 工具脚本（上下文生成 / 本地化 / 检查） |
| `addons/` | 第三方插件 |

## 多人联机

- host 权威 + 意图 RPC + 快照 / 事件中继；client 为只读镜像
- 局域网默认 `127.0.0.1:31007`；互联网联机走 NodeTunnel（运行配置在本地 `config.cfg`，该文件含密钥、不入库）
- 暂停采用“全队同意”机制

## i18n 约束

所有用户可见文案必须经 `tr()` / `I18NManager` / `UiText` 获取；新增翻译键需同步 `locales/zh.json` 与 `locales/en.json`。

## 许可

- 项目代码：MIT（见 [LICENSE](LICENSE)）
- 第三方素材：见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)；其中音乐**仅供本地测试**，发布前必须替换或取得授权
