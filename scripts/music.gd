extends Node
## 程序合成背景音乐（Autoload: Music）。无需任何音频素材：
## 每种情绪（calm 经营 / battle 战斗）各合成 4 首风格迥异的曲子，随机轮播（不连续重复同一首）；
## 旋律按随机游走生成——每次启动听到的都是新曲。两个常驻播放器按情绪交叉淡入淡出（set_mood）。
## 五声音阶（宫商角徵羽），合中式古风。除首曲外其余曲目在后台线程合成，不拖慢启动。

const RATE := 22050
const BASE_DB := -15.0       # 音乐整体增益（压低，绝不盖过音效）
const FADE := 1.6            # 情绪交叉淡变时长（秒）
const GAP := 1.4             # 曲间静默（秒）：一曲终了稍作停顿再起下一首
const STYLES := 4            # 每种情绪的曲目数

# 五声音阶频率（C 宫）：低八度根音 + 旋律音
const ROOT := [130.81, 146.83, 164.81, 196.00, 220.00]            # C3 D3 E3 G3 A3
const MEL := [261.63, 293.66, 329.63, 392.00, 440.00, 523.25]     # C4 D4 E4 G4 A4 C5
const BASS := [65.41, 73.42, 82.41, 98.00]                        # C2 D2 E2 G2

var enabled := true
var user_vol := 1.0    # 设置·背景音乐音量（0..1，不依赖音频总线）
var _p_calm: AudioStreamPlayer
var _p_battle: AudioStreamPlayer
var _mood := "calm"
var _tc := 1.0    # calm 目标音量(0..1)
var _tb := 0.0    # battle 目标音量
var _vc := 0.0    # calm 当前音量
var _vb := 0.0    # battle 当前音量
var _tracks := {"calm": [], "battle": []}   # 情绪 -> Array[AudioStreamWAV]（随线程合成逐渐补齐）
var _last_idx := {"calm": -1, "battle": -1} # 上一首索引（避免连续重复）
var _gap := {"calm": 0.0, "battle": 0.0}    # 曲间停顿计时
var _thr: Thread = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # 暂停时音乐继续
	if OS.get_environment("MUSIC_TEST") == "1":
		# 测试：全部同步合成并打印统计（长度/峰值/削波）
		for s in range(STYLES):
			var cb := _build_calm_style(s, _mk_rng())
			var bb := _build_battle_style(s, _mk_rng())
			_dump("calm%d" % s, cb)
			_dump("battle%d" % s, bb)
			_add_track("calm", cb)
			_add_track("battle", bb)
	else:
		# 首曲同步合成（进菜单即有乐），其余 6 首后台线程慢慢补
		_add_track("calm", _build_calm_style(0, _mk_rng()))
		_add_track("battle", _build_battle_style(0, _mk_rng()))
		_thr = Thread.new()
		_thr.start(_bg_build)
	_p_calm = _mk_player()
	_p_battle = _mk_player()
	_play_next("calm")
	_play_next("battle")
	set_mood("calm", true)


func _exit_tree() -> void:
	if _thr != null and _thr.is_started():
		_thr.wait_to_finish()


## 后台合成其余曲目：每首用独立 RNG，结果经 call_deferred 回主线程入库（PackedFloat32Array 跨线程按值拷贝，安全）
func _bg_build() -> void:
	for s in range(1, STYLES):
		var cb := _build_calm_style(s, _mk_rng())
		call_deferred("_add_track_buf", "calm", cb)
		var bb := _build_battle_style(s, _mk_rng())
		call_deferred("_add_track_buf", "battle", bb)


func _add_track_buf(mood_key: String, buf: PackedFloat32Array) -> void:
	_add_track(mood_key, buf)


func _add_track(mood_key: String, buf: PackedFloat32Array) -> void:
	_seam_fade(buf)
	_tracks[mood_key].append(_wav(buf))


func _mk_rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.randomize()   # 每次启动旋律都不同
	return r


func _dump(name: String, b: PackedFloat32Array) -> void:
	var peak := 0.0
	var clip := 0
	for v in b:
		peak = maxf(peak, absf(v))
		if absf(v) > 1.0:
			clip += 1
	print("[music] %s len=%.1fs peak=%.2f clip=%d" % [name, float(b.size()) / RATE, peak, clip])


func _mk_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Master"
	p.volume_db = -70.0
	add_child(p)
	return p


## 轮播：从该情绪曲库随机挑下一首（多于 1 首时避开上一首），装载播放
func _play_next(mood_key: String) -> void:
	var arr: Array = _tracks[mood_key]
	if arr.is_empty():
		return
	var idx := 0
	if arr.size() > 1:
		idx = randi() % arr.size()
		while idx == int(_last_idx[mood_key]):
			idx = randi() % arr.size()
	_last_idx[mood_key] = idx
	var p := _p_calm if mood_key == "calm" else _p_battle
	if p == null:
		return
	p.stream = arr[idx]
	p.play()


func _process(delta: float) -> void:
	var step := delta / FADE
	_vc = move_toward(_vc, _tc if enabled else 0.0, step)
	_vb = move_toward(_vb, _tb if enabled else 0.0, step)
	_apply()
	_tick_playlist("calm", _p_calm, delta)
	_tick_playlist("battle", _p_battle, delta)


## 一曲放完 → 停顿 GAP 秒 → 随机下一首（两情绪各自独立轮播；被淡出静音的那路也照常轮，切回时正在新曲）
func _tick_playlist(mood_key: String, p: AudioStreamPlayer, delta: float) -> void:
	if p == null or p.playing or _tracks[mood_key].is_empty():
		return
	_gap[mood_key] = float(_gap[mood_key]) + delta
	if float(_gap[mood_key]) >= GAP:
		_gap[mood_key] = 0.0
		_play_next(mood_key)


func _apply() -> void:
	if _p_calm != null:
		_p_calm.volume_db = _vol_db(_vc)
	if _p_battle != null:
		_p_battle.volume_db = _vol_db(_vb)


func _vol_db(v: float) -> float:
	if v <= 0.004 or user_vol <= 0.004:
		return -70.0
	return BASE_DB + linear_to_db(clampf(v, 0.0, 1.0)) + linear_to_db(clampf(user_vol, 0.0, 1.0))


## 设置·背景音乐音量（0..1），即调即生效。
func set_user_vol(v: float) -> void:
	user_vol = v
	_apply()


## 切换情绪："calm" / "battle"。instant=立即生效（无淡变，开局/回菜单用）
func set_mood(m: String, instant := false) -> void:
	if m != "calm" and m != "battle":
		return
	_mood = m
	_tc = 1.0 if m == "calm" else 0.0
	_tb = 1.0 if m == "battle" else 0.0
	if instant:
		_vc = _tc if enabled else 0.0
		_vb = _tb if enabled else 0.0
		_apply()


func mood() -> String:
	return _mood


func set_enabled(on: bool) -> void:
	enabled = on


## ---------- 合成 ----------

## 曲首曲尾淡变：首 4ms 淡入、尾 60ms 淡出 → 起止无「咔哒」爆音（非循环曲，尾巴略长更自然）
func _seam_fade(buf: PackedFloat32Array) -> void:
	var n := buf.size()
	var hf := int(0.004 * RATE)
	var tf := int(0.06 * RATE)
	for i in range(hf):
		buf[i] *= float(i) / float(hf)
	for i in range(tf):
		buf[n - 1 - i] *= float(i) / float(tf)


## 护卫帧 GUARD：重采样器在流末尾会多读 1~N 帧。尾部补零作安全垫，避免越界读命中未映射页硬崩（安卓）。
const GUARD := 64

func _wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var n := buf.size()
	var data := PackedByteArray()
	data.resize((n + GUARD) * 2)
	for i in range(n):
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w   # 不循环：播完由轮播器随机接下一首


## 往缓冲叠加一个音符（加法合成）。
func _add_note(buf: PackedFloat32Array, freq: float, start: float, dur: float, vol: float,
		wave := "sine", decay := 2.5, atk_s := 0.012) -> void:
	var n := buf.size()
	var s0 := int(start * RATE)
	var ns := int(dur * RATE)
	for i in range(ns):
		var idx := s0 + i
		if idx < 0 or idx >= n:
			continue
		var t := float(i) / RATE
		var ph := freq * t
		var s: float
		match wave:
			"tri": s = absf(fmod(ph, 1.0) * 4.0 - 2.0) - 1.0
			"saw": s = fmod(ph, 1.0) * 2.0 - 1.0
			_: s = sin(ph * TAU)
		var env := minf(1.0, t / atk_s) * exp(-decay * t)
		buf[idx] += s * env * vol


## 竹笛：正弦 + 揉音（5.5Hz 颤音）+ 气息起音，悠长
func _add_flute(buf: PackedFloat32Array, freq: float, start: float, dur: float, vol: float) -> void:
	var n := buf.size()
	var s0 := int(start * RATE)
	var ns := int(dur * RATE)
	for i in range(ns):
		var idx := s0 + i
		if idx < 0 or idx >= n:
			continue
		var t := float(i) / RATE
		var vib := 1.0 + 0.006 * sin(TAU * 5.5 * t) * minf(1.0, t / 0.3)   # 起音后渐入揉音
		var s := sin(TAU * freq * vib * t) + 0.18 * sin(TAU * freq * 2.0 * vib * t)
		var env := minf(1.0, t / 0.06) * exp(-1.1 * t) * clampf((dur - t) * 8.0, 0.0, 1.0)   # 气息起音+尾音收束
		buf[idx] += s * env * vol


## 战鼓：低频「咚」+ 噪声攻击（rng 供噪声，线程安全）
func _add_drum(buf: PackedFloat32Array, start: float, vol: float, rng: RandomNumberGenerator, pitch := 92.0) -> void:
	var n := buf.size()
	var s0 := int(start * RATE)
	var ns := int(0.32 * RATE)
	for i in range(ns):
		var idx := s0 + i
		if idx < 0 or idx >= n:
			continue
		var t := float(i) / RATE
		var body := sin((pitch * (1.0 - t * 1.2)) * t * TAU)   # 下滑音高，鼓腔感
		var click := rng.randf_range(-1.0, 1.0) * exp(-60.0 * t) * 0.5
		buf[idx] += (body * exp(-9.0 * t) + click) * vol


## 木鱼/梆子：短促高频「哒」
func _add_tick(buf: PackedFloat32Array, start: float, vol: float, pitch := 1250.0) -> void:
	_add_note(buf, pitch, start, 0.05, vol, "tri", 45.0, 0.002)


func _silent(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b


## 随机游走旋律：五声音阶内小步移动，乐句尾落宫/徵（听感有「归宿」）
func _walk_mel(rng: RandomNumberGenerator, count: int, phrase := 8) -> Array:
	var seq: Array = []
	var idx := 2
	for i in range(count):
		if (i + 1) % phrase == 0:
			idx = 0 if rng.randf() < 0.6 else 3   # 句尾归宫(C)或徵(G)
		else:
			idx = clampi(idx + rng.randi_range(-2, 2), 0, MEL.size() - 1)
		seq.append(idx)
	return seq


## ---------- 经营曲 4 式 ----------
## 0 山寨晨昏·古筝拨奏 | 1 芦苇泛舟·竹笛 | 2 夜泊水寨·羽调夜曲 | 3 溪涧练兵·轻快弹拨
func _build_calm_style(style: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	match style:
		1: return _calm_flute(rng)
		2: return _calm_night(rng)
		3: return _calm_brook(rng)
	return _calm_zheng(rng)


func _calm_zheng(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var loop := 16.0
	var buf := _silent(loop)
	var bass_seq := [0, 3, 1, 2, 0, 3]
	for k in range(bass_seq.size()):
		_add_note(buf, BASS[bass_seq[k]], k * 2.66, 2.5, 0.26, "sine", 0.7, 0.05)
		_add_note(buf, BASS[bass_seq[k]] * 1.5, k * 2.66 + 0.02, 2.3, 0.10, "sine", 0.8)
	var mel := _walk_mel(rng, 20)
	for k in range(mel.size()):
		var f: float = MEL[mel[k]]
		_add_note(buf, f, k * 0.75, 0.9, 0.15, "tri", 3.2)
		if k % 4 == 2:
			_add_note(buf, f * 2.0, k * 0.75 + 0.06, 0.5, 0.06, "sine", 4.0)
	return buf


func _calm_flute(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var loop := 18.0
	var buf := _silent(loop)
	var tr := 9.0 / 8.0   # D 转调
	var bass_seq := [0, 2, 3, 1, 0, 2]
	for k in range(bass_seq.size()):
		_add_note(buf, BASS[bass_seq[k]] * tr, k * 3.0, 2.9, 0.22, "sine", 0.6, 0.08)
	var mel := _walk_mel(rng, 12, 6)
	for k in range(mel.size()):
		var f: float = MEL[mel[k]] * tr
		_add_flute(buf, f, k * 1.4 + rng.randf_range(0.0, 0.08), 1.35, 0.13)
	# 偶尔一记古筝应和
	for k in range(5):
		var f2: float = MEL[_walk_mel(rng, 1)[0]] * tr
		_add_note(buf, f2 * 2.0, rng.randf_range(1.0, loop - 2.0), 0.7, 0.055, "tri", 4.0)
	return buf


func _calm_night(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var loop := 20.0
	var buf := _silent(loop)
	# 羽调（A 为根）：夜色沉静。低音长垫 + 稀疏拨奏 + 心跳般的远鼓
	var pads := [220.0 * 0.5, 261.63 * 0.5, 196.0 * 0.5, 220.0 * 0.5]   # A2 C3 G2 A2
	for k in range(pads.size()):
		_add_note(buf, pads[k], k * 5.0, 4.8, 0.20, "sine", 0.35, 0.4)
		_add_note(buf, pads[k] * 2.0, k * 5.0 + 0.05, 4.4, 0.06, "sine", 0.5, 0.5)
	var nmel := [4, 5, 3, 4, 2, 0, 1, 2, 4, 3]   # 围绕羽/宫低回
	for k in range(nmel.size()):
		if rng.randf() < 0.25:
			continue   # 留白：夜曲要疏
		_add_note(buf, MEL[nmel[k]], k * 1.9 + rng.randf_range(0.0, 0.3), 1.3, 0.10, "tri", 2.2)
	for k in range(5):
		_add_drum(buf, k * 4.0 + 1.2, 0.10, rng, 62.0)   # 远处更鼓
	return buf


func _calm_brook(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var loop := 14.0
	var buf := _silent(loop)
	var tr := 4.0 / 3.0   # F 转调，明快
	var bass_seq := [0, 3, 2, 3]
	for k in range(bass_seq.size()):
		_add_note(buf, BASS[bass_seq[k]] * tr, k * 3.5, 3.3, 0.22, "sine", 0.7, 0.06)
	var mel := _walk_mel(rng, 26, 6)
	for k in range(mel.size()):
		var f: float = MEL[mel[k]] * tr
		_add_note(buf, f, k * 0.5, 0.6, 0.13, "tri", 4.5)
		if rng.randf() < 0.2:   # 倚音点缀
			_add_note(buf, f * 1.5, k * 0.5 + 0.1, 0.3, 0.05, "sine", 6.0)
	for k in range(int(loop / 1.75)):
		_add_tick(buf, k * 1.75 + 0.9, 0.05)   # 轻梆子
	return buf


## ---------- 战斗曲 4 式 ----------
## 0 擂鼓迎敌·行进 | 1 急攻·风火 | 2 围城·沉重 | 3 马蹄·追击
func _build_battle_style(style: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	match style:
		1: return _battle_rush(rng)
		2: return _battle_siege(rng)
		3: return _battle_gallop(rng)
	return _battle_march(rng)


func _battle_march(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var loop := 12.0
	var buf := _silent(loop)
	var beats := int(loop / 0.5)
	for k in range(beats):
		var v := 0.5 if k % 4 == 0 else (0.34 if k % 2 == 0 else 0.22)
		_add_drum(buf, k * 0.5, v, rng, 96.0 if k % 4 == 0 else 88.0)
	var bass_pat := [0, 0, 3, 0, 2, 2, 3, 0]
	for k in range(beats):
		_add_note(buf, BASS[bass_pat[k % bass_pat.size()]], k * 0.5, 0.42, 0.20, "saw", 4.5)
	var mel := _walk_mel(rng, int(loop / 0.25), 8)
	for k in range(mel.size()):
		_add_note(buf, MEL[mel[k]], k * 0.25, 0.34, 0.13, "tri", 5.5)
	return buf


func _battle_rush(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var loop := 11.0
	var buf := _silent(loop)
	var tr := 9.0 / 8.0
	var step := 0.42
	var beats := int(loop / step)
	for k in range(beats):
		_add_drum(buf, k * step, 0.44 if k % 4 == 0 else 0.24, rng, 100.0)
		if k % 2 == 1:
			_add_note(buf, 5200.0, k * step + step * 0.5, 0.03, 0.05, "square", 70.0, 0.001)   # 急促镲点
	var bass_pat := [0, 2, 0, 3, 0, 2, 3, 3]
	for k in range(beats):
		_add_note(buf, BASS[bass_pat[k % bass_pat.size()]] * tr, k * step, step * 0.85, 0.20, "saw", 5.5)
	var mel := _walk_mel(rng, int(loop / (step * 0.5)), 8)
	for k in range(mel.size()):
		_add_note(buf, MEL[mel[k]] * tr, k * step * 0.5, step * 0.7, 0.12, "tri", 7.0)
	return buf


func _battle_siege(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var loop := 14.0
	var buf := _silent(loop)
	var step := 0.7
	var beats := int(loop / step)
	for k in range(beats):
		_add_drum(buf, k * step, 0.55 if k % 2 == 0 else 0.30, rng, 72.0)   # 沉重低鼓
		if k % 4 == 3:
			_add_drum(buf, k * step + step * 0.5, 0.26, rng, 58.0)          # 拖沓补拍
	for k in range(int(loop / 3.5)):
		_add_note(buf, BASS[0] * 0.5, k * 3.5, 3.4, 0.16, "saw", 0.6, 0.3)  # C1 长驱低鸣
	var dire := [2, 1, 0, 1, 2, 0, 1, 0]
	for k in range(dire.size()):
		if rng.randf() < 0.2:
			continue
		_add_note(buf, MEL[dire[k]] * 0.5, k * 1.7 + rng.randf_range(0.0, 0.2), 1.2, 0.13, "tri", 2.6)
	return buf


func _battle_gallop(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var loop := 12.0
	var buf := _silent(loop)
	var bar := 0.6   # 「哒-哒哒」马蹄一组
	var bars := int(loop / bar)
	for k in range(bars):
		_add_drum(buf, k * bar, 0.4, rng, 94.0)
		_add_drum(buf, k * bar + bar * 0.5, 0.22, rng, 86.0)
		_add_drum(buf, k * bar + bar * 0.72, 0.22, rng, 86.0)
	var bass_pat := [0, 0, 2, 3]
	for k in range(bars):
		_add_note(buf, BASS[bass_pat[k % bass_pat.size()]], k * bar, bar * 0.9, 0.18, "saw", 4.0)
	# 上行冲刺短句
	var mel := _walk_mel(rng, int(loop / 0.3), 10)
	for k in range(mel.size()):
		var up := mini(mel[k] + (k % 3), MEL.size() - 1)   # 每三音上冲
		_add_note(buf, MEL[up], k * 0.3, 0.28, 0.12, "tri", 6.5)
	return buf
