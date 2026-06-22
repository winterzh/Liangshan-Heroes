extends Node
## 程序合成循环背景音乐（Autoload: Music）。无需任何音频素材：
## 运行时合成两段「情绪」——calm(经营/安宁) 与 battle(战斗/紧张)——各为可无缝循环的
## AudioStreamWAV，用两个常驻播放器交叉淡入淡出（set_mood）。五声音阶（宫商角徵羽），合中式古风。

const RATE := 22050
const BASE_DB := -15.0       # 音乐整体增益（压低，绝不盖过音效）
const FADE := 1.6            # 情绪交叉淡变时长（秒）

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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # 暂停时音乐继续
	var cb := _build_calm()
	var bb := _build_battle()
	_seam_fade(cb)
	_seam_fade(bb)
	if OS.get_environment("MUSIC_TEST") == "1":
		_dump("calm", cb)
		_dump("battle", bb)
	_p_calm = _mk_player(_wav(cb))
	_p_battle = _mk_player(_wav(bb))
	set_mood("calm", true)


func _dump(name: String, b: PackedFloat32Array) -> void:
	var peak := 0.0
	var clip := 0
	for v in b:
		peak = maxf(peak, absf(v))
		if absf(v) > 1.0:
			clip += 1
	# 循环接缝跳变：首样本与末样本之差（越接近 0 越无缝，无爆音）
	var jump: float = absf(b[0] - b[b.size() - 1])
	print("[music] %s len=%.1fs peak=%.2f clip=%d seam_jump=%.4f" % [
		name, float(b.size()) / RATE, peak, clip, jump])


func _mk_player(stream: AudioStreamWAV) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = "Master"
	p.volume_db = -70.0
	add_child(p)
	p.play()
	return p


func _process(delta: float) -> void:
	var step := delta / FADE
	_vc = move_toward(_vc, _tc if enabled else 0.0, step)
	_vb = move_toward(_vb, _tb if enabled else 0.0, step)
	_apply()


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

## 循环接缝淡变：首 4ms 淡入、尾 8ms 淡出 → 首尾样本归零，循环无「咔哒」爆音
func _seam_fade(buf: PackedFloat32Array) -> void:
	var n := buf.size()
	var hf := int(0.004 * RATE)
	var tf := int(0.008 * RATE)
	for i in range(hf):
		buf[i] *= float(i) / float(hf)
	for i in range(tf):
		buf[n - 1 - i] *= float(i) / float(tf)


## 护卫帧 GUARD：重采样器在循环边界会多读 1~N 帧（22050→44100 线性插值读 pos+1）。
## 原来 loop_end=数据末尾→越界读 data 之外的内存，偶发命中未映射页→安卓 AudioTrack 线程 SIGSEGV 硬崩。
## 在数据尾部补一段「循环起点」的拷贝作安全垫：loop_end 仍指原长度（无缝循环），越界读落在护卫帧里不再崩。
const GUARD := 64

func _wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var n := buf.size()
	var data := PackedByteArray()
	data.resize((n + GUARD) * 2)
	for i in range(n):
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	for i in range(GUARD):                                  # 护卫=循环起点拷贝（n>0 时无缝）
		data.encode_s16((n + i) * 2, int(clampf(buf[i % maxi(1, n)], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n                                          # 仍在原长度循环；护卫帧只给越界读留安全内存
	return w


## 往缓冲叠加一个音符（加法合成）。音符尾音须落在缓冲内衰减完，循环接缝才无爆音。
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


## 战鼓：低频「咚」+ 一点噪声攻击，落在缓冲内
func _add_drum(buf: PackedFloat32Array, start: float, vol: float, pitch := 92.0) -> void:
	var n := buf.size()
	var s0 := int(start * RATE)
	var ns := int(0.32 * RATE)
	for i in range(ns):
		var idx := s0 + i
		if idx < 0 or idx >= n:
			continue
		var t := float(i) / RATE
		var body := sin((pitch * (1.0 - t * 1.2)) * t * TAU)   # 下滑音高，鼓腔感
		var click := randf_range(-1.0, 1.0) * exp(-60.0 * t) * 0.5
		buf[idx] += (body * exp(-9.0 * t) + click) * vol


func _silent(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b


## 经营曲：安宁、舒缓。低音根弦垫底 + 五声旋律拨奏，12 秒循环。
func _build_calm() -> PackedFloat32Array:
	var loop := 12.0
	var buf := _silent(loop)
	# 低音根弦：每 3 秒一个长音（柔正弦，慢衰减作 pad）
	var bass_seq := [0, 3, 1, 2]   # 索引进 BASS
	for k in range(bass_seq.size()):
		_add_note(buf, BASS[bass_seq[k]], k * 3.0, 2.9, 0.26, "sine", 0.7, 0.05)
		_add_note(buf, BASS[bass_seq[k]] * 1.5, k * 3.0 + 0.02, 2.6, 0.10, "sine", 0.8)   # 纯五度泛音
	# 旋律：五声音阶拨奏，每 0.75 秒一音，三角波带衰减（古筝/拨弦感）
	var mel_pat := [0, 2, 3, 4, 3, 2, 4, 5, 4, 3, 1, 0, 2, 3, 1, 0]
	for k in range(mel_pat.size()):
		var f: float = MEL[mel_pat[k]]
		_add_note(buf, f, k * 0.75, 0.9, 0.15, "tri", 3.2)
		if k % 4 == 2:   # 偶尔加一层高八度点缀
			_add_note(buf, f * 2.0, k * 0.75 + 0.06, 0.5, 0.06, "sine", 4.0)
	return buf


## 战斗曲：紧张、行进。战鼓节拍 + 低音固定音型 + 急促五声旋律，8 秒循环。
func _build_battle() -> PackedFloat32Array:
	var loop := 8.0
	var buf := _silent(loop)
	# 战鼓：每 0.5 秒一拍，重拍更响
	var beats := int(loop / 0.5)
	for k in range(beats):
		var v := 0.5 if k % 4 == 0 else (0.34 if k % 2 == 0 else 0.22)
		_add_drum(buf, k * 0.5, v, 96.0 if k % 4 == 0 else 88.0)
	# 低音固定音型（八分驱动，锯齿略带张力）
	var bass_pat := [0, 0, 3, 0, 2, 2, 3, 0]   # 每拍一个，循环
	for k in range(beats):
		var bf: float = BASS[bass_pat[k % bass_pat.size()]]
		_add_note(buf, bf, k * 0.5, 0.42, 0.20, "saw", 4.5)
	# 旋律：急促五声，每 0.25 秒一音（含偶尔小三度色彩音，更肃杀）
	var mel_pat := [4, 5, 4, 3, 4, 3, 2, 3, 4, 5, 4, 5, 3, 2, 3, 4,
			4, 3, 4, 5, 3, 4, 2, 3, 4, 5, 4, 3, 2, 3, 1, 0]
	for k in range(mel_pat.size()):
		var f: float = MEL[mel_pat[k]]
		_add_note(buf, f, k * 0.25, 0.34, 0.13, "tri", 5.5)
	return buf
