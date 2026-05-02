@tool
extends OptionButton
class_name FlyoutButton

enum PopupDirection { RIGHT, LEFT, UP, DOWN }

const EDITOR_ICONS_TYPE := &"EditorIcons"

@export var popup_direction := PopupDirection.DOWN

@export var options: Array[FlyoutButtonItem] = []:
	set(value):
		options = value
		_rebuild_options()

var selected_title: StringName:
	get:
		return get_selected_title()

var _transparent_icon: ImageTexture
var _popup_was_positioned := false


func _init() -> void:
	flat = true
	toggle_mode = true
	fit_to_longest_item = false
	allow_reselect = true
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	text = ""


func _ready() -> void:
	_ensure_transparent_icon()
	_configure_button_theme()
	_configure_popup()

	if not item_selected.is_connected(_on_item_selected):
		item_selected.connect(_on_item_selected)
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)

	_rebuild_options()


func _shortcut_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return

	for index in range(options.size()):
		var item := options[index]
		if item != null and item.shortcut != null and item.shortcut.matches_event(event):
			select(index)
			_on_item_selected(index)
			accept_event()
			return


func _process(_delta: float) -> void:
	var popup := get_popup()
	if popup.visible:
		_position_popup()
	elif _popup_was_positioned:
		_popup_was_positioned = false
		set_process(false)


func add_flyout_item(item: FlyoutButtonItem) -> void:
	options.append(item)
	_rebuild_options()


func get_selected_item() -> FlyoutButtonItem:
	var index := selected
	if index < 0 or index >= options.size():
		return null
	return options[index]


func get_selected_title() -> StringName:
	var item := get_selected_item()
	if item == null:
		return &""
	return item.title


func _rebuild_options() -> void:
	if not is_inside_tree():
		return

	clear()
	_configure_popup()
	var popup := get_popup()

	for index in range(options.size()):
		var item: FlyoutButtonItem = options[index]
		var item_icon := _resolve_icon(item)
		var item_text := "" if item_icon != null else String(item.title)
		add_icon_item(item_icon, item_text, index)
		set_item_metadata(index, item.title)
		set_item_tooltip(index, item.tooltip)
		popup.set_item_as_radio_checkable(index, false)
		popup.set_item_as_checkable(index, false)
		if item.shortcut != null:
			popup.set_item_shortcut(index, item.shortcut)
		if item_icon != null:
			popup.set_item_icon_max_width(index, item_icon.get_width())

	if options.is_empty():
		icon = null
		text = ""
		tooltip_text = ""
		return

	if selected < 0 or selected >= options.size():
		select(0)
	_apply_selected_item(selected)


func _configure_button_theme() -> void:
	_ensure_transparent_icon()
	add_theme_icon_override(&"arrow", _transparent_icon)
	add_theme_constant_override(&"h_separation", 0)
	add_theme_constant_override(&"arrow_margin", 0)


func _configure_popup() -> void:
	var popup := get_popup()
	popup.hide_on_item_selection = true
	popup.hide_on_checkable_item_selection = true
	popup.allow_search = false
	popup.prefer_native_menu = false
	popup.add_theme_icon_override(&"checked", _transparent_icon)
	popup.add_theme_icon_override(&"unchecked", _transparent_icon)
	popup.add_theme_icon_override(&"radio_checked", _transparent_icon)
	popup.add_theme_icon_override(&"radio_unchecked", _transparent_icon)
	popup.add_theme_constant_override(&"gutter_compact", 1)
	popup.add_theme_constant_override(&"h_separation", 0)
	popup.add_theme_constant_override(&"v_separation", 0)
	popup.add_theme_constant_override(&"item_start_padding", 0)
	popup.add_theme_constant_override(&"item_end_padding", 0)

	if not popup.about_to_popup.is_connected(_on_popup_about_to_popup):
		popup.about_to_popup.connect(_on_popup_about_to_popup)


func _on_popup_about_to_popup() -> void:
	_popup_was_positioned = false
	set_process(true)
	call_deferred("_position_popup")


func _on_pressed() -> void:
	button_pressed = true


func _on_item_selected(index: int) -> void:
	if index < 0 or index >= options.size():
		return

	_apply_selected_item(index)
	button_pressed = true


func _apply_selected_item(index: int) -> void:
	var item: FlyoutButtonItem = options[index]
	icon = _resolve_icon(item)
	text = "" if icon != null else String(item.title)
	tooltip_text = item.tooltip


func _position_popup() -> void:
	var popup := get_popup()
	if not popup.visible:
		return

	var direction := _choose_direction()
	var button_rect := get_global_rect()
	var viewport_rect := get_viewport_rect()
	var popup_size := Vector2(popup.size)
	if popup_size.x <= 0.0 or popup_size.y <= 0.0:
		popup_size = Vector2(popup.get_contents_minimum_size())

	var popup_position := button_rect.position
	match direction:
		PopupDirection.RIGHT:
			popup_position.x = button_rect.end.x
		PopupDirection.LEFT:
			popup_position.x = button_rect.position.x - popup_size.x
		PopupDirection.UP:
			popup_position.y = button_rect.position.y - popup_size.y
		PopupDirection.DOWN:
			popup_position.y = button_rect.end.y

	if direction == PopupDirection.RIGHT or direction == PopupDirection.LEFT:
		popup_position.y = button_rect.position.y
	else:
		popup_position.x = button_rect.position.x

	popup_position.x = clamp(popup_position.x, 0.0, max(0.0, viewport_rect.size.x - popup_size.x))
	popup_position.y = clamp(popup_position.y, 0.0, max(0.0, viewport_rect.size.y - popup_size.y))
	popup.position = Vector2i(popup_position.round())
	_popup_was_positioned = true


func _choose_direction() -> int:
	var preferred := popup_direction
	var popup := get_popup()
	var button_rect := get_global_rect()
	var popup_size := Vector2(popup.size)
	if popup_size.x <= 0.0 or popup_size.y <= 0.0:
		popup_size = Vector2(popup.get_contents_minimum_size())

	if _direction_fits(preferred, button_rect, popup_size):
		return preferred

	var fallbacks := _fallback_directions(preferred)
	for fallback in fallbacks:
		if _direction_fits(fallback, button_rect, popup_size):
			return fallback

	return fallbacks[0] if not fallbacks.is_empty() else preferred


func _fallback_directions(preferred: int) -> Array[int]:
	match preferred:
		PopupDirection.DOWN:
			return [PopupDirection.UP, PopupDirection.RIGHT, PopupDirection.LEFT]
		PopupDirection.UP:
			return [PopupDirection.DOWN, PopupDirection.RIGHT, PopupDirection.LEFT]
		PopupDirection.LEFT:
			return [PopupDirection.RIGHT, PopupDirection.DOWN, PopupDirection.UP]
		PopupDirection.RIGHT:
			return [PopupDirection.LEFT, PopupDirection.DOWN, PopupDirection.UP]
	return [PopupDirection.DOWN, PopupDirection.UP, PopupDirection.RIGHT, PopupDirection.LEFT]


func _direction_fits(direction: int, button_rect: Rect2, popup_size: Vector2) -> bool:
	var viewport_size := get_viewport_rect().size
	match direction:
		PopupDirection.RIGHT:
			return button_rect.end.x + popup_size.x <= viewport_size.x
		PopupDirection.LEFT:
			return button_rect.position.x - popup_size.x >= 0.0
		PopupDirection.UP:
			return button_rect.position.y - popup_size.y >= 0.0
		PopupDirection.DOWN:
			return button_rect.end.y + popup_size.y <= viewport_size.y
	return false


func _resolve_icon(item: FlyoutButtonItem) -> Texture2D:
	if item == null:
		return null
	if item.icon != null:
		return item.icon
	if item.editor_icon != &"":
		return _get_editor_icon(item.editor_icon)
	return null


func _get_editor_icon(icon_name: StringName) -> Texture2D:
	if not Engine.is_editor_hint():
		return null
	if not Engine.has_singleton(&"EditorInterface"):
		return null

	var editor_interface := Engine.get_singleton(&"EditorInterface")
	if editor_interface == null:
		return null

	if editor_interface.has_method("get_editor_theme"):
		var editor_theme := editor_interface.call("get_editor_theme") as Theme
		if editor_theme != null and editor_theme.has_icon(icon_name, EDITOR_ICONS_TYPE):
			return editor_theme.get_icon(icon_name, EDITOR_ICONS_TYPE)

	if editor_interface.has_method("get_base_control"):
		var base_control := editor_interface.call("get_base_control") as Control
		if base_control != null and base_control.has_theme_icon(icon_name, EDITOR_ICONS_TYPE):
			return base_control.get_theme_icon(icon_name, EDITOR_ICONS_TYPE)

	return null


func _ensure_transparent_icon() -> void:
	if _transparent_icon != null:
		return

	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	_transparent_icon = ImageTexture.create_from_image(image)
