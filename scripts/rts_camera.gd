class_name RTSCamera
extends Camera2D
## RTS 视角：方向键/屏幕边缘平移、中键拖拽、触控板双指平移；
## 鼠标滚轮或触控板捏合缩放。（字母键留给指令：A=攻击移动）

const EDGE := 30.0          # 边缘滚屏触发像素
const PANEL_H := 158.0      # 底部面板高度：此区域不触发向下边缘滚屏

var pan_speed := 750.0
var _mid_drag := false
var _shake := 0.0          # 当前屏震强度（像素），逐帧衰减
var _shake_ph := 0.0       # 抖动相位
# 触摸：双指捏合缩放 / 双指平移
var touch_mode := false
var _touches := {}         # index -> 当前位置
var _pinch_d := 0.0        # 上一帧双指间距
var _pinch_mid := Vector2.ZERO


func _ready() -> void:
	make_current()
	zoom = Vector2(1.1, 1.1)


## 叠加屏震（取较大值，封顶防过激）。暴击/施法/大单位阵亡时触发。
func add_shake(amount: float) -> void:
	_shake = minf(maxf(_shake, amount), 9.0)


func _process(delta: float) -> void:
	# 屏震：用 offset 抖动（不污染 position/边缘滚屏逻辑），强度指数衰减
	if _shake > 0.01:
		_shake_ph += delta * 34.0
		var amp := _shake / zoom.x
		offset = Vector2(sin(_shake_ph * 1.0), cos(_shake_ph * 1.7)) * amp
		_shake = maxf(0.0, _shake - delta * (_shake * 5.0 + 6.0))
	elif offset != Vector2.ZERO:
		offset = Vector2.ZERO
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		v.y += 1.0
	if Input.is_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		v.x += 1.0
	# 边缘滚屏：只要窗口有焦点就判定，不要求指针留在窗口内——指针顶到/越出某条边后，
	# 视口坐标会停在那条边上，于是继续朝该方向滚（即「光标移出操作区域后仍持续滚动」）。
	# 向下有两处触发：① 命令面板顶上那一条；② 整个窗口最底边（把光标怼到底/越出底部即向下滚）。
	# 中间那段（面板主体）不触发，免得点命令卡时镜头乱飘。
	var vp := get_viewport()
	var mp := vp.get_mouse_position()
	var vs := vp.get_visible_rect().size
	var play_bottom := vs.y - PANEL_H
	if get_window().has_focus() and not touch_mode and Settings.edge_scroll:   # 触摸屏没有「悬停」，关掉边缘滚屏免得乱飘
		if mp.x < EDGE:
			v.x -= 1.0
		elif mp.x > vs.x - EDGE:
			v.x += 1.0
		if mp.y < EDGE:
			v.y -= 1.0
		elif (mp.y > play_bottom - EDGE and mp.y <= play_bottom) or mp.y >= vs.y - EDGE:
			v.y += 1.0
	if v != Vector2.ZERO:
		position += v.normalized() * pan_speed * Settings.cam_speed * delta / zoom.x
	# 键盘缩放兜底（+ / -），始终可用，不依赖鼠标或触控板
	if Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_KP_ADD):
		_zoom_by(1.0 + 1.6 * delta * Settings.zoom_sens)
	if Input.is_key_pressed(KEY_MINUS) or Input.is_key_pressed(KEY_KP_SUBTRACT):
		_zoom_by(1.0 - 1.6 * delta * Settings.zoom_sens)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_by(1.0 + 0.12 * Settings.zoom_sens)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_by(1.0 / (1.0 + 0.12 * Settings.zoom_sens))
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_mid_drag = event.pressed
	elif event is InputEventMouseMotion and _mid_drag:
		position -= event.relative / zoom.x
	elif event is InputEventMagnifyGesture:
		# 触控板捏合缩放（macOS）：factor > 1 放大
		_zoom_by(event.factor)
	elif event is InputEventPanGesture:
		# 触控板双指平移（macOS）
		position += event.delta * 26.0 / zoom.x
	elif event is InputEventScreenTouch:
		touch_mode = true
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		if _touches.size() < 2:
			_pinch_d = 0.0
			_pinch_mid = Vector2.ZERO
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			# 双指：捏合缩放 + 平移（取前两指）
			var ks := _touches.keys()
			var a: Vector2 = _touches[ks[0]]
			var b: Vector2 = _touches[ks[1]]
			var d := a.distance_to(b)
			var mid := (a + b) * 0.5
			if _pinch_d > 0.0 and d > 0.0:
				_zoom_by(d / _pinch_d)
				if _pinch_mid != Vector2.ZERO:
					position -= (mid - _pinch_mid) / zoom.x
			_pinch_d = d
			_pinch_mid = mid


func _zoom_by(f: float) -> void:
	zoom = Vector2.ONE * clampf(zoom.x * f, 0.5, 3.2)
