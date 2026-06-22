extends Node
## 合成式音效（Autoload: Sfx）。运行时用 AudioStreamWAV 程序化生成各音色，
## 无需任何音频素材。play(name) 播放，自带节流避免多单位刷屏。

const RATE := 22050
const POOL := 10
const GUARD := 64   # 重采样越界读护卫帧（见 music.gd 同名说明）：WAV 尾部补静音，避免读到未映射页硬崩

var _bank := {}                 # name -> AudioStreamWAV
var _players: Array = []
var _next := 0
var _last := {}                 # name -> 上次播放 ticks（节流）
var enabled := true
var user_vol := 1.0    # 设置·音效音量（0..1，不依赖音频总线）


func _ready() -> void:
	_build_bank()
	for i in range(POOL):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)


## 播放：vol_db 增益，pitch 轻微随机，min_gap_ms 节流（同名）
func play(name: String, vol_db := 0.0, pitch_var := 0.06, min_gap_ms := 55) -> void:
	if not enabled or not _bank.has(name):
		return
	var now := Time.get_ticks_msec()
	if _last.get(name, -9999) + min_gap_ms > now:
		return
	_last[name] = now
	var pl: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	pl.stream = _bank[name]
	pl.volume_db = vol_db + (linear_to_db(clampf(user_vol, 0.0, 1.0)) if user_vol > 0.004 else -80.0)
	pl.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	pl.play()


## ---------- 合成 ----------

func _build_bank() -> void:
	_bank["select"] = _wav(_tone(560.0, 0.07, 0.22, 16.0, "tri"))
	_bank["order"] = _wav(_tone(720.0, 0.05, 0.20, 24.0, "tri"))
	_bank["click"] = _wav(_tone(900.0, 0.03, 0.18, 34.0, "square"))
	_bank["build"] = _wav(_noise(0.06, 0.30, 26.0))
	_bank["complete"] = _wav(_seq([_tone(523.0, 0.12, 0.24, 7.0), _tone(784.0, 0.18, 0.24, 6.0)]))
	_bank["levelup"] = _wav(_seq([
		_tone(523.0, 0.08, 0.22, 9.0), _tone(659.0, 0.08, 0.22, 9.0),
		_tone(784.0, 0.08, 0.22, 9.0), _tone(1046.0, 0.20, 0.24, 6.0)]))
	_bank["alert"] = _wav(_seq([_tone(880.0, 0.10, 0.26, 10.0, "square"), _silence(0.06), _tone(880.0, 0.12, 0.26, 9.0, "square")]))
	_bank["cant"] = _wav(_tone(150.0, 0.14, 0.24, 5.0, "saw"))
	_bank["hit"] = _wav(_mix(_noise(0.05, 0.28, 30.0), _tone(180.0, 0.05, 0.18, 26.0)))
	_bank["arrow"] = _wav(_noise(0.07, 0.18, 16.0))
	_bank["cast"] = _wav(_noise(0.20, 0.22, 6.0))
	_bank["death"] = _wav(_mix(_tone(120.0, 0.22, 0.26, 8.0), _noise(0.10, 0.18, 16.0)))
	_bank["build_done"] = _bank["complete"]
	# —— 按武器类型区分的攻击音 —— （unit._attack_sfx_name 选取）
	_bank["atk_sword"]    = _wav(_mix(_tone(820.0, 0.05, 0.18, 34.0, "tri"), _noise(0.035, 0.13, 44.0)))   # 利刃·铮
	_bank["atk_spear"]    = _wav(_mix(_noise(0.06, 0.15, 26.0), _tone(330.0, 0.045, 0.14, 30.0)))           # 长枪·破风刺
	_bank["atk_axe"]      = _wav(_mix(_tone(150.0, 0.10, 0.26, 13.0), _noise(0.06, 0.22, 24.0)))            # 大斧·闷劈
	_bank["atk_bow"]      = _wav(_mix(_seq([_tone(540.0, 0.02, 0.18, 20.0, "tri"), _tone(320.0, 0.05, 0.15, 24.0, "tri")]), _noise(0.025, 0.07, 40.0)))  # 弓·崩弦
	_bank["atk_crossbow"] = _wav(_mix(_tone(240.0, 0.04, 0.16, 30.0, "square"), _noise(0.025, 0.17, 55.0))) # 弩·机括
	_bank["atk_mace"]     = _wav(_mix(_tone(190.0, 0.12, 0.28, 10.0), _tone(380.0, 0.07, 0.15, 16.0)))      # 双鞭·金铁
	_bank["atk_fist"]     = _wav(_mix(_tone(120.0, 0.06, 0.24, 22.0), _noise(0.035, 0.12, 46.0)))           # 拳·闷击
	_bank["atk_staff"]    = _wav(_mix(_tone(260.0, 0.05, 0.20, 28.0, "tri"), _noise(0.03, 0.10, 42.0)))     # 禅杖/棍·木响
	_bank["atk_catapult"] = _wav(_mix(_tone(95.0, 0.18, 0.30, 8.0, "saw"), _noise(0.09, 0.18, 13.0)))       # 投石·发射轰
	# —— 按技能种类区分的施法音 —— （battle._ability_sfx 选取）
	_bank["sk_smite"]  = _wav(_mix(_tone(520.0, 0.06, 0.20, 18.0, "tri"), _noise(0.05, 0.16, 22.0)))        # 落雷/打击
	_bank["sk_thrust"] = _wav(_mix(_noise(0.10, 0.18, 13.0), _tone(180.0, 0.10, 0.18, 14.0, "saw")))        # 枪波推进
	_bank["sk_sweep"]  = _wav(_mix(_noise(0.14, 0.16, 9.0), _tone(440.0, 0.08, 0.12, 16.0, "tri")))         # 横扫
	_bank["sk_chrono"] = _wav(_mix(_seq([_tone(700.0, 0.07, 0.16, 3.0, "tri"), _tone(560.0, 0.07, 0.16, 3.0, "tri"), _tone(440.0, 0.08, 0.16, 3.0, "tri"), _tone(330.0, 0.16, 0.18, 2.0, "tri")]), _tone(110.0, 0.42, 0.12, 1.6, "saw")))  # 时停·降频
	_bank["sk_blink"]  = _wav(_mix(_seq([_tone(900.0, 0.03, 0.16, 18.0, "square"), _tone(1300.0, 0.03, 0.14, 18.0, "square")]), _noise(0.05, 0.12, 30.0)))  # 闪烁·电吟
	_bank["sk_rain"]   = _wav(_mix(_noise(0.26, 0.15, 5.0), _seq([_tone(820.0, 0.05, 0.10, 10.0), _tone(640.0, 0.05, 0.10, 10.0), _tone(520.0, 0.06, 0.10, 10.0)])))  # 箭雨·簌簌
	_bank["sk_axes"]   = _wav(_seq([_noise(0.05, 0.14, 18.0), _silence(0.025), _noise(0.05, 0.14, 18.0), _silence(0.025), _noise(0.05, 0.14, 18.0)]))  # 双斧旋
	_bank["sk_charge"] = _wav(_mix(_tone(160.0, 0.22, 0.20, 5.0, "saw"), _noise(0.14, 0.16, 8.0)))          # 冲锋·疾走
	_bank["sk_fury"]   = _wav(_mix(_tone(130.0, 0.30, 0.24, 3.0, "saw"), _noise(0.18, 0.14, 6.0)))          # 狂暴·怒吼
	_bank["sk_rally"]  = _wav(_mix(_seq([_tone(330.0, 0.12, 0.20, 6.0), _tone(247.0, 0.18, 0.20, 5.0)]), _noise(0.06, 0.16, 16.0)))  # 鼓舞·号角战鼓
	_bank["sk_haste"]  = _wav(_seq([_tone(440.0, 0.06, 0.16, 8.0, "tri"), _tone(587.0, 0.06, 0.16, 8.0, "tri"), _tone(784.0, 0.10, 0.18, 7.0, "tri")]))  # 疾行·上行
	_bank["sk_debuff"] = _wav(_seq([_tone(330.0, 0.08, 0.18, 6.0, "saw"), _tone(262.0, 0.10, 0.18, 6.0, "saw"), _tone(196.0, 0.14, 0.18, 5.0, "saw")]))  # 削弱·下行
	_bank["sk_drag"]   = _wav(_mix(_noise(0.12, 0.16, 10.0), _tone(220.0, 0.12, 0.16, 8.0, "saw")))         # 拖拽·猛拽
	_bank["sk_fire"]   = _wav(_mix(_noise(0.22, 0.16, 7.0), _tone(160.0, 0.16, 0.14, 9.0, "saw")))          # 火·呼啸
	_bank["sk_swap"]   = _wav(_mix(_tone(700.0, 0.05, 0.18, 24.0, "tri"), _tone(950.0, 0.04, 0.14, 28.0, "tri")))  # 切换·拔刀


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var n := samples.size()
	var data := PackedByteArray()
	data.resize((n + GUARD) * 2)   # 末尾 GUARD 帧留 0（静音垫）：重采样越界读不再命中未映射页
	for i in range(n):
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


func _tone(freq: float, dur: float, vol: float, decay := 6.0, wave := "sine") -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var t := float(i) / RATE
		var ph := freq * t
		var s: float
		match wave:
			"square": s = 1.0 if sin(ph * TAU) >= 0.0 else -1.0
			"saw": s = fmod(ph, 1.0) * 2.0 - 1.0
			"tri": s = absf(fmod(ph, 1.0) * 4.0 - 2.0) - 1.0
			_: s = sin(ph * TAU)
		var atk := minf(1.0, t / 0.004)          # 4ms 起音，去爆音
		out[i] = s * exp(-decay * t) * atk * vol
	return out


func _noise(dur: float, vol: float, decay := 10.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var t := float(i) / RATE
		out[i] = randf_range(-1.0, 1.0) * exp(-decay * t) * vol
	return out


func _silence(dur: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(dur * RATE))
	return out


func _seq(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in parts:
		out.append_array(p)
	return out


func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var n := maxi(a.size(), b.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var v := 0.0
		if i < a.size():
			v += a[i]
		if i < b.size():
			v += b[i]
		out[i] = clampf(v, -1.0, 1.0)
	return out
