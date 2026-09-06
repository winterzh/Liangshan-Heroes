"""Render reproducible, isolated Steam footage from the verified release PCK."""
import argparse, json, os, pathlib, subprocess, hashlib, time

HERE = pathlib.Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('--godot', required=True)
parser.add_argument('--pack', required=True)
parser.add_argument('--expected-sha256', required=True)
parser.add_argument('--output-root',required=True,help='Use an ignored directory such as .godot/steam_store_media_20260907/video')
parser.add_argument('--shot', choices=('zhu','naval','defense','caravan'), required=True)
parser.add_argument('--duration', type=int)
args = parser.parse_args()
pack = pathlib.Path(args.pack).resolve()
pack_sha = hashlib.sha256(pack.read_bytes()).hexdigest()
driver_sha = hashlib.sha256((HERE/'record_gameplay.gd').read_bytes()).hexdigest()
if pack_sha != args.expected_sha256.lower():
    raise SystemExit('Release package SHA256 does not match the approved recording source.')
out = pathlib.Path(args.output_root).resolve() / args.shot
out.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
for k in list(env):
    if k in {'SMOKE_TEST','AUTO_MICRO','LEVEL','SKIRMISH','SKIRMISH_AI','ARENA','DEF_WAVES','DEF_HEROES','DEF_RANDOM','DEF_INTERVAL','AI_FRIENDLY','SCALE_ON','ENEMY_MULT','HERO_MULT','CUSTOM_DEFENSE','SCENARIO','PERF_BENCH','INFO_UI_TEST_DIR','SCREENSHOT_DIR','ABILITY_VIS_AUDIT','STORE_DURATION'} or k.endswith('_TEST'):
        env.pop(k)
env['APPDATA'] = str(out / 'isolated_userdata')
env['STORE_SHOT'] = args.shot
env['STORE_VIDEO_OUT'] = str(out)
env['STORE_MOUNTED_PACK'] = str(pack)
if args.duration: env['STORE_DURATION'] = str(args.duration)
cmd = [args.godot, '--main-pack', str(pack), '--script', str(HERE/'record_gameplay.gd'),
       '--resolution','1920x1080','--position','0,0','--write-movie',str(out/(args.shot+'.avi')),
       '--fixed-fps','30','--disable-vsync']
started = time.time()
with (out/'console.log').open('w', encoding='utf-8') as log:
    result = subprocess.run(cmd, env=env, stdout=log, stderr=subprocess.STDOUT)
receipt = {'source_sha':'443e75e887afd76f9569cae17b0527a72408aedc','pack':str(pack),
           'pack_sha256':pack_sha,'expected_pack_sha256':args.expected_sha256.lower(),'driver_sha256':driver_sha,'command':cmd,
           'returncode':result.returncode,'elapsed_seconds':round(time.time()-started,2)}
(out/'render_receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(receipt,ensure_ascii=False))
raise SystemExit(result.returncode)
