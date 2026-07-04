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
	if OS.get_environment("SFX_TEST") == "1":
		_ability_sfx_selftest()


## 技能专属音自检（SFX_TEST=1）：跨主题/类型合成样例，验证可生成、响度归一、同主题不同 id 波形确实有别。
func _ability_sfx_selftest() -> void:
	var demos := [
		["t_fire_a", "fire", "smite"], ["t_fire_b", "fire", "smite"], ["t_fire_c", "fire", "fire_dot"],
		["t_ice", "ice", "bolt"], ["t_thunder", "thunder", "chain_nuke"], ["t_water", "water", "hook"],
		["t_poison", "poison", "debuff"], ["t_shadow", "shadow", "hex"], ["t_holy", "holy", "heal_wave"],
		["t_stone", "stone", "smite"], ["t_blade", "blade", "blink"], ["t_beast", "beast", "transform"],
		["t_chain", "chain", "pull"], ["t_cmd", "command", "rally"], ["t_fallback", "", "charge"],
	]
	var sigs := {}
	for d in demos:
		var b := _build_ability(String(d[0]), String(d[1]), String(d[2]))
		var peak := 0.0
		var energy := 0.0
		for v in b:
			peak = maxf(peak, absf(v))
			energy += absf(v)
		sigs[d[0]] = "%d_%d" % [b.size(), int(energy)]
		print("[sfx] %s theme=%s kind=%s len=%.2fs peak=%.2f" % [d[0], d[1], d[2], float(b.size()) / RATE, peak])
	var distinct: bool = sigs["t_fire_a"] != sigs["t_fire_b"]   # 同主题同类型、不同 id → 波形必须有别
	print("[sfx] ability_selftest OK: samples=%d fire_a_vs_b_distinct=%s" % [demos.size(), str(distinct)])


## 技能专属音：按技能 id 播种合成（同主题不同技能音高/层次/节奏皆异），懒生成缓存。
## theme 取 DotaVisuals 写入的视觉主题（fire/ice/...），缺省按 kind 推断；kind 叠加施法类型动机（弹道/光环/位移…）。
func play_ability(aid: String, theme: String, kind: String, vol_db := 0.0) -> void:
	if not enabled:
		return
	var key := "ab_" + aid
	if not _bank.has(key):
		_bank[key] = _wav(_build_ability(aid, theme, kind))
	play(key, vol_db, 0.03, 70)


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


## ---------- 技能专属音合成 ----------
## 设计：hash(aid) 播种 → 同一技能每次听到同一签名音、不同技能必然有别。
## 主题模板给「材质」（火的呼啸噼啪 / 冰的清脆闪烁 / 雷的炸裂…），kind 动机给「动作」（弹道起飞 / 光环升腾 / 位移嗖离…）。

## 频率滑音：f0→f1 线性滑，相位积分（无断裂）
func _glide(f0: float, f1: float, dur: float, vol: float, decay := 6.0, wave := "sine") -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in range(n):
		var t := float(i) / RATE
		ph += lerpf(f0, f1, t / dur) / RATE
		var s: float
		match wave:
			"square": s = 1.0 if sin(ph * TAU) >= 0.0 else -1.0
			"saw": s = fmod(ph, 1.0) * 2.0 - 1.0
			"tri": s = absf(fmod(ph, 1.0) * 4.0 - 2.0) - 1.0
			_: s = sin(ph * TAU)
		out[i] = s * minf(1.0, t / 0.004) * exp(-decay * t) * vol
	return out


## 噼啪/滴答/叮当：span 秒内撒 count 个短促爆点；tone_f>0 用音头（水滴/链环），否则纯噪（火星）
func _pops(rng: RandomNumberGenerator, count: int, span: float, vol: float, tone_f := 0.0, decay := 55.0) -> PackedFloat32Array:
	var n := int(span * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for _k in range(count):
		var s0 := int(rng.randf_range(0.0, span * 0.85) * RATE)
		var f := tone_f * rng.randf_range(0.8, 1.25)
		var ns := int(0.05 * RATE)
		for i in range(ns):
			var idx := s0 + i
			if idx >= n:
				break
			var t := float(i) / RATE
			var s := sin(TAU * f * t) if tone_f > 0.0 else rng.randf_range(-1.0, 1.0)
			out[idx] += s * exp(-decay * t) * vol
	return out


## 和音：几个频率同时鸣响（钟磬/号角）
func _chord(freqs: Array, dur: float, vol: float, decay := 5.0, wave := "sine") -> PackedFloat32Array:
	var out := _silence(dur)
	for f in freqs:
		out = _mix(out, _tone(float(f), dur, vol / float(freqs.size()) * 1.6, decay, wave))
	return out


## 峰值归一：过响压回、过弱抬升到目标峰值（各技能响度一致，不会有的震耳有的听不见）
func _norm(buf: PackedFloat32Array, target := 0.55) -> PackedFloat32Array:
	var peak := 0.0
	for v in buf:
		peak = maxf(peak, absf(v))
	if peak < 0.01:
		return buf
	var g := target / peak
	for i in range(buf.size()):
		buf[i] *= g
	return buf


## kind → 主题兜底（无 DotaVisuals 主题的技能：自定义关卡/内容包/旧 kit）
const _KIND_THEME := {
	"fire_dot": "fire", "fire_line": "fire", "fire_trail": "fire", "black_rain": "fire",
	"ice_wall": "ice", "chrono": "ice", "heal_wave": "holy", "shield": "holy",
	"hook": "chain", "pull": "chain", "drag": "chain", "ensnare": "chain",
	"rally": "command", "haste": "command", "summon": "beast", "transform": "beast",
	"hex": "shadow", "silence": "shadow", "invis": "shadow", "debuff": "shadow",
}

func _build_ability(aid: String, theme: String, kind: String) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(aid)
	var pv := rng.randf_range(0.82, 1.22)   # 个体音高体质：同主题技能彼此拉开
	if theme == "":
		theme = String(_KIND_THEME.get(kind, ""))
	var body: PackedFloat32Array
	match theme:
		"fire":
			body = _mix(_noise(rng.randf_range(0.18, 0.3), 0.16, rng.randf_range(5.0, 8.5)),
				_glide(190.0 * pv, 85.0 * pv, 0.24, 0.15, 6.0, "saw"))
			body = _mix(body, _pops(rng, rng.randi_range(3, 7), 0.3, 0.14))   # 火星噼啪
		"ice":
			body = _mix(_glide(760.0 * pv, 1500.0 * pv, rng.randf_range(0.12, 0.2), 0.11, 8.0, "sine"),
				_pops(rng, rng.randi_range(3, 6), 0.26, 0.10, 1900.0 * pv, 40.0))   # 冰晶叮铃
		"thunder":
			body = _mix(_noise(0.05, 0.30, 42.0), _glide(320.0 * pv, 62.0 * pv, rng.randf_range(0.28, 0.4), 0.22, 4.5, "saw"))
			body = _mix(body, _pops(rng, 2, 0.12, 0.16))   # 炸裂枝杈
		"water":
			body = _mix(_glide(520.0 * pv, 260.0 * pv, rng.randf_range(0.2, 0.3), 0.13, 5.0, "sine"),
				_noise(0.22, 0.11, 7.0))
			body = _mix(body, _pops(rng, rng.randi_range(2, 5), 0.28, 0.09, 620.0 * pv, 30.0))   # 水珠
		"poison":
			body = _mix(_pops(rng, rng.randi_range(5, 9), rng.randf_range(0.24, 0.34), 0.13, 260.0 * pv, 22.0),
				_noise(0.26, 0.09, 6.0))   # 咕嘟冒泡 + 毒雾嘶嘶
		"shadow":
			body = _mix(_glide(240.0 * pv, 108.0 * pv, rng.randf_range(0.3, 0.42), 0.15, 3.6, "saw"),
				_glide(247.0 * pv, 111.0 * pv, 0.34, 0.10, 3.6, "saw"))   # 双saw微失谐·阴冷
		"holy":
			body = _chord([523.0 * pv, 659.0 * pv, 784.0 * pv], rng.randf_range(0.3, 0.42), 0.12, rng.randf_range(4.0, 6.0))
			body = _mix(body, _noise(0.12, 0.05, 12.0))   # 圣钟 + 微光气息
		"stone", "hammer":
			body = _mix(_tone(88.0 * pv, 0.18, 0.30, 9.0), _noise(0.09, 0.24, 16.0))
			body = _mix(body, _pops(rng, rng.randi_range(2, 5), 0.22, 0.10))   # 落石碎屑
		"axe", "blade":
			body = _mix(_tone(rng.randf_range(700.0, 950.0) * pv, 0.05, 0.17, 32.0, "tri"), _noise(0.05, 0.15, 34.0))
			body = _mix(body, _tone(1300.0 * pv, 0.09, 0.07, 22.0, "sine"))   # 刃鸣余韵
		"spear":
			body = _mix(_noise(rng.randf_range(0.06, 0.1), 0.16, 22.0), _glide(420.0 * pv, 210.0 * pv, 0.1, 0.12, 18.0, "tri"))
		"arrow":
			body = _seq([_tone(rng.randf_range(480.0, 620.0) * pv, 0.025, 0.16, 22.0, "tri"), _noise(0.08, 0.12, 14.0)])   # 崩弦+破空
		"beast":
			body = _mix(_glide(170.0 * pv, 84.0 * pv, rng.randf_range(0.24, 0.36), 0.20, 4.0, "saw"), _noise(0.16, 0.10, 8.0))   # 低吼+鼻息
		"chain":
			body = _mix(_pops(rng, rng.randi_range(4, 7), rng.randf_range(0.18, 0.28), 0.15, 1050.0 * pv, 32.0), _noise(0.1, 0.08, 18.0))   # 铁环铮铮
		"command":
			body = _mix(_glide(233.0 * pv, 349.0 * pv, rng.randf_range(0.24, 0.34), 0.15, 3.2, "tri"), _tone(98.0, 0.16, 0.18, 8.0))   # 号角+鼓
		_:
			body = _mix(_noise(0.16, 0.16, 9.0), _glide(500.0 * pv, 300.0 * pv, 0.16, 0.12, 8.0, "tri"))   # 通用施法
	# —— kind 动机叠加：给「动作感」——
	match kind:
		"bolt", "line_nuke", "chain_nuke", "global_nuke", "blink_shot":
			body = _seq([_glide(360.0 * pv, 880.0 * pv, 0.1, 0.12, 10.0, "tri"), body])   # 起飞嗖
		"charge", "blink", "path", "swap":
			body = _mix(body, _glide(1250.0 * pv, 460.0 * pv, 0.14, 0.10, 9.0, "sine"))   # 疾离
		"rally", "haste", "shield", "self_buff", "atkspeed", "heal_wave", "ward":
			body = _mix(body, _seq([_tone(330.0 * pv, 0.07, 0.08, 8.0, "tri"), _tone(440.0 * pv, 0.07, 0.08, 8.0, "tri"), _tone(587.0 * pv, 0.1, 0.09, 7.0, "tri")]))   # 升腾三连
		"debuff", "hex", "silence", "disarm", "ensnare":
			body = _mix(body, _seq([_tone(392.0 * pv, 0.08, 0.08, 7.0, "saw"), _tone(311.0 * pv, 0.09, 0.08, 7.0, "saw"), _tone(233.0 * pv, 0.12, 0.08, 6.0, "saw")]))   # 沉降三连
		"summon", "transform", "invis":
			body = _mix(body, _glide(220.0 * pv, 640.0 * pv, 0.3, 0.09, 3.0, "sine"))   # 现形/化形涌起
		"hook", "pull", "drag":
			body = _seq([body, _tone(140.0 * pv, 0.1, 0.16, 12.0)])   # 拽定闷响
	return _norm(body)
