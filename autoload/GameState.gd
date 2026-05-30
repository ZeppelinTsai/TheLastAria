extends Node

# ─────────────────────────────────────────
#  GameState.gd
#  Autoload — 提供乾淨的介面查詢遊戲狀態
#  實際資料存在 SaveManager，這裡只是包裝
# ─────────────────────────────────────────

# ── 章節 ──────────────────────────────────
enum Act { PROLOGUE, ACT1, ACT2, ACT3, FINAL }

func get_act() -> int:
	return SaveManager.get_story_value("act", Act.PROLOGUE)

func set_act(act: int) -> void:
	SaveManager.set_story_value("act", act)

func is_act_at_least(act: int) -> bool:
	return get_act() >= act

# ── 裂縫進程 ──────────────────────────────
# 0 = 序章（完美無瑕）
# 1 = Act1（腳踝裂痕）
# 2 = Act2（手臂裂開）
# 3 = Lumi犧牲後（裂到臉上）
# 4 = Final Act（金繼全身）

func get_crack_level() -> int:
	return SaveManager.get_story_value("crack_level", 0)

func set_crack_level(level: int) -> void:
	var clamped = clampi(level, 0, 4)
	SaveManager.set_story_value("crack_level", clamped)

func advance_crack() -> void:
	set_crack_level(get_crack_level() + 1)

# ── Lumi 狀態 ─────────────────────────────
func is_lumi_alive() -> bool:
	return not SaveManager.has_flag("lumi_dead")

func set_lumi_dead() -> void:
	SaveManager.set_flag("lumi_dead")

# ── 道具 ──────────────────────────────────
const ITEMS = {
	"memory_crystal": "item_memory_crystal",
	"battery":        "item_battery",
	"cryo_system":    "item_cryo_system",
	"name_tag":       "item_name_tag",
}

func has_item(item_id: String) -> bool:
	var flag = ITEMS.get(item_id, "")
	if flag == "":
		push_warning("GameState.has_item: unknown item '%s'" % item_id)
		return false
	return SaveManager.has_flag(flag)

func give_item(item_id: String) -> void:
	var flag = ITEMS.get(item_id, "")
	if flag == "":
		push_warning("GameState.give_item: unknown item '%s'" % item_id)
		return
	SaveManager.set_flag(flag)

# ── 結局解鎖 ──────────────────────────────
func unlock_ending(ending: int) -> void:
	SaveManager.set_flag("ending_%d_unlocked" % ending)

func is_ending_unlocked(ending: int) -> bool:
	return SaveManager.has_flag("ending_%d_unlocked" % ending)

# ── 結局條件判定 ──────────────────────────
# 結局1：Lumi死亡（或存活皆可），未做結局2選擇
# 結局2：Lumi存活，選擇讓Lyra同步Orion記憶
# 結局3：Lumi存活，取得name_tag，進入禁忌區域

func can_reach_ending2() -> bool:
	return is_lumi_alive()

func can_reach_ending3() -> bool:
	return is_lumi_alive() and has_item("name_tag") and is_ending_unlocked(2)

# ── 便利查詢 ──────────────────────────────
func debug_status() -> String:
	return "[GameState] Act:%d Crack:%d Lumi:%s Items:%s" % [
		get_act(),
		get_crack_level(),
		"alive" if is_lumi_alive() else "dead",
		str(ITEMS.keys().filter(func(k): return has_item(k)))
	]