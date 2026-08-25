#!/usr/bin/env python3
"""Regenerate locales/{zh,en}.json with structural UI keys + content keys.

Content zh values are read from resources/*.tres (source of truth).
Content en values are maintained in CONTENT_EN below.
Run from project root: python tools/update_locales.py
"""
import json
import pathlib
import re


def clean(content_id: str) -> str:
    return content_id.replace(":", "_").replace("/", "_").replace("-", "_").replace(".", "_")


def ckey(content_id: str, field: str) -> str:
    return f"content.{clean(content_id)}.{field}"


def cc(content_id: str, name: str, desc: str = ""):
    out = {ckey(content_id, "name"): name}
    if desc:
        out[ckey(content_id, "desc")] = desc
    return out


def res_field(path: str, key: str) -> str:
    text = pathlib.Path(path).read_text(encoding="utf-8")
    match = re.search(r"^" + key + r' = "([^"]+)"', text, re.M)
    return match.group(1) if match else ""


def add_zh_resource(content_zh: dict, content_id: str, path: str) -> None:
    name = res_field(path, "display_name")
    if name:
        content_zh[ckey(content_id, "name")] = name
    desc = res_field(path, "description")
    if desc:
        content_zh[ckey(content_id, "desc")] = desc


def build_content_zh() -> dict:
    out = {}
    for p in pathlib.Path("resources/weapons/type").glob("type_*.tres"):
        add_zh_resource(out, "weapon/type/" + p.stem[5:], str(p))
    for p in pathlib.Path("resources/weapons/model").glob("model_*.tres"):
        add_zh_resource(out, "weapon/model/" + p.stem[6:], str(p))
    for p in pathlib.Path("resources/attachments").glob("attachment_*.tres"):
        add_zh_resource(out, "attachment/" + p.stem[11:], str(p))
    for p in pathlib.Path("resources/facilities").glob("facility_*.tres"):
        add_zh_resource(out, "facility/" + p.stem[9:], str(p))
    for p in pathlib.Path("resources/shop/items").glob("shop_*.tres"):
        text = p.read_text(encoding="utf-8")
        blocks = text.split("[resource]")
        tail = blocks[-1] if len(blocks) > 1 else text
        idm = re.search(r'^id = "([^"]+)"', tail, re.M)
        nm = re.search(r'^display_name = "([^"]+)"', tail, re.M)
        ds = re.search(r'^description = "([^"]+)"', tail, re.M)
        if idm:
            cid = idm.group(1)
            out[ckey(cid, "name")] = nm.group(1) if nm else cid
            if ds:
                out[ckey(cid, "desc")] = ds.group(1)
    for sid, name in [("muzzle", "枪口"), ("sight", "瞄具"), ("mag", "弹匣"), ("stock", "枪托")]:
        out[f"content.attachment_slot_{sid}.name"] = name
    # P1 街机化：道具 / 章节 / 运行定义 / 精英敌人（中文回退源 = 资源字段）
    for p in pathlib.Path("resources/powerups").glob("power_up_*.tres"):
        text = p.read_text(encoding="utf-8")
        idm = re.search(r'^id = "([^"]+)"', text, re.M)
        nm = re.search(r'^display_name = "([^"]+)"', text, re.M)
        if idm and nm:
            out[ckey(idm.group(1), "name")] = nm.group(1)
    for p in pathlib.Path("resources/chapters").glob("chapter_*.tres"):
        text = p.read_text(encoding="utf-8")
        blocks = text.split("[resource]")
        tail = blocks[-1] if len(blocks) > 1 else text
        idm = re.search(r'^id = "([^"]+)"', tail, re.M)
        nm = re.search(r'^display_name = "([^"]+)"', tail, re.M)
        if idm and nm:
            out[ckey(idm.group(1), "name")] = nm.group(1)
    run_text = pathlib.Path("resources/runs/arcade_run.tres").read_text(encoding="utf-8")
    run_id = re.search(r'^id = "([^"]+)"', run_text, re.M)
    run_name = re.search(r'^display_name = "([^"]+)"', run_text, re.M)
    if run_id and run_name:
        out[ckey(run_id.group(1), "name")] = run_name.group(1)
    for p in pathlib.Path("resources/enemies").glob("enemy_*.tres"):
        add_zh_resource(out, "bulwark:enemy/" + p.stem[6:], str(p))
    return out


def build_content_en() -> dict:
    out = {}
    for tid, name in [("ar", "Assault Rifle"), ("sg", "Shotgun"), ("hg", "Pistol"),
                      ("lmg", "Light Machine Gun"), ("er", "Energy Rifle")]:
        out.update(cc("weapon/type/" + tid, name))
    for mid, name in [
        ("ar_1", "AR-1 Assault Rifle"), ("ar_2", "AR-2 Assault Rifle"), ("ar_3", "AR-3 Assault Rifle"),
        ("sg_1", "SG-1 Shotgun"), ("sg_2", "SG-2 Shotgun"), ("sg_3", "SG-3 Shotgun"),
        ("hg_1", "HG-1 Pistol"), ("hg_2", "HG-2 Pistol"), ("hg_3", "HG-3 Pistol"), ("hg_4", "HG-4 Heavy Pistol"),
        ("lmg_1", "LMG-1 Light Machine Gun"), ("lmg_2", "LMG-2 Light Machine Gun"), ("lmg_3", "LMG-3 Light Machine Gun"),
        ("er_1", "ER-1 Energy Rifle"), ("er_2", "ER-2 Energy Rifle"), ("er_3", "ER-3 Energy Rifle"),
    ]:
        out.update(cc("weapon/model/" + mid, name))
    out.update(cc("attachment/red_dot", "Red Dot Sight", "Small accuracy bonus, no zoom penalty"))
    out.update(cc("attachment/ext_mag", "Extended Mag", "Magazine capacity ×1.5 (refilled on equip)"))
    out.update(cc("attachment/compensator", "Compensator", "Spread tightened (more stable when firing)"))
    out.update(cc("attachment/light_stock", "Light Stock", "Reload time ×0.8"))
    for sid, name in [("muzzle", "Muzzle"), ("sight", "Sight"), ("mag", "Magazine"), ("stock", "Stock")]:
        out[f"content.attachment_slot_{sid}.name"] = name
    out.update(cc("facility/barricade", "Barricade"))
    out.update(cc("facility/turret", "Auto-Turret"))

    shop_en = {
        "damage_up": ("Gun Calibration (Damage +2)", "All weapons damage +2"),
        "fire_rate_up": ("Trigger Tuning (Fire Rate +8%)", "All weapons fire rate ×1.08"),
        "mag_up": ("Military Supply (Mag +25%)", "All weapons magazine size ×1.25"),
        "reload_up": ("Speed Loader (Reload -15%)", "All weapons reload time ×0.85"),
        "crit_chance_up": ("Precision Piercing (Crit +5%)", "All weapons crit chance +5%"),
        "switch_cd_down": ("Quick Sling (Switch CD -0.2s)", "Weapon switch cooldown -0.2s"),
        "max_hp_up": ("First Aid Training (Max HP +20)", "Max health +20 (instantly refills the difference)"),
        "armor_up": ("Ceramic Plate (Armor +5%)", "Player armor +5%"),
        "move_speed_up": ("Marching Boots (Speed +6%)", "Move speed ×1.06"),
        "lifesteal_up": ("Field Lifesteal (Lifesteal +5%)", "Heal 5% of damage dealt"),
        "turret_damage_up": ("Turret Servo Tune (Turret Damage +1)", "Auto-turret damage +1"),
        "barricade_hp_up": ("Reinforced Sandbags (Barricade HP +20)", "New barricade durability +20"),
        "repair_speed_up": ("Field Engineer (Repair +20%)", "Facility repair speed +20%"),
        "build_cost_down": ("Structural Optimization (Cost -1)", "Facility material cost -1"),
        "material_yield_up": ("Salvage Training (Materials +10%)", "Kill material drop chance +10%"),
        "credit_yield_up": ("Bounty Negotiation (Credits +10%)", "Kill credit reward +10%"),
        "red_dot": ("Red Dot Sight (Attachment)", "Sight slot: spread -1.5° (no zoom)"),
        "ext_mag": ("Extended Mag (Attachment)", "Mag slot: capacity ×1.5"),
        "compensator": ("Compensator (Attachment)", "Muzzle slot: spread -1.0°"),
        "light_stock": ("Light Stock (Attachment)", "Stock slot: reload time ×0.8"),
        "barricade": ("Barricade Kit ×1", "Gain 1 barricade kit (place near base with E to block enemies)"),
        "reserve": ("Emergency Reserve +1", "Revive resource +1 (auto-revive after death; very scarce)"),
        "ammo_crate": ("Ammo Crate +30", "Bullet reserve +30 (intermission supply)"),
    }
    for sid, (name, desc) in shop_en.items():
        out.update(cc("shop/item/" + sid, name, desc))
    for typ, names in {
        "ar": ["AR-2 Assault Rifle", "AR-3 Assault Rifle"],
        "sg": ["SG-2 Shotgun", "SG-3 Shotgun"],
        "hg": ["HG-2 Pistol", "HG-3 Pistol"],
        "lmg": ["LMG-1 Light Machine Gun", "LMG-2 Light Machine Gun", "LMG-3 Light Machine Gun"],
        "er": ["ER-1 Energy Rifle", "ER-2 Energy Rifle", "ER-3 Energy Rifle"],
    }.items():
        start = 2 if typ in ("ar", "sg", "hg") else 1
        for idx, name in enumerate(names, start):
            out.update(cc(f"shop/item/weapon_crate_{typ}_{idx}", f"Weapon Crate · {name}",
                          "Adds the model to your personal arsenal; equip it at the workbench."))
    # P1 街机化：道具 / 章节 / 运行定义 / 精英敌人英文
    for power_id, name in [
        ("power/ammo", "Ammo Box"), ("power/material", "Materials"),
        ("power/heal", "Medkit"), ("power/fire_rate", "Rapid Fire"),
        ("power/pellets", "Triple Shot"), ("power/shield", "Shield"),
        ("power/score", "Score Boost"), ("power/reserve", "Extra Life"),
    ]:
        out.update(cc(power_id, name))
    for chapter_id, name in [
        ("chapter/1", "Chapter 1 · Outpost Edge"),
        ("chapter/2", "Chapter 2 · Ruined Town"),
        ("chapter/3", "Chapter 3 · Contaminated Zone"),
        ("chapter/4", "Chapter 4 · Nest"),
    ]:
        out.update(cc(chapter_id, name))
    out.update(cc("run/arcade", "Arcade Chapters"))
    for stem, name in {
        "enemy_runner": "Runner",
        "enemy_runner_fast": "Fast Runner",
        "enemy_runner_tough": "Tough Runner",
        "enemy_self_destruct": "Self-Destruct",
        "enemy_spitter": "Spitter",
        "enemy_armored": "Armored Beast",
        "enemy_flying": "Flyer",
        "enemy_sniper": "Sniper",
        "enemy_elite_behemoth": "Elite Behemoth",
    }.items():
        out.update(cc("bulwark:enemy/" + stem[6:], name))
    return out


STRUCT_ZH = {
    "common.currency": "货币", "common.material": "建材", "common.reserve": "储备",
    "common.health": "生命", "common.base": "基地", "common.ammo": "弹药", "common.wave": "波",
    "common.player_number": "玩家 {0}", "common.unknown": "未知", "common.empty": "空", "common.empty_paren": "（空）",
    "common.slot_main": "主", "common.slot_sub": "副", "common.slot_pistol": "手枪",
    "hud.resources_placeholder": "货币 -- · 建材 -- · 储备 --", "hud.resources": "货币 {0} · 建材 {1} · 储备 {2}",
    "hud.health_placeholder": "生命 --", "hud.health": "生命 {0}/{1}",
    "hud.base_placeholder": "基地 --", "hud.base": "基地 {0}/{1}",
    "hud.wave_placeholder": "第 -/- 波", "hud.wave": "第 {0} 波",
    "hud.ammo_title": "弹药", "hud.ammo_display": "/ {0}",
    "hud.slot_badge": "{0} {1}",
    "hud.facility_hint": "设施：{0}（F 切换，E 放置/交互）",
    "hud.pause_requests": "{0} 请求暂停 ({1}/{2}) · 全员请求才暂停",
    "hud.revive": "复活中 {0}s",
    "hud.switching": "切换中 {0}s", "hud.switching_dots": "切换中…", "hud.slot_empty": "槽位 {0} 空",
    "hud.reloading": "换弹 {0}s",
    "hud.tier_heavy": "大量", "hud.tier_medium": "中等", "hud.tier_light": "少量", "hud.tier_unknown": "未知",
    "hud.elite_warning": " · 精英单位出现", "hud.incoming": "预计{0}来袭{1}",
    "hud.banner_wave_warning": "第 {0} 波 · {1}{2}", "hud.banner_contact": "接敌！",
    "hud.banner_wave_cleared": "第 {0} 波击退。", "hud.banner_died": "阵亡。正在调用应急储备…",
    "hud.controls_hint": "WASD 移动 · 左键射击 · R 换弹 · 1/2/3 切枪 · E 路障 · Esc 暂停",
    "shop.title": "军需站", "shop.offers_title": "补给",
    "shop.sort_default": "默认序", "shop.sort_category": "按类别", "shop.sort_rarity": "按稀有度", "shop.sort_price": "按价格",
    "shop.slot_main": "主武器", "shop.slot_sub": "副武器", "shop.slot_pistol": "手枪",
    "shop.workbench": "改枪台", "shop.workbench_empty": "改枪台 · 空", "shop.workbench_model": "改枪台 · {0}",
    "shop.attachment_slots": "配件槽", "shop.bag": "背包", "shop.continue": "继续",
    "shop.no_offers": "暂无货物。", "shop.arsenal_empty": "军械库为空。", "shop.no_models_for_slot": "该槽位暂无可用型号。",
    "shop.current_prefix": "[当前] ", "shop.owned_count": "已购 {0}", "shop.buy": "购买",
    "shop.feedback_bought": "购入 {0} · ¥{1}", "shop.feedback_not_enough": "货币不足。", "shop.feedback_not_found": "商品已下架。",
    "shop.feedback_equipped": "已装配 {0}", "shop.feedback_equip_failed": "装配失败。", "shop.feedback_unequipped": "已卸下 {0}",
    "shop.feedback_model_changed": "已更换为 {0}", "shop.bag_empty": "背包是空的。", "shop.equip": "装配", "shop.unequip": "卸下",
    "shop.rarity_rare": "[稀有] ", "shop.rarity_epic": "[史诗] ", "shop.rarity_legendary": "[传说] ",
    "result.stats": "到达波次 {0} · 击杀 {1} · 货币 {2} · 建材 {3}",
    "hud.score": "分数 {0}", "hud.combo": "连击 {0} · ×{1}", "hud.buff_item": "{0} {1}s",
    "hud.banner_chapter": "{0} · 第 {1} 波",
    "result.score": "总分：{0}", "result.combo": "最高连击：{0}", "result.time": "用时：{0}s",
    "result.highscores": "—— 本机 Top {0} ——", "result.highscore_entry": "{0}. {1}分 · 连击{2} · {3}s",
    "result.highscore_rank": "本局名次：第 {0} 名",
    "menu.subtitle": "FRONTLINE BULWARK",
    "settings.key.aim": "瞄准",
    "settings.key.cycle_facility": "切换设施",
    "settings.key.process": "处理",
    "settings.key.clear": "清空",
    "settings.key.prev_device": "上一个设备",
    "settings.key.next_device": "下一个设备",
    "net.error_port_in_use": "端口 {0} 被占用或不可用（err={1}）",
    "net.error_connect": "无法连接 {0}:{1}（err={2}）",
    "net.error_connect_failed": "连接失败：{0}:{1}（host 未开或端口不符？）",
    "net.error_disconnected": "与 host 的连接已断开",
    "net.error_join_room": "加入房间失败（err={0}）",
    "net.error_relay": "Relay 错误：{0}",
}

STRUCT_EN = {
    "common.currency": "Credits", "common.material": "Materials", "common.reserve": "Reserves",
    "common.health": "HP", "common.base": "Base", "common.ammo": "Ammo", "common.wave": "Wave",
    "common.player_number": "Player {0}", "common.unknown": "Unknown", "common.empty": "Empty", "common.empty_paren": "(Empty)",
    "common.slot_main": "Main", "common.slot_sub": "Sub", "common.slot_pistol": "Pistol",
    "hud.resources_placeholder": "Credits -- · Materials -- · Reserves --", "hud.resources": "Credits {0} · Materials {1} · Reserves {2}",
    "hud.health_placeholder": "HP --", "hud.health": "HP {0}/{1}",
    "hud.base_placeholder": "Base --", "hud.base": "Base {0}/{1}",
    "hud.wave_placeholder": "Wave -/-", "hud.wave": "Wave {0}",
    "hud.ammo_title": "AMMO", "hud.ammo_display": "/ {0}",
    "hud.slot_badge": "{0} {1}",
    "hud.facility_hint": "Facility: {0} (F to cycle, E to place/interact)",
    "hud.pause_requests": "{0} requested pause ({1}/{2}) · All players must request to pause",
    "hud.revive": "Reviving {0}s",
    "hud.switching": "Switching {0}s", "hud.switching_dots": "Switching…", "hud.slot_empty": "Slot {0} is empty",
    "hud.reloading": "Reloading {0}s",
    "hud.tier_heavy": "Heavy", "hud.tier_medium": "Medium", "hud.tier_light": "Light", "hud.tier_unknown": "Unknown",
    "hud.elite_warning": " · Elite unit approaching", "hud.incoming": "Expect {0} incoming{1}",
    "hud.banner_wave_warning": "Wave {0} · {1}{2}", "hud.banner_contact": "Contact!",
    "hud.banner_wave_cleared": "Wave {0} repelled.", "hud.banner_died": "Down. Calling emergency reserve…",
    "hud.controls_hint": "WASD move · LMB shoot · R reload · 1/2/3 switch · E barricade · Esc pause",
    "shop.title": "Supply Depot", "shop.offers_title": "Supplies",
    "shop.sort_default": "Default", "shop.sort_category": "By Category", "shop.sort_rarity": "By Rarity", "shop.sort_price": "By Price",
    "shop.slot_main": "Primary", "shop.slot_sub": "Secondary", "shop.slot_pistol": "Pistol",
    "shop.workbench": "Gun Bench", "shop.workbench_empty": "Gun Bench · Empty", "shop.workbench_model": "Gun Bench · {0}",
    "shop.attachment_slots": "Attachment Slots", "shop.bag": "Bag", "shop.continue": "Continue",
    "shop.no_offers": "No supplies available.", "shop.arsenal_empty": "Your arsenal is empty.", "shop.no_models_for_slot": "No available models for this slot.",
    "shop.current_prefix": "[Equipped] ", "shop.owned_count": "Owned {0}", "shop.buy": "Buy",
    "shop.feedback_bought": "Bought {0} · ¥{1}", "shop.feedback_not_enough": "Not enough credits.", "shop.feedback_not_found": "Item no longer offered.",
    "shop.feedback_equipped": "Equipped {0}", "shop.feedback_equip_failed": "Equip failed.", "shop.feedback_unequipped": "Unequipped {0}",
    "shop.feedback_model_changed": "Switched to {0}", "shop.bag_empty": "Bag is empty.", "shop.equip": "Equip", "shop.unequip": "Unequip",
    "shop.rarity_rare": "[Rare] ", "shop.rarity_epic": "[Epic] ", "shop.rarity_legendary": "[Legendary] ",
    "result.stats": "Waves {0} · Kills {1} · Credits {2} · Materials {3}",
    "hud.score": "Score {0}", "hud.combo": "Combo {0} · x{1}", "hud.buff_item": "{0} {1}s",
    "hud.banner_chapter": "{0} · Wave {1}",
    "result.score": "Total score: {0}", "result.combo": "Best combo: {0}", "result.time": "Time: {0}s",
    "result.highscores": "—— Local Top {0} ——", "result.highscore_entry": "{0}. {1} pts · combo {2} · {3}s",
    "result.highscore_rank": "This run ranked: #{0}",
    "menu.subtitle": "FRONTLINE BULWARK",
    "settings.key.aim": "Aim",
    "settings.key.cycle_facility": "Cycle Facility",
    "settings.key.process": "Process",
    "settings.key.clear": "Clear",
    "settings.key.prev_device": "Previous Device",
    "settings.key.next_device": "Next Device",
    "net.error_port_in_use": "Port {0} is unavailable (err={1})",
    "net.error_connect": "Cannot connect to {0}:{1} (err={2})",
    "net.error_connect_failed": "Connection failed: {0}:{1} (host down or wrong port?)",
    "net.error_disconnected": "Connection to host lost",
    "net.error_join_room": "Failed to join room (err={0})",
    "net.error_relay": "Relay error: {0}",
}


def main():
    zh_path = pathlib.Path("locales/zh.json")
    en_path = pathlib.Path("locales/en.json")
    zh = json.loads(zh_path.read_text(encoding="utf-8"))
    en = json.loads(en_path.read_text(encoding="utf-8"))
    for key in list(zh.keys()):
        if key.startswith("content."):
            zh.pop(key, None)
    for key in list(en.keys()):
        if key.startswith("content."):
            en.pop(key, None)
    zh.update(STRUCT_ZH)
    en.update(STRUCT_EN)
    zh.update(build_content_zh())
    en.update(build_content_en())
    zh_path.write_text(json.dumps(zh, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")
    en_path.write_text(json.dumps(en, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")
    print("zh keys:", len(zh), "en keys:", len(en))


if __name__ == "__main__":
    main()
