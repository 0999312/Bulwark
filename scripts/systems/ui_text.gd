class_name UiText
extends RefCounted
## 项目统一 UI 文案入口（i18n 硬约束）：
## - 用户可见字符串禁止硬编码，一律经本类 / tr() / I18NManager.get_text 取翻译
## - content_name/content_desc 用于内容数据（武器/商品/技能等）的显示名与描述：
##   翻译键规则 content.<id 斜杠换下划线>.<field>，缺失时回退资源内 display_name/description
## - 语言切换后各面板须订阅 LanguageChangedEvent 并重建可见文本

static func text(key: String, args: Array = []) -> String:
	return I18NManager.get_text(key, args)

## 有回退值的翻译：键缺失时使用 fallback（并同样支持占位符）
static func localized(key: String, fallback: String, args: Array = []) -> String:
	var translated := I18NManager.get_text(key)
	if translated == key:
		return fallback.format(args) if not args.is_empty() else fallback
	return translated.format(args) if not args.is_empty() else translated

static func content_name(content_id: String, fallback: String) -> String:
	return localized(content_key(content_id, "name"), fallback)

static func content_description(content_id: String, fallback: String) -> String:
	return localized(content_key(content_id, "desc"), fallback)

static func content_key(content_id: String, field: String) -> String:
	var cleaned := content_id.replace(":", "_").replace("/", "_") \
		.replace("-", "_").replace(".", "_")
	return "content.%s.%s" % [cleaned, field]
