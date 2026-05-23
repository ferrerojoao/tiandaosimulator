## camera_controller.gd - 摄像机移动控制
extends Camera2D

const MAP_W: int = 6400
const MAP_H: int = 6400
const VP_W: int = 1920
const VP_H: int = 1080
const PAN_SPEED: float = 800.0
const ZOOM_MIN: float = 0.3
const ZOOM_MAX: float = 3.0
const ZOOM_STEP: float = 0.2

func _ready() -> void:
	enabled = true
	make_current()
	position = Vector2(MAP_W / 2.0, MAP_H / 2.0)

func _process(delta: float) -> void:
	var input = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):    input.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):  input.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):  input.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): input.x += 1
	position += input.normalized() * PAN_SPEED * delta / zoom.x
	_clamp()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom += Vector2(ZOOM_STEP, ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom -= Vector2(ZOOM_STEP, ZOOM_STEP)
		zoom = zoom.clamp(Vector2(ZOOM_MIN, ZOOM_MIN), Vector2(ZOOM_MAX, ZOOM_MAX))
	_clamp()

func _clamp() -> void:
	var half: Vector2 = Vector2(VP_W, VP_H) / zoom / 2.0
	position.x = clampf(position.x, half.x, MAP_W - half.x)
	position.y = clampf(position.y, half.y, MAP_H - half.y)
