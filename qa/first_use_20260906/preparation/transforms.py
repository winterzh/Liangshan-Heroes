"""Reversible, complete-method wrappers. Never writes source by itself."""
import hashlib
import re

PINS = {
    'scripts/sfx.gd': 'ed3e9e5527b68d47ff02ffc53e75256d1483287dd29f512165c8086c75232f1b',
    'scripts/art_db.gd': 'e3e871b85fa87e17c047de58a5d2ea13bed34fd7772027145b64026383024996',
    'tools/polish_performance_probe.gd': '04a47115c8cd05670b465086653491466fdae99f6fadf9c41c40379aee0c1407',
    'scripts/battle.gd': '784373eede18a82c24fc50a6e36a42b6c20516bf439cf200fe5be7d239db6e2c',
    'scripts/unit.gd': 'c8a692bff598b6ac9199d113ccc9ff39ea8943f127012b45fc67ff2cd6c4deec',
}


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def normalized(raw):
    return raw.replace(b'\r\n', b'\n')


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def method_span(text, name):
    hits = list(re.finditer(r'^func ' + re.escape(name) + r'\(', text, re.M))
    require(len(hits) == 1, 'Expected exactly one method: ' + name)
    start = hits[0].start()
    # Only top-level declarations end the method. Keep comments and blank lines.
    next_decl = re.search(r'^(?:func |class |const |var |static |signal |enum |@)', text[hits[0].end():], re.M)
    end = hits[0].end() + next_decl.start() if next_decl else len(text)
    return start, end


def wrap(text, name, body):
    start, end = method_span(text, name)
    old = text[start:end]
    signature = old.splitlines()[0]
    renamed_name = '_first_use_original_' + name.lstrip('_')
    require(renamed_name not in text, 'Already wrapped: ' + name)
    renamed = old.replace('func ' + name + '(', 'func ' + renamed_name + '(', 1)
    body = body.replace('@ORIGINAL@', renamed_name)
    require(body.count(renamed_name + '(') == 1, 'Wrapper must have one original call site')
    wrapper = signature + '\n' + body.strip('\n') + '\n\n\n'
    result = text[:start] + wrapper + renamed + text[end:]
    recovered = result[:start] + result[start + len(wrapper):]
    recovered = recovered.replace('func ' + renamed_name + '(', 'func ' + name + '(', 1)
    require(recovered == text, 'Inverse failed for ' + name)
    return result, {'method': name, 'original_method_lf_sha256': sha(old.encode()),
                    'original_call_sites': 1, 'body_byte_identical_after_lf_normalization': True,
                    'inverse_transform_verified': True}


SFX = {
    'play_ability': '''
	var observe: bool = not _shutting_down and enabled and not _bank.has("ab_" + aid)
	var prior_context: String = FirstUseDiag.sfx_context
	var ticket: int = -1
	if observe:
		FirstUseDiag.sfx_context = aid
		ticket = FirstUseDiag.open_event(0, aid + "|" + theme + "|" + kind)
	@ORIGINAL@(aid, theme, kind, vol_db)
	if observe:
		FirstUseDiag.close_event(ticket)
		FirstUseDiag.sfx_context = prior_context
''',
    '_build_ability': '''
	var ticket: int = FirstUseDiag.open_event(1, aid + "|" + theme + "|" + kind)
	var result: PackedFloat32Array = @ORIGINAL@(aid, theme, kind)
	FirstUseDiag.close_event(ticket, result.size())
	return result
''',
    '_wav': '''
	var ticket: int = FirstUseDiag.open_event(2, FirstUseDiag.sfx_context, samples.size())
	var result: AudioStreamWAV = @ORIGINAL@(samples)
	FirstUseDiag.close_event(ticket, samples.size())
	return result
''',
}
ART = {
    '_try_load': '''
	var ticket: int = FirstUseDiag.open_event(3, path)
	var result: Texture2D = @ORIGINAL@(path)
	FirstUseDiag.close_event(ticket, 1 if result != null else 0)
	return result
''',
    '_atlas': '''
	var ticket: int = -1
	if tex != null and not _cache.has(cache_key):
		ticket = FirstUseDiag.open_event(4, cache_key)
	var result: Texture2D = @ORIGINAL@(tex, cell, grid, cache_key)
	FirstUseDiag.close_event(ticket, 1 if result != null else 0)
	return result
''',
    'unit_anim_frames': '''
	var ticket: int = -1
	if variant.is_empty() and (direction.is_empty() or direction in CampaignArt.DIRECTIONS):
		var resolved_key: String = _ra(key)
		resolved_key = SPRITE_ALIAS.get(resolved_key, resolved_key)
		var ck: String = "legacy|%s|%s" % [resolved_key, state] if direction.is_empty() else "unit|%s|%s|%s" % [resolved_key, state, direction]
		if not _anim_cache.has(ck):
			ticket = FirstUseDiag.open_event(5, ck)
	var result: Array = @ORIGINAL@(key, state, direction, variant)
	FirstUseDiag.close_event(ticket, result.size())
	return result
''',
    '_load_generic_directional_frames': '''
	var ticket: int = -1
	if not path.is_empty():
		ticket = FirstUseDiag.open_event(6, path)
	var result: Array = @ORIGINAL@(path)
	FirstUseDiag.close_event(ticket, result.size())
	return result
''',
    '_slice_anim_strip': '''
	var ticket: int = -1
	if tex != null:
		ticket = FirstUseDiag.open_event(7, tex.resource_path)
	var result: Array = @ORIGINAL@(tex)
	FirstUseDiag.close_event(ticket, result.size())
	return result
''',
}


def instrument(path, raw):
    require(path in PINS and sha(normalized(raw)) == PINS[path], 'Pinned source drift: ' + path)
    text = normalized(raw).decode('utf-8')
    recipes = SFX if path == 'scripts/sfx.gd' else ART
    receipts = []
    for name, body in recipes.items():
        text, receipt = wrap(text, name, body)
        receipts.append(receipt)
    # Everything outside wrappers and renamed original declarations is unchanged.
    return text.encode('utf-8'), receipts


def once(text, needle, replacement):
    require(text.count(needle) == 1, 'Driver anchor changed: ' + repr(needle))
    return text.replace(needle, replacement, 1)


def driver(probe_raw, template):
    require(sha(normalized(probe_raw)) == PINS['tools/polish_performance_probe.gd'], 'M1 probe drift')
    probe = normalized(probe_raw).decode('utf-8')
    lo, hi = method_span(probe, '_run')
    run = probe[lo:hi]
    run = once(run, 'func _run() -> void:\n', 'func _run() -> void:\n\tvar diag = root.get_node("FirstUseDiag")\n\tdiag.mark_stage("music_wait")\n')
    run = once(run, '\tvar b = await _new_battle(); battle_ref = b', '\tdiag.mark_stage("fixture_setup")\n\tvar b = await _new_battle(); battle_ref = b')
    run = once(run, '\tvar initial_state := _state(b)', '\tvar initial_state := _state(b)\n\tdiag.capture_fixture(b)')
    run = once(run, '\tvar warm_start := Time.get_ticks_usec()', '\tvar warm_start := Time.get_ticks_usec()\n\tdiag.mark_stage("warmup", warm_start)')
    run = once(run, '\tvar warm_end_tick := physics_tick', '\tvar warm_end_tick := physics_tick\n\tdiag.mark_stage("warmup_post_process")')
    run = once(run, '\tvar started := Time.get_ticks_usec(); var previous := started; var start_tick := physics_tick', '\tvar started := Time.get_ticks_usec(); var previous := started; var start_tick := physics_tick\n\tdiag.mark_stage("sample", started)')
    run = once(run, '\tvar elapsed := float(Time.get_ticks_usec()-started)/1000000.0', '\tvar elapsed := float(Time.get_ticks_usec()-started)/1000000.0\n\tdiag.freeze_capture(started + roundi(elapsed * 1000000.0))')
    run = once(run, '\tvar output: String = OS.get_environment("POLISH_OUT")', '\tcheck(diag.capture_valid(), "first-use buffers and source scope valid")\n\tcheck(seconds == 10.0 and scenario == "defense200" and camera_mode == "fixed", "single 10-second fixed entry scope")\n\tvar first_use_report: Dictionary = diag.export_report()\n\treport["first_use"] = first_use_report\n\treport["diagnostic_only"] = true\n\treport["acceptance_eligible"] = false\n\tvar output: String = OS.get_environment("POLISH_OUT")')
    require(template.count('@@RUN_METHOD@@') == 1, 'Expected one driver template slot')
    return template.replace('@@RUN_METHOD@@', run).encode('utf-8')
