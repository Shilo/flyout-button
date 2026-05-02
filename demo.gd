extends Control

const FlyoutButtonItem := preload("res://flyout_button_item.gd")

const ICON_RECTANGLE_FILLED := preload("res://icons/RectangleFilled.svg")
const ICON_ELLIPSE := preload("res://icons/Ellipse.svg")
const ICON_ELLIPSE_FILLED := preload("res://icons/EllipseFilled.svg")


func _ready() -> void:
	_make_edge_strip(
		"TopTools",
		Vector2(0.5, 0.0),
		Vector2(-54, 8),
		Vector2(54, 40),
		HBoxContainer.new(),
		FlyoutButton.PopupDirection.DOWN
	)
	_make_edge_strip(
		"BottomTools",
		Vector2(0.5, 1.0),
		Vector2(-54, -40),
		Vector2(54, -8),
		HBoxContainer.new(),
		FlyoutButton.PopupDirection.UP
	)
	_make_edge_strip(
		"LeftTools",
		Vector2(0.0, 0.5),
		Vector2(8, -54),
		Vector2(40, 54),
		VBoxContainer.new(),
		FlyoutButton.PopupDirection.RIGHT
	)
	_make_edge_strip(
		"RightTools",
		Vector2(1.0, 0.5),
		Vector2(-40, -54),
		Vector2(-8, 54),
		VBoxContainer.new(),
		FlyoutButton.PopupDirection.LEFT
	)


func _make_edge_strip(
	strip_name: String,
	anchor: Vector2,
	offset_start: Vector2,
	offset_end: Vector2,
	container: BoxContainer,
	direction: int
) -> void:
	container.name = strip_name
	container.anchor_left = anchor.x
	container.anchor_right = anchor.x
	container.anchor_top = anchor.y
	container.anchor_bottom = anchor.y
	container.offset_left = offset_start.x
	container.offset_top = offset_start.y
	container.offset_right = offset_end.x
	container.offset_bottom = offset_end.y
	container.add_theme_constant_override("separation", 0)
	add_child(container)

	var group := ButtonGroup.new()
	var shape_button := _make_button("Shape", group, direction, _shape_items())
	container.add_child(shape_button)
	container.add_child(_make_button("Fill", group, direction, _fill_items()))
	container.add_child(_make_button("Editor", group, direction, _editor_items()))
	shape_button.set_pressed_no_signal(true)


func _make_button(
	button_name: String,
	group: ButtonGroup,
	direction: int,
	items: Array[FlyoutButtonItem]
) -> FlyoutButton:
	var button := FlyoutButton.new()
	button.name = button_name
	button.button_group = group
	button.popup_direction = direction as FlyoutButton.PopupDirection
	button.options = items
	button.custom_minimum_size = Vector2(32, 32)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


func _shape_items() -> Array[FlyoutButtonItem]:
	return [
		_make_item(&"rectangle_filled", ICON_RECTANGLE_FILLED, "Rectangle Filled"),
		_make_item(&"ellipse_outline", ICON_ELLIPSE, "Ellipse Outline"),
		_make_item(&"ellipse_filled", ICON_ELLIPSE_FILLED, "Ellipse Filled"),
	]


func _fill_items() -> Array[FlyoutButtonItem]:
	return [
		_make_item(&"fill_rectangle", ICON_RECTANGLE_FILLED, "Fill Rectangle"),
		_make_item(&"fill_ellipse", ICON_ELLIPSE_FILLED, "Fill Ellipse"),
	]


func _editor_items() -> Array[FlyoutButtonItem]:
	return [
		_make_editor_item(&"editor_select", &"ToolSelect", "Editor Select"),
		_make_editor_item(&"editor_move", &"Move", "Editor Move"),
		_make_editor_item(&"editor_anchor", &"Anchor", "Editor Anchor"),
	]


func _make_item(state: StringName, texture: Texture2D, tooltip: String) -> FlyoutButtonItem:
	var item: FlyoutButtonItem = FlyoutButtonItem.new()
	item.state = state
	item.icon = texture
	item.tooltip = tooltip
	return item


func _make_editor_item(state: StringName, editor_icon: StringName, tooltip: String) -> FlyoutButtonItem:
	var item: FlyoutButtonItem = FlyoutButtonItem.new()
	item.state = state
	item.editor_icon = editor_icon
	item.tooltip = tooltip
	item.icon = ICON_RECTANGLE_FILLED if state == &"editor_select" else ICON_ELLIPSE
	return item
