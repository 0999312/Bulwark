class_name ChapterRewardPanel
extends BaseModalPanel
## P2-19 章间三选一奖励面板
## 数据：{ choices: Array[PowerUpData], chapter_index:int, chapter_name:String, lore_text:String }
## 选择后发布 ChapterRewardPickedEvent（GameSession host 裁决），随后关闭并恢复

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var choices_box: VBoxContainer = %ChoicesBox

var _choices: Array[PowerUpData] = []
var _chapter_index := -1

func _on_open(data: Dictionary = {}) -> void:
	super(data)
	_choices.clear()
	var raw_choices: Array = data.get("choices", [])
	for item in raw_choices:
		if item is PowerUpData:
			_choices.append(item as PowerUpData)
	_chapter_index = int(data.get("chapter_index", -1))
	title_label.text = UiText.text("p2.chapter_reward_title")
	var chapter_name := str(data.get("chapter_name", ""))
	var lore_text := str(data.get("lore_text", ""))
	subtitle_label.text = UiText.text("p2.chapter_reward_subtitle", [chapter_name])
	if not lore_text.is_empty():
		subtitle_label.text = "%s\n%s" % [subtitle_label.text, lore_text]
	_rebuild_choices()

func _on_close() -> void:
	super()

func _rebuild_choices() -> void:
	for child in choices_box.get_children():
		choices_box.remove_child(child)
		child.free()
	for i in _choices.size():
		var power: PowerUpData = _choices[i]
		if power == null:
			continue
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 62)
		var name_text := UiText.content_name(power.id, power.display_name)
		var desc_text := UiText.content_description(power.id, "")
		btn.text = name_text if desc_text.is_empty() else "%s\n%s" % [name_text, desc_text]
		btn.pressed.connect(_pick.bind(i))
		choices_box.add_child(btn)
	if choices_box.get_child_count() == 0:
		var fallback := Button.new()
		fallback.text = UiText.text("p2.chapter_reward_none")
		fallback.pressed.connect(_pick.bind(-1))
		choices_box.add_child(fallback)

func _pick(index: int) -> void:
	if index >= 0 and index < _choices.size():
		var power: PowerUpData = _choices[index]
		EventBus.publish(ChapterRewardPickedEvent.new(power.id, _chapter_index))
	UIManager.close_panel(panel_id)
