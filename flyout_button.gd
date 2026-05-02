@tool
extends Button
class_name FlyoutButton

signal state_clicked(state: StringName, index: int, item: Dictionary)
signal state_changed(state: StringName, index: int, item: Dictionary)
signal flyout_opened
signal flyout_closed

enum FlyoutDirection { AUTO, RIGHT, LEFT, DOWN, UP }

const EDITOR_ICONS_TYPE := &"EditorIcons"

@export var items: Array[Dictionary] = []:
	set(value):
		items = value
		if selected_index >= items.size():
			selected_index = max(items.size() - 1, 0)
		_refresh_button()

@export var selected_index := 0:
	set(value):
		selected_index = max(value, 0)
		_refresh_button()

@export_range(16, 96, 1) var button_side := 26:
	set(value):
		button_side = value
		_apply_button_metrics()

@export_range(8, 64, 1) var icon_side := 18:
	set(value):
		icon_side = value
		_texture_cache.clear()
		_apply_button_metrics()
		_refresh_button()

@export var flyout_direction := FlyoutDirection.AUTO
@export var auto_preferred_direction := FlyoutDirection.RIGHT
@export_range(0, 24, 1) var flyout_gap := 2
@export var single_click_opens_flyout := true
@export var close_on_select := true
@export var open_on_right_click := true
@export var show_flyout_indicator := true
@export var allow_editor_icons := true
@export var use_generated_fallback_icons := true

@export_group("Colors")
@export var normal_color := Color(0.08, 0.09, 0.10, 1.0):
	set(value):
		normal_color = value
		_apply_theme()
@export var hover_color := Color(0.16, 0.18, 0.20, 1.0):
	set(value):
		hover_color = value
		_apply_theme()
@export var pressed_color := Color(0.20, 0.24, 0.28, 1.0):
	set(value):
		pressed_color = value
		_apply_theme()
@export var selected_color := Color(0.23, 0.30, 0.38, 1.0)
@export var border_color := Color(0.30, 0.35, 0.40, 1.0):
	set(value):
		border_color = value
		_apply_theme()
@export var icon_color := Color(0.86, 0.88, 0.90, 1.0):
	set(value):
		icon_color = value
		_texture_cache.clear()
		_refresh_button()
@export var panel_color := Color(0.055, 0.06, 0.068, 0.98)

var _popup_layer: CanvasLayer
var _panel: PanelContainer
var _strip: BoxContainer
var _item_buttons: Array[Button] = []
var _texture_cache: Dictionary = {}
var _current_direction := FlyoutDirection.RIGHT


func _ready() -> void:
	text = ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	_apply_button_metrics()
	_apply_theme()
	_refresh_button()


func _exit_tree() -> void:
	close_flyout()


func _get_minimum_size() -> Vector2:
	return Vector2(button_side, button_side)


func _process(_delta: float) -> void:
	if is_flyout_open():
		_position_panel()


func _input(event: InputEvent) -> void:
	if not is_flyout_open():
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_flyout()
		accept_event()
		return

	if event is InputEventMouseButton and event.pressed:
		var point: Vector2 = event.position
		if _control_contains_screen_point(self, point):
			return
		if is_instance_valid(_panel) and _control_contains_screen_point(_panel, point):
			return

		close_flyout()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if open_on_right_click and event.button_index == MOUSE_BUTTON_RIGHT:
			toggle_flyout()
			accept_event()


func _draw() -> void:
	if not show_flyout_indicator or items.size() <= 1:
		return

	var corner := Vector2(button_side - 7, button_side - 7)
	draw_colored_polygon(
		PackedVector2Array([
			corner + Vector2(5, 0),
			corner + Vector2(5, 5),
			corner + Vector2(0, 5),
		]),
		border_color.lightened(0.35)
	)


func open_flyout() -> void:
	if is_flyout_open() or items.is_empty():
		return

	_popup_layer = CanvasLayer.new()
	_popup_layer.name = "%sFlyoutLayer" % name
	_popup_layer.layer = 256
	get_tree().root.add_child(_popup_layer)

	_panel = PanelContainer.new()
	_panel.name = "FlyoutPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _make_style(panel_color, border_color, 1))
	_popup_layer.add_child(_panel)

	_current_direction = _choose_open_direction()
	_strip = VBoxContainer.new() if _is_vertical_direction(_current_direction) else HBoxContainer.new()
	_strip.name = "IconStrip"
	_strip.add_theme_constant_override("separation", 1)
	_panel.add_child(_strip)

	_item_buttons.clear()
	for index in range(items.size()):
		var item_button := _make_item_button(index)
		_strip.add_child(item_button)
		_item_buttons.append(item_button)

	_panel.reset_size()
	_position_panel()
	set_process(true)
	flyout_opened.emit()


func close_flyout() -> void:
	var was_open := is_flyout_open()
	if is_instance_valid(_popup_layer):
		_popup_layer.queue_free()
	_popup_layer = null
	_panel = null
	_strip = null
	_item_buttons.clear()
	set_process(false)
	if was_open:
		flyout_closed.emit()


func toggle_flyout() -> void:
	if is_flyout_open():
		close_flyout()
	else:
		open_flyout()


func is_flyout_open() -> bool:
	return is_instance_valid(_popup_layer) and is_instance_valid(_panel)


func select_state(index: int, emit_clicked := true) -> void:
	if index < 0 or index >= items.size():
		return

	var previous_index := selected_index
	selected_index = index
	_refresh_item_selection()

	var selected_item: Dictionary = items[index].duplicate(true)
	var state := _state_for_item(items[index], index)
	if emit_clicked:
		state_clicked.emit(state, index, selected_item)
	if previous_index != index:
		state_changed.emit(state, index, selected_item)
	if close_on_select:
		close_flyout()


func set_items(new_items: Array[Dictionary], new_selected_index := 0) -> void:
	items = new_items
	selected_index = new_selected_index
	_texture_cache.clear()
	_refresh_button()


func get_selected_state() -> StringName:
	if selected_index < 0 or selected_index >= items.size():
		return &""
	return _state_for_item(items[selected_index], selected_index)


func _on_pressed() -> void:
	if single_click_opens_flyout and items.size() > 1:
		toggle_flyout()
	elif not items.is_empty():
		select_state(selected_index, true)


func _on_item_pressed(index: int) -> void:
	select_state(index, true)


func _make_item_button(index: int) -> Button:
	var item: Dictionary = items[index]
	var item_button := Button.new()
	item_button.name = "Item%d" % index
	item_button.text = ""
	item_button.icon = _texture_for_item(item, index)
	item_button.toggle_mode = true
	item_button.button_pressed = index == selected_index
	item_button.focus_mode = Control.FOCUS_NONE
	item_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item_button.tooltip_text = _label_for_item(item, index)
	item_button.custom_minimum_size = Vector2(button_side, button_side)
	item_button.add_theme_constant_override("h_separation", 0)
	item_button.add_theme_constant_override("icon_max_width", icon_side)
	item_button.add_theme_stylebox_override("normal", _make_style(normal_color, border_color.darkened(0.15), 1))
	item_button.add_theme_stylebox_override("hover", _make_style(hover_color, border_color, 1))
	item_button.add_theme_stylebox_override("pressed", _make_style(selected_color, border_color.lightened(0.18), 1))
	item_button.add_theme_stylebox_override("hover_pressed", _make_style(selected_color.lightened(0.05), border_color.lightened(0.2), 1))
	item_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	item_button.pressed.connect(_on_item_pressed.bind(index))
	return item_button


func _refresh_item_selection() -> void:
	for index in range(_item_buttons.size()):
		_item_buttons[index].set_pressed_no_signal(index == selected_index)


func _refresh_button() -> void:
	if selected_index < 0 or selected_index >= items.size():
		icon = null
		tooltip_text = ""
		queue_redraw()
		return

	var item: Dictionary = items[selected_index]
	text = ""
	icon = _texture_for_item(item, selected_index)
	tooltip_text = _label_for_item(item, selected_index)
	queue_redraw()


func _apply_button_metrics() -> void:
	custom_minimum_size = Vector2(button_side, button_side)
	add_theme_constant_override("h_separation", 0)
	add_theme_constant_override("icon_max_width", icon_side)
	queue_redraw()


func _apply_theme() -> void:
	if not is_inside_tree():
		return

	add_theme_stylebox_override("normal", _make_style(normal_color, border_color.darkened(0.2), 1))
	add_theme_stylebox_override("hover", _make_style(hover_color, border_color, 1))
	add_theme_stylebox_override("pressed", _make_style(pressed_color, border_color.lightened(0.15), 1))
	add_theme_stylebox_override("hover_pressed", _make_style(pressed_color.lightened(0.05), border_color.lightened(0.2), 1))
	add_theme_stylebox_override("focus", _make_focus_style())
	add_theme_stylebox_override("disabled", _make_style(normal_color.darkened(0.25), border_color.darkened(0.4), 1))
	add_theme_color_override("icon_normal_color", icon_color)
	add_theme_color_override("icon_hover_color", icon_color.lightened(0.08))
	add_theme_color_override("icon_pressed_color", icon_color)
	add_theme_color_override("icon_focus_color", icon_color)
	add_theme_color_override("icon_disabled_color", icon_color.darkened(0.45))


func _position_panel() -> void:
	if not is_instance_valid(_panel):
		return

	var button_rect := get_global_rect()
	var panel_size := _panel.get_combined_minimum_size()
	var viewport_rect := get_viewport_rect()
	var position := button_rect.position

	match _current_direction:
		FlyoutDirection.RIGHT:
			position.x += button_rect.size.x + flyout_gap
		FlyoutDirection.LEFT:
			position.x -= panel_size.x + flyout_gap
		FlyoutDirection.DOWN:
			position.y += button_rect.size.y + flyout_gap
		FlyoutDirection.UP:
			position.y -= panel_size.y + flyout_gap

	position.x = clamp(position.x, 0.0, max(0.0, viewport_rect.size.x - panel_size.x))
	position.y = clamp(position.y, 0.0, max(0.0, viewport_rect.size.y - panel_size.y))
	_panel.position = position.round()
	_panel.size = panel_size


func _choose_open_direction() -> int:
	if flyout_direction != FlyoutDirection.AUTO:
		return flyout_direction

	var count: int = max(items.size(), 1)
	var separation: int = 1
	var horizontal_size := Vector2(
		button_side * count + separation * max(count - 1, 0) + 2,
		button_side + 2
	)
	var vertical_size := Vector2(
		button_side + 2,
		button_side * count + separation * max(count - 1, 0) + 2
	)

	for direction: int in _auto_direction_candidates():
		var panel_size := vertical_size if _is_vertical_direction(direction) else horizontal_size
		if _direction_fits(direction, panel_size):
			return direction

	return _best_available_direction(horizontal_size, vertical_size)


func _auto_direction_candidates() -> Array[int]:
	var preferred: int = auto_preferred_direction
	if preferred == FlyoutDirection.AUTO:
		preferred = FlyoutDirection.RIGHT

	var candidates: Array[int] = [preferred, _opposite_direction(preferred)]
	for direction: int in [FlyoutDirection.RIGHT, FlyoutDirection.LEFT, FlyoutDirection.DOWN, FlyoutDirection.UP]:
		if not candidates.has(direction):
			candidates.append(direction)
	return candidates


func _opposite_direction(direction: int) -> int:
	match direction:
		FlyoutDirection.RIGHT:
			return FlyoutDirection.LEFT
		FlyoutDirection.LEFT:
			return FlyoutDirection.RIGHT
		FlyoutDirection.DOWN:
			return FlyoutDirection.UP
		FlyoutDirection.UP:
			return FlyoutDirection.DOWN
	return FlyoutDirection.RIGHT


func _best_available_direction(horizontal_size: Vector2, vertical_size: Vector2) -> int:
	var button_rect := get_global_rect()
	var viewport_size := get_viewport_rect().size
	var scores := {
		FlyoutDirection.RIGHT: viewport_size.x - button_rect.end.x - flyout_gap - horizontal_size.x,
		FlyoutDirection.LEFT: button_rect.position.x - flyout_gap - horizontal_size.x,
		FlyoutDirection.DOWN: viewport_size.y - button_rect.end.y - flyout_gap - vertical_size.y,
		FlyoutDirection.UP: button_rect.position.y - flyout_gap - vertical_size.y,
	}
	var best_direction: int = FlyoutDirection.RIGHT
	var best_score: float = -INF
	for direction: int in scores:
		if scores[direction] > best_score:
			best_score = scores[direction]
			best_direction = direction
	return best_direction


func _direction_fits(direction: int, panel_size: Vector2) -> bool:
	var button_rect := get_global_rect()
	var viewport_size := get_viewport_rect().size
	match direction:
		FlyoutDirection.RIGHT:
			return button_rect.end.x + flyout_gap + panel_size.x <= viewport_size.x
		FlyoutDirection.LEFT:
			return button_rect.position.x - flyout_gap - panel_size.x >= 0.0
		FlyoutDirection.DOWN:
			return button_rect.end.y + flyout_gap + panel_size.y <= viewport_size.y
		FlyoutDirection.UP:
			return button_rect.position.y - flyout_gap - panel_size.y >= 0.0
	return false


func _is_vertical_direction(direction: int) -> bool:
	return direction == FlyoutDirection.DOWN or direction == FlyoutDirection.UP


func _texture_for_item(item: Dictionary, index: int) -> Texture2D:
	if item.has("icon") and item["icon"] is Texture2D:
		return item["icon"]

	if item.has("icon_path"):
		var loaded := load(str(item["icon_path"]))
		if loaded is Texture2D:
			return loaded

	if allow_editor_icons and item.has("editor_icon"):
		var editor_texture := _get_editor_icon(StringName(str(item["editor_icon"])))
		if editor_texture != null:
			return editor_texture

	if item.has("shape"):
		return _generated_shape_texture(item, index)

	if use_generated_fallback_icons:
		return _generated_fallback_texture(item, index)

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


func _generated_shape_texture(item: Dictionary, index: int) -> Texture2D:
	var cache_key := "%s:%d:%s:%s:%s" % [
		str(item.get("shape", "")),
		icon_side,
		str(item.get("filled", false)),
		str(item.get("color", icon_color)),
		index,
	]
	if _texture_cache.has(cache_key):
		return _texture_cache[cache_key]

	var image := Image.create(icon_side, icon_side, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	var color := _color_from_item(item, "color", icon_color)
	var filled := bool(item.get("filled", false))
	match str(item.get("shape", "")).to_lower():
		"rectangle", "rect":
			_draw_rect_icon(image, color, filled)
		"ellipse", "oval", "circle":
			_draw_ellipse_icon(image, color, filled)
		_:
			_draw_diamond_icon(image, color, filled)

	var texture := ImageTexture.create_from_image(image)
	_texture_cache[cache_key] = texture
	return texture


func _generated_fallback_texture(item: Dictionary, index: int) -> Texture2D:
	var cache_key := "fallback:%d:%d:%s" % [icon_side, index, str(item.get("editor_icon", item.get("state", index)))]
	if _texture_cache.has(cache_key):
		return _texture_cache[cache_key]

	var image := Image.create(icon_side, icon_side, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	var hue := fposmod(float(abs(hash(cache_key)) % 360) / 360.0, 1.0)
	var color := Color.from_hsv(hue, 0.45, 0.95, 1.0)
	_draw_diamond_icon(image, color, index % 2 == 0)

	var texture := ImageTexture.create_from_image(image)
	_texture_cache[cache_key] = texture
	return texture


func _draw_rect_icon(image: Image, color: Color, filled: bool) -> void:
	var min_xy: int = max(1, int(icon_side / 8))
	var max_xy: int = icon_side - min_xy - 1
	for y in range(min_xy, max_xy + 1):
		for x in range(min_xy, max_xy + 1):
			var edge: bool = x <= min_xy + 1 or x >= max_xy - 1 or y <= min_xy + 1 or y >= max_xy - 1
			if filled or edge:
				image.set_pixel(x, y, color)


func _draw_ellipse_icon(image: Image, color: Color, filled: bool) -> void:
	var center := Vector2((icon_side - 1) * 0.5, (icon_side - 1) * 0.5)
	var radius := Vector2(max(2.0, icon_side * 0.38), max(2.0, icon_side * 0.27))
	for y in range(icon_side):
		for x in range(icon_side):
			var p := Vector2(x, y)
			var normalized := Vector2((p.x - center.x) / radius.x, (p.y - center.y) / radius.y)
			var distance := normalized.length_squared()
			if filled and distance <= 1.0:
				image.set_pixel(x, y, color)
			elif not filled and distance <= 1.15 and distance >= 0.62:
				image.set_pixel(x, y, color)


func _draw_diamond_icon(image: Image, color: Color, filled: bool) -> void:
	var center := Vector2((icon_side - 1) * 0.5, (icon_side - 1) * 0.5)
	var radius: float = max(3.0, icon_side * 0.36)
	for y in range(icon_side):
		for x in range(icon_side):
			var d: float = abs(float(x) - center.x) + abs(float(y) - center.y)
			if filled and d <= radius:
				image.set_pixel(x, y, color)
			elif not filled and d <= radius and d >= radius - 2.0:
				image.set_pixel(x, y, color)


func _make_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(0)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


func _make_focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = border_color.lightened(0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	style.draw_center = false
	return style


func _control_contains_screen_point(control: Control, point: Vector2) -> bool:
	return control.get_global_rect().has_point(point)


func _state_for_item(item: Dictionary, index: int) -> StringName:
	if item.has("state"):
		return StringName(str(item["state"]))
	if item.has("id"):
		return StringName(str(item["id"]))
	return StringName("state_%d" % index)


func _label_for_item(item: Dictionary, index: int) -> String:
	if item.has("label"):
		return str(item["label"])
	if item.has("tooltip"):
		return str(item["tooltip"])
	return str(_state_for_item(item, index)).capitalize()


func _color_from_item(item: Dictionary, key: String, fallback: Color) -> Color:
	if not item.has(key):
		return fallback
	var value = item[key]
	if value is Color:
		return value
	if value is String:
		return Color(value)
	return fallback
